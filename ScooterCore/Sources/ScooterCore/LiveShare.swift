import Foundation

/// Partage de position en direct : état publié et tracé compact pour la page web.
public enum LiveShare {
    public enum State: String, Sendable, Codable {
        case riding, paused, arrived, alert
    }

    /// Adresse de la page de suivi pour cet identifiant de partage.
    public static func link(id: String) -> URL? {
        URL(string: "https://brunotahiti.github.io/Scooter-power/live/?id=" + id)
    }

    /// Identifiant aléatoire, impossible à deviner (128 bits).
    public static func newID() -> String {
        UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    }

    /// Tracé allégé pour la page : un point tous les `spacing` mètres au plus,
    /// `maxPoints` derniers points, sous la forme « lat,lon;lat,lon » (5 décimales).
    public static func encodeTrail(_ route: [Coordinate], spacing: Double = 15, maxPoints: Int = 400) -> String {
        var kept: [Coordinate] = []
        for point in route {
            if let last = kept.last, TripStatistics.haversine(last, point) < spacing { continue }
            kept.append(point)
        }
        if let last = route.last, kept.last != last { kept.append(last) }
        return kept.suffix(maxPoints)
            .map { String(format: "%.5f,%.5f", $0.latitude, $0.longitude) }
            .joined(separator: ";")
    }

    public static func decodeTrail(_ text: String) -> [Coordinate] {
        text.split(separator: ";").compactMap { pair in
            let parts = pair.split(separator: ",")
            guard parts.count == 2, let lat = Double(parts[0]), let lon = Double(parts[1]) else { return nil }
            return Coordinate(latitude: lat, longitude: lon)
        }
    }
}
