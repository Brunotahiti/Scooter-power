import Foundation

/// Ce que le scooter faisait à un point du tracé.
public struct ReplayPoint: Sendable, Equatable, Codable {
    /// Secondes depuis le premier point du trajet.
    public var time: TimeInterval
    public var speedKmh: Double
    /// m/s², signée.
    public var acceleration: Double
    /// Degrés, positifs vers la droite.
    public var leanDegrees: Double

    public init(time: TimeInterval, speedKmh: Double, acceleration: Double, leanDegrees: Double) {
        self.time = time
        self.speedKmh = speedKmh
        self.acceleration = acceleration
        self.leanDegrees = leanDegrees
    }

    // Clés courtes : un trajet partagé tient dans un petit fichier.
    private enum CodingKeys: String, CodingKey {
        case time = "t", speedKmh = "v", acceleration = "a", leanDegrees = "l"
    }
}

/// État du scooter à un instant de la revisualisation.
public struct ReplayFrame: Sendable, Equatable {
    public var coordinate: Coordinate
    /// Cap en degrés, 0 = nord, 90 = est.
    public var heading: Double
    public var speedKmh: Double
    public var acceleration: Double
    public var leanDegrees: Double
    /// Secondes depuis le début de la revisualisation.
    public var time: TimeInterval
    /// Index du dernier point du tracé atteint.
    public var index: Int

    public init(coordinate: Coordinate, heading: Double, speedKmh: Double, acceleration: Double,
                leanDegrees: Double, time: TimeInterval, index: Int) {
        self.coordinate = coordinate
        self.heading = heading
        self.speedKmh = speedKmh
        self.acceleration = acceleration
        self.leanDegrees = leanDegrees
        self.time = time
        self.index = index
    }
}

/// Rejoue un trajet : position, cap, vitesse, poussée et inclinaison à
/// chaque instant, par interpolation entre les points du tracé.
public struct TripReplay: Sendable {
    /// Une interruption plus longue (pause, tunnel) est ramenée à cette durée.
    public static let maxGap: TimeInterval = 2

    public let route: [Coordinate]
    public let points: [ReplayPoint]
    /// Temps de revisualisation de chaque point, pauses raccourcies.
    public let times: [TimeInterval]
    /// Vrai si les vitesses viennent de l'enregistrement, faux si elles sont estimées.
    public let isRecorded: Bool

    public var duration: TimeInterval { times.last ?? 0 }

    /// `points` doit être aligné sur `route` ; sinon le trajet est rejoué à
    /// vitesse constante (`averageSpeedKmh`), pour les trajets anciens.
    ///
    /// `absoluteTimes` (balades de groupe) garde les temps tels quels, sans
    /// raccourcir les pauses ni repartir de zéro, pour que tous les pilotes
    /// restent synchronisés.
    public init(route: [Coordinate], points: [ReplayPoint], averageSpeedKmh: Double, absoluteTimes: Bool = false) {
        let valid: [Coordinate] = route
        if points.count == valid.count, valid.count > 1 {
            self.route = valid
            self.points = points
            self.isRecorded = true
            if absoluteTimes {
                var times: [TimeInterval] = []
                for point in points {
                    times.append(max(point.time, times.last ?? point.time))
                }
                self.times = times
            } else {
                var times: [TimeInterval] = [0]
                for index in 1..<points.count {
                    let gap: TimeInterval = max(0, points[index].time - points[index - 1].time)
                    times.append(times[index - 1] + min(gap, Self.maxGap))
                }
                self.times = times
            }
        } else {
            self.route = valid
            self.isRecorded = false
            let speed: Double = max(10, averageSpeedKmh)
            var times: [TimeInterval] = []
            var built: [ReplayPoint] = []
            var elapsed: TimeInterval = 0
            for index in valid.indices {
                if index > 0 {
                    elapsed += TripStatistics.haversine(valid[index - 1], valid[index]) / (speed / 3.6)
                }
                times.append(elapsed)
                built.append(ReplayPoint(time: elapsed, speedKmh: speed, acceleration: 0, leanDegrees: 0))
            }
            self.points = built
            self.times = times
        }
    }

    /// État du scooter à l'instant `time`, borné au début et à la fin.
    public func frame(at time: TimeInterval) -> ReplayFrame? {
        guard let first = route.first, let firstPoint = points.first else { return nil }
        guard route.count > 1 else {
            return ReplayFrame(
                coordinate: first, heading: 0, speedKmh: firstPoint.speedKmh,
                acceleration: firstPoint.acceleration, leanDegrees: firstPoint.leanDegrees, time: 0, index: 0)
        }
        let t: TimeInterval = min(max(times.first ?? 0, time), duration)
        let (coordinate, index, f) = position(at: t)
        let pa = points[index]
        let pb = points[index + 1]
        // Douceur aux changements de point : vitesse, accélération et
        // inclinaison suivent une courbe en S plutôt qu'une ligne brisée.
        let g: Double = f * f * (3 - 2 * f)
        return ReplayFrame(
            coordinate: coordinate,
            heading: smoothHeading(at: t, index: index),
            speedKmh: pa.speedKmh + (pb.speedKmh - pa.speedKmh) * g,
            acceleration: pa.acceleration + (pb.acceleration - pa.acceleration) * g,
            leanDegrees: pa.leanDegrees + (pb.leanDegrees - pa.leanDegrees) * g,
            time: t,
            index: f >= 1 ? index + 1 : index)
    }

    /// Tracé parcouru jusqu'à `time`, en suivant la même courbe que le scooter
    /// (la traînée reste collée à lui dans les virages).
    public func trail(upTo time: TimeInterval) -> [Coordinate] {
        guard route.count > 1 else { return route }
        let (end, index, _) = position(at: time)
        var result: [Coordinate] = Array(route[0...index])
        let start: TimeInterval = times[index]
        var t: TimeInterval = start + 0.2
        while t < time {
            result.append(position(at: t).0)
            t += 0.2
        }
        result.append(end)
        return result
    }

    /// Position à l'instant `t` sur une courbe de Catmull-Rom passant par les
    /// points du tracé : les virages sont arrondis au lieu de faire des angles.
    func position(at time: TimeInterval) -> (Coordinate, Int, Double) {
        let t: TimeInterval = min(max(times.first ?? 0, time), duration)
        var low = 0
        var high = times.count - 1
        while low < high {
            let mid = (low + high + 1) / 2
            if times[mid] <= t { low = mid } else { high = mid - 1 }
        }
        let index: Int = min(low, route.count - 2)
        let span: TimeInterval = times[index + 1] - times[index]
        let f: Double = span > 0 ? min(1, max(0, (t - times[index]) / span)) : 1
        let p1: Coordinate = route[index]
        let p2: Coordinate = route[index + 1]
        // Aux extrémités, point fictif dans le prolongement : vitesse régulière.
        let p0: Coordinate = index > 0 ? route[index - 1]
            : Coordinate(latitude: 2 * p1.latitude - p2.latitude, longitude: 2 * p1.longitude - p2.longitude)
        let p3: Coordinate = index + 2 < route.count ? route[index + 2]
            : Coordinate(latitude: 2 * p2.latitude - p1.latitude, longitude: 2 * p2.longitude - p1.longitude)
        // Pas de courbe sur un saut GPS ou à l'arrêt : la ligne droite suffit.
        let d12: Double = TripStatistics.haversine(p1, p2)
        guard d12 > 0.5, d12 < 400 else {
            return (Coordinate(latitude: p1.latitude + (p2.latitude - p1.latitude) * f,
                               longitude: p1.longitude + (p2.longitude - p1.longitude) * f), index, f)
        }
        func spline(_ a: Double, _ b: Double, _ c: Double, _ d: Double) -> Double {
            let f2: Double = f * f
            let f3: Double = f2 * f
            return 0.5 * ((2 * b) + (-a + c) * f + (2 * a - 5 * b + 4 * c - d) * f2 + (-a + 3 * b - 3 * c + d) * f3)
        }
        return (Coordinate(latitude: spline(p0.latitude, p1.latitude, p2.latitude, p3.latitude),
                           longitude: spline(p0.longitude, p1.longitude, p2.longitude, p3.longitude)), index, f)
    }

    /// Cap lissé : direction entre la position 0,6 s avant et 0,6 s après,
    /// pour que le scooter tourne progressivement dans les virages.
    private func smoothHeading(at t: TimeInterval, index: Int) -> Double {
        let (before, _, _) = position(at: t - 0.6)
        let (after, _, _) = position(at: t + 0.6)
        if TripStatistics.haversine(before, after) > 1.5 {
            return Self.bearing(from: before, to: after)
        }
        return heading(around: index)
    }

    /// Cap du segment qui part de `index`, ou du précédent si ce segment est
    /// trop court (scooter à l'arrêt), pour éviter que l'icône tourne sur place.
    private func heading(around index: Int) -> Double {
        var i = index
        while i >= 0 {
            if TripStatistics.haversine(route[i], route[i + 1]) > 1 {
                return Self.bearing(from: route[i], to: route[i + 1])
            }
            i -= 1
        }
        var j = index + 1
        while j < route.count - 1 {
            if TripStatistics.haversine(route[j], route[j + 1]) > 1 {
                return Self.bearing(from: route[j], to: route[j + 1])
            }
            j += 1
        }
        return 0
    }

    /// Cap initial de `a` vers `b`, en degrés dans [0, 360[.
    public static func bearing(from a: Coordinate, to b: Coordinate) -> Double {
        let lat1: Double = a.latitude * .pi / 180
        let lat2: Double = b.latitude * .pi / 180
        let dLon: Double = (b.longitude - a.longitude) * .pi / 180
        let y: Double = sin(dLon) * cos(lat2)
        let x: Double = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let degrees: Double = atan2(y, x) * 180 / .pi
        return (degrees + 360).truncatingRemainder(dividingBy: 360)
    }
}
