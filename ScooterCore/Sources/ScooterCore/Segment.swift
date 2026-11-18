import Foundation

/// Un segment : une portion de route chronométrée à chaque passage, comme une
/// spéciale. Il est découpé dans un trajet enregistré.
public struct Segment: Sendable, Equatable, Codable {
    public var path: [Coordinate]

    /// Rayon autour du départ et de l'arrivée.
    public static let gateRadius: Double = 30
    /// Écart maximal toléré entre le trajet et le segment.
    public static let corridor: Double = 50
    public static let minimumLength: Double = GhostRace.minimumLength

    public init(path: [Coordinate]) {
        self.path = path
    }

    public var length: Double {
        zip(path, path.dropFirst()).reduce(0) { $0 + TripStatistics.haversine($1.0, $1.1) }
    }

    /// Découpe la portion d'un tracé entre deux fractions de sa longueur (0 à 1).
    public static func cut(route: [Coordinate], from start: Double, to end: Double) -> Segment? {
        guard route.count >= 2, end > start else { return nil }
        var cumulative: [Double] = [0]
        for index in 1..<route.count {
            cumulative.append(cumulative[index - 1] + TripStatistics.haversine(route[index - 1], route[index]))
        }
        guard let total = cumulative.last, total > 0 else { return nil }
        let a: Double = max(0, min(1, start)) * total
        let b: Double = max(0, min(1, end)) * total
        var path: [Coordinate] = [point(at: a, route: route, cumulative: cumulative)]
        for index in route.indices where cumulative[index] > a && cumulative[index] < b {
            path.append(route[index])
        }
        path.append(point(at: b, route: route, cumulative: cumulative))
        let segment = Segment(path: path)
        return segment.length >= minimumLength ? segment : nil
    }

    /// Un passage chronométré sur le segment.
    public struct Pass: Sendable, Equatable {
        /// Temps du trajet au départ et à l'arrivée du segment.
        public var startTime: TimeInterval
        public var endTime: TimeInterval
        public var duration: TimeInterval { endTime - startTime }
        /// Indices du tracé du trajet au départ et à l'arrivée.
        public var startIndex: Int
        public var endIndex: Int
    }

    /// Passages complets d'un trajet sur ce segment, dans le bon sens. `times`
    /// est aligné sur `route` (secondes depuis le début du trajet).
    public func passes(route: [Coordinate], times: [TimeInterval]) -> [Pass] {
        guard path.count >= 2, route.count >= 2, route.count == times.count,
              let first = path.first, let last = path.last else { return [] }
        let checkpoints: [Coordinate] = Self.checkpoints(path)
        var result: [Pass] = []
        var index = 0
        while index < route.count {
            // Passage au plus près de la ligne de départ.
            guard var entry = Self.closestVisit(to: first, in: route, from: index) else { break }
            // Arrivée : première visite de la ligne d'arrivée après le départ.
            guard let exit = Self.closestVisit(to: last, in: route, from: entry.end) else { break }
            // Dernier passage au départ avant cette arrivée (aller-retour, demi-tour).
            while let later = Self.closestVisit(to: first, in: route, from: entry.end), later.best < exit.start {
                entry = later
            }
            let startTime: TimeInterval = Self.time(at: entry, route: route, times: times, gate: first)
            if Self.follows(checkpoints, route: route, from: entry.best, to: exit.best) {
                let endTime: TimeInterval = Self.time(at: exit, route: route, times: times, gate: last)
                if endTime > startTime {
                    result.append(Pass(startTime: startTime, endTime: endTime, startIndex: entry.best, endIndex: exit.best))
                }
                index = exit.end
            } else {
                index = entry.end
            }
        }
        return result
    }

    /// Un passage comme ghost, pour refaire le segment contre lui.
    public static func ghost(route: [Coordinate], times: [TimeInterval], pass: Pass) -> GhostRace? {
        guard pass.startIndex < pass.endIndex, pass.endIndex < route.count, route.count == times.count else { return nil }
        let start: TimeInterval = times[pass.startIndex]
        return GhostRace(route: Array(route[pass.startIndex...pass.endIndex]),
                         times: times[pass.startIndex...pass.endIndex].map { $0 - start })
    }

    /// Le meilleur passage d'un trajet, s'il y en a un.
    public func bestPass(route: [Coordinate], times: [TimeInterval]) -> Pass? {
        passes(route: route, times: times).min { $0.duration < $1.duration }
    }

    // MARK: - Interne

    /// Une visite dans le rayon d'une porte : premier et dernier indice, et le plus proche.
    struct Visit {
        var start: Int
        var end: Int
        var best: Int
    }

    static func closestVisit(to gate: Coordinate, in route: [Coordinate], from start: Int) -> Visit? {
        guard start < route.count else { return nil }
        var visit: Visit?
        var bestDistance = Double.infinity
        for index in start..<route.count {
            let distance: Double = TripStatistics.haversine(route[index], gate)
            if distance <= gateRadius {
                if visit == nil { visit = Visit(start: index, end: index + 1, best: index) }
                visit?.end = index + 1
                if distance < bestDistance {
                    bestDistance = distance
                    visit?.best = index
                }
            } else if visit != nil {
                break
            }
        }
        return visit
    }

    /// Temps de passage à la porte : point le plus proche, affiné entre ses voisins.
    static func time(at visit: Visit, route: [Coordinate], times: [TimeInterval], gate: Coordinate) -> TimeInterval {
        let index: Int = visit.best
        var bestTime: TimeInterval = times[index]
        var bestDistance: Double = TripStatistics.haversine(route[index], gate)
        for neighbour in [index - 1, index + 1] where neighbour >= 0 && neighbour < route.count {
            let (distance, ratio) = GhostRace.distance(from: gate, toSegment: route[min(index, neighbour)], route[max(index, neighbour)])
            if distance < bestDistance {
                bestDistance = distance
                let low: Int = min(index, neighbour)
                let high: Int = max(index, neighbour)
                bestTime = times[low] + (times[high] - times[low]) * ratio
            }
        }
        return bestTime
    }

    /// Points de contrôle tous les 100 m le long du segment.
    static func checkpoints(_ path: [Coordinate]) -> [Coordinate] {
        var result: [Coordinate] = []
        var travelled: Double = 0
        var next: Double = 100
        for (a, b) in zip(path, path.dropFirst()) {
            let step: Double = TripStatistics.haversine(a, b)
            while step > 0, travelled + step >= next {
                let ratio: Double = (next - travelled) / step
                result.append(Coordinate(latitude: a.latitude + (b.latitude - a.latitude) * ratio,
                                         longitude: a.longitude + (b.longitude - a.longitude) * ratio))
                next += 100
            }
            travelled += step
        }
        return result
    }

    /// Le trajet passe près de chaque point de contrôle, dans l'ordre.
    static func follows(_ checkpoints: [Coordinate], route: [Coordinate], from start: Int, to end: Int) -> Bool {
        guard start < end else { return checkpoints.isEmpty }
        var cursor: Int = start
        for checkpoint in checkpoints {
            var found: Int?
            for index in cursor..<end {
                let (distance, _) = GhostRace.distance(from: checkpoint, toSegment: route[index], route[index + 1])
                if distance <= corridor {
                    found = index
                    break
                }
            }
            guard let found else { return false }
            cursor = found
        }
        return true
    }

    static func distance(from point: Coordinate, toPolyline line: ArraySlice<Coordinate>) -> Double {
        guard let first = line.first else { return .infinity }
        guard line.count > 1 else { return TripStatistics.haversine(point, first) }
        var best = Double.infinity
        for (a, b) in zip(line, line.dropFirst()) {
            best = min(best, GhostRace.distance(from: point, toSegment: a, b).0)
        }
        return best
    }

    static func point(at meters: Double, route: [Coordinate], cumulative: [Double]) -> Coordinate {
        let upper: Int = cumulative.firstIndex { $0 >= meters } ?? route.count - 1
        let lower: Int = max(0, upper - 1)
        let span: Double = cumulative[upper] - cumulative[lower]
        let ratio: Double = span > 0 ? (meters - cumulative[lower]) / span : 0
        let a: Coordinate = route[lower]
        let b: Coordinate = route[upper]
        return Coordinate(latitude: a.latitude + (b.latitude - a.latitude) * ratio,
                          longitude: a.longitude + (b.longitude - a.longitude) * ratio)
    }
}
