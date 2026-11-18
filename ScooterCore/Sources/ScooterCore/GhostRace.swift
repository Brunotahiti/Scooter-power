import Foundation

/// Course contre un trajet déjà enregistré (le « ghost ») sur le même parcours.
///
/// Les deux chronos partent quand le scooter a parcouru `startRadius` mètres le
/// long du tracé : l'attente au départ du ghost comme du pilote ne compte pas.
/// L'écart est calculé à distance égale : le temps qu'avait mis le ghost pour
/// arriver là où est le pilote, moins le temps du pilote.
public struct GhostRace: Sendable {
    public enum Phase: Sendable, Equatable {
        /// Le pilote doit rejoindre le départ du ghost.
        case waitingForStart
        case racing
        case finished
    }

    public struct Status: Sendable, Equatable {
        public var phase: Phase
        /// Distance jusqu'au départ, tant que la course n'a pas commencé.
        public var distanceToStart: Double?
        /// Secondes d'avance sur le ghost (négatif : retard).
        public var gapSeconds: Double?
        /// Mètres d'avance sur le ghost au même instant (négatif : retard).
        public var gapMeters: Double?
        /// Part du parcours faite par le pilote et par le ghost, de 0 à 1.
        public var progress: Double
        public var ghostProgress: Double
        /// Position du ghost à cet instant.
        public var ghostCoordinate: Coordinate?
        /// Le pilote s'est éloigné du parcours.
        public var offRoute: Bool
        /// Temps du pilote et du ghost à l'arrivée.
        public var finishTime: Double?
        public var ghostFinishTime: Double?
    }

    public static let startRadius: Double = 40
    public static let finishRadius: Double = 35
    public static let offRouteDistance: Double = 80
    /// Parcours trop court pour une course.
    public static let minimumLength: Double = 300

    public let route: [Coordinate]
    private let times: [TimeInterval]
    private let cumulative: [Double]
    public let length: Double
    /// Temps du ghost au moment où il passe la ligne de départ.
    private let ghostStart: TimeInterval

    public private(set) var phase = Phase.waitingForStart
    private var armed = false
    private var startTime: TimeInterval?
    private var progressMeters: Double = 0
    private var segment = 0
    private var finish: (rider: Double, ghost: Double)?

    /// `nil` si le trajet n'a pas de tracé exploitable.
    public init?(route: [Coordinate], times: [TimeInterval]) {
        guard route.count >= 2, route.count == times.count else { return nil }
        var cumulative: [Double] = [0]
        for index in 1..<route.count {
            cumulative.append(cumulative[index - 1] + TripStatistics.haversine(route[index - 1], route[index]))
        }
        guard let total = cumulative.last, total >= Self.minimumLength else { return nil }
        self.route = route
        self.times = times
        self.cumulative = cumulative
        self.length = total
        self.ghostStart = Self.interpolate(Self.startRadius, keys: cumulative, values: times)
    }

    /// Temps de course du ghost pour la distance parcourue donnée.
    public func ghostTime(atDistance meters: Double) -> TimeInterval {
        Self.interpolate(meters, keys: cumulative, values: times) - ghostStart
    }

    /// Distance du ghost après ce temps de course.
    public func ghostDistance(atTime seconds: TimeInterval) -> Double {
        Self.interpolate(seconds + ghostStart, keys: times, values: cumulative)
    }

    /// Nouvelle position du pilote ; `time` en secondes, sur une horloge qui avance.
    public mutating func update(time: TimeInterval, coordinate: Coordinate) -> Status {
        switch phase {
        case .finished:
            return status(time: time, offRoute: false)
        case .waitingForStart:
            let toStart: Double = TripStatistics.haversine(coordinate, route[0])
            if toStart <= Self.startRadius { armed = true }
            if armed, let (distance, along) = project(coordinate), distance <= Self.offRouteDistance,
               along >= Self.startRadius - 0.5 {
                phase = .racing
                startTime = time
                progressMeters = along
            } else {
                // Sorti de la zone de départ sans suivre le parcours : il faut y revenir.
                if armed, toStart > Self.startRadius * 3 { armed = false }
                var waiting = status(time: time, offRoute: false)
                waiting.distanceToStart = toStart
                return waiting
            }
        case .racing:
            break
        }

        var offRoute = false
        if let (distance, along) = project(coordinate), distance <= Self.offRouteDistance {
            progressMeters = max(progressMeters, along)
        } else {
            offRoute = true
        }
        if progressMeters >= length - Self.finishRadius, let startTime {
            phase = .finished
            finish = (time - startTime, ghostTime(atDistance: length - Self.finishRadius))
        }
        return status(time: time, offRoute: offRoute)
    }

    private func status(time: TimeInterval, offRoute: Bool) -> Status {
        guard let startTime, phase != .waitingForStart else {
            return Status(phase: phase, distanceToStart: nil, gapSeconds: nil, gapMeters: nil, progress: 0,
                          ghostProgress: 0, ghostCoordinate: route[0], offRoute: false, finishTime: nil, ghostFinishTime: nil)
        }
        if let finish {
            return Status(phase: .finished, distanceToStart: nil, gapSeconds: finish.ghost - finish.rider, gapMeters: nil,
                          progress: 1, ghostProgress: 1, ghostCoordinate: route.last, offRoute: false,
                          finishTime: finish.rider, ghostFinishTime: finish.ghost)
        }
        let elapsed: Double = time - startTime
        let ghostMeters: Double = ghostDistance(atTime: elapsed)
        return Status(
            phase: .racing, distanceToStart: nil,
            gapSeconds: ghostTime(atDistance: progressMeters) - elapsed,
            gapMeters: progressMeters - ghostMeters,
            progress: min(1, progressMeters / length), ghostProgress: min(1, ghostMeters / length),
            ghostCoordinate: coordinate(atDistance: ghostMeters), offRoute: offRoute,
            finishTime: nil, ghostFinishTime: nil)
    }

    /// Point du parcours à cette distance du départ.
    public func coordinate(atDistance meters: Double) -> Coordinate {
        guard meters > 0 else { return route[0] }
        guard meters < length else { return route[route.count - 1] }
        let upper: Int = cumulative.firstIndex { $0 >= meters } ?? route.count - 1
        let lower: Int = max(0, upper - 1)
        let span: Double = cumulative[upper] - cumulative[lower]
        let ratio: Double = span > 0 ? (meters - cumulative[lower]) / span : 0
        let a: Coordinate = route[lower]
        let b: Coordinate = route[upper]
        return Coordinate(latitude: a.latitude + (b.latitude - a.latitude) * ratio,
                          longitude: a.longitude + (b.longitude - a.longitude) * ratio)
    }

    /// Projection sur le parcours, près de la dernière position connue (un
    /// parcours qui repasse au même endroit ne fait pas sauter la course).
    /// Rend la distance au parcours et la distance parcourue jusqu'au point projeté.
    private mutating func project(_ point: Coordinate) -> (Double, Double)? {
        var best: (distance: Double, along: Double, segment: Int)?
        for index in 0..<(route.count - 1) {
            if cumulative[index] > progressMeters + 600 { break }
            if cumulative[index + 1] < progressMeters - 100 { continue }
            let (distance, ratio) = Self.distance(from: point, toSegment: route[index], route[index + 1])
            let along: Double = cumulative[index] + (cumulative[index + 1] - cumulative[index]) * ratio
            if best == nil || distance < best!.distance {
                best = (distance, along, index)
            }
        }
        guard let best else { return nil }
        segment = best.segment
        return (best.distance, best.along)
    }

    /// Distance d'un point à un segment (plan local, suffisant sur quelques centaines de mètres).
    static func distance(from p: Coordinate, toSegment a: Coordinate, _ b: Coordinate) -> (Double, Double) {
        let metersPerDegree = 111_320.0
        let scale: Double = cos(p.latitude * .pi / 180)
        let ax: Double = (a.longitude - p.longitude) * metersPerDegree * scale
        let ay: Double = (a.latitude - p.latitude) * metersPerDegree
        let bx: Double = (b.longitude - p.longitude) * metersPerDegree * scale
        let by: Double = (b.latitude - p.latitude) * metersPerDegree
        let dx: Double = bx - ax
        let dy: Double = by - ay
        let lengthSquared: Double = dx * dx + dy * dy
        var ratio: Double = lengthSquared > 0 ? -(ax * dx + ay * dy) / lengthSquared : 0
        ratio = min(1, max(0, ratio))
        let x: Double = ax + dx * ratio
        let y: Double = ay + dy * ratio
        return ((x * x + y * y).squareRoot(), ratio)
    }

    /// Interpolation linéaire dans une table croissante.
    static func interpolate(_ x: Double, keys: [Double], values: [Double]) -> Double {
        guard let first = keys.first, let last = keys.last else { return 0 }
        if x <= first { return values[0] }
        if x >= last { return values[values.count - 1] }
        var low = 0
        var high = keys.count - 1
        while high - low > 1 {
            let mid = (low + high) / 2
            if keys[mid] <= x { low = mid } else { high = mid }
        }
        let span: Double = keys[high] - keys[low]
        let ratio: Double = span > 0 ? (x - keys[low]) / span : 0
        return values[low] + (values[high] - values[low]) * ratio
    }
}
