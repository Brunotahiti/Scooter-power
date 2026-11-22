import Foundation

/// Boucles « balade » : points de passage autour du départ, puis choix de
/// l'itinéraire le plus sinueux et le moins redondant parmi plusieurs essais.
public enum RideLoop {
    /// Les routes réelles sont plus longues que le cercle tracé à vol d'oiseau.
    static let detourFactor: Double = 1.35

    /// Trois points de passage sur un cercle qui passe par le départ, dans la
    /// direction `bearing` : départ → A → B → C → départ fait environ `meters`.
    public static func waypoints(start: Coordinate, meters: Double, bearing: Double) -> [Coordinate] {
        let radius: Double = meters / (2 * .pi * detourFactor)
        let center: Coordinate = RouteOffset.shift(start, bearing: bearing - 90, meters: radius)
        // Angle du départ vu du centre, puis trois points répartis sur le cercle.
        let startAngle: Double = TripReplay.bearing(from: center, to: start)
        return [90.0, 180.0, 270.0].map { step in
            destination(from: center, bearing: startAngle + step, meters: radius)
        }
    }

    /// Point à `meters` de `origin`, dans la direction `bearing` (degrés, 0 = nord).
    public static func destination(from origin: Coordinate, bearing: Double, meters: Double) -> Coordinate {
        let angle: Double = bearing * .pi / 180
        let dNorth: Double = cos(angle) * meters
        let dEast: Double = sin(angle) * meters
        return Coordinate(
            latitude: origin.latitude + dNorth / 111_320,
            longitude: origin.longitude + dEast / (111_320 * max(0.01, cos(origin.latitude * .pi / 180))))
    }

    /// Sinuosité : degrés de virage par kilomètre, sur des tronçons d'au moins 25 m.
    public static func curviness(_ route: [Coordinate]) -> Double {
        var points: [Coordinate] = []
        for point in route {
            if let last = points.last, TripStatistics.haversine(last, point) < 25 { continue }
            points.append(point)
        }
        guard points.count >= 3 else { return 0 }
        var turning: Double = 0
        var length: Double = 0
        for index in 1..<points.count {
            length += TripStatistics.haversine(points[index - 1], points[index])
        }
        for index in 1..<(points.count - 1) {
            let a: Double = TripReplay.bearing(from: points[index - 1], to: points[index])
            let b: Double = TripReplay.bearing(from: points[index], to: points[index + 1])
            var delta: Double = abs(b - a).truncatingRemainder(dividingBy: 360)
            if delta > 180 { delta = 360 - delta }
            // Un demi-tour (rond-point, impasse) n'est pas un virage plaisant.
            if delta < 150 { turning += delta }
        }
        guard length > 0 else { return 0 }
        return turning / (length / 1000)
    }

    /// Part du parcours qui repasse par une route déjà empruntée (aller-retour).
    public static func overlap(_ route: [Coordinate], tolerance: Double = 20) -> Double {
        var points: [Coordinate] = []
        for point in route {
            if let last = points.last, TripStatistics.haversine(last, point) < 30 { continue }
            points.append(point)
        }
        guard points.count > 10 else { return 0 }
        var repeated = 0
        for index in points.indices {
            // Comparé aux points parcourus au moins 10 étapes plus tôt.
            let earlier = points[..<max(0, index - 10)]
            if earlier.contains(where: { TripStatistics.haversine($0, points[index]) < tolerance }) {
                repeated += 1
            }
        }
        return Double(repeated) / Double(points.count)
    }

    /// Note d'une boucle : beaucoup de virages, peu d'aller-retour, longueur proche de la cible.
    public static func score(route: [Coordinate], meters: Double, target: Double) -> Double {
        let lengthPenalty: Double = abs(meters - target) / max(target, 1)
        return curviness(route) * (1 - min(1, overlap(route) * 1.5)) * max(0, 1 - lengthPenalty)
    }
}
