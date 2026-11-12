import Foundation

/// Produit un fichier GPX 1.1 à partir d'un tracé.
public enum GPXExporter {
    public static func document(route: [Coordinate], name: String, date: Date?) -> String {
        var lines: [String] = [
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
            "<gpx version=\"1.1\" creator=\"Scooter Power\" xmlns=\"http://www.topografix.com/GPX/1/1\">",
            "  <metadata>",
            "    <name>\(escape(name))</name>",
        ]
        if let date {
            lines.append("    <time>\(timestamp(date))</time>")
        }
        lines.append("  </metadata>")
        lines.append("  <trk>")
        lines.append("    <name>\(escape(name))</name>")
        lines.append("    <trkseg>")
        for point in route where point.latitude.isFinite && point.longitude.isFinite {
            // `String(format:)` utilise toujours le point décimal, comme l'exige le format GPX.
            lines.append(String(format: "      <trkpt lat=\"%.6f\" lon=\"%.6f\"/>", point.latitude, point.longitude))
        }
        lines.append("    </trkseg>")
        lines.append("  </trk>")
        lines.append("</gpx>")
        return lines.joined(separator: "\n") + "\n"
    }

    /// Nom de fichier sans extension, sûr sur tous les systèmes.
    public static func fileName(for title: String) -> String {
        let folded = title.folding(options: .diacriticInsensitive, locale: nil)
        var slug = ""
        var pendingDash = false
        for scalar in folded.unicodeScalars {
            let isPlain = scalar.isASCII && (CharacterSet.alphanumerics.contains(scalar))
            if isPlain {
                if pendingDash, !slug.isEmpty { slug.append("-") }
                slug.unicodeScalars.append(scalar)
                pendingDash = false
            } else {
                pendingDash = true
            }
        }
        return slug.isEmpty ? "ScooterPower" : "ScooterPower-" + slug
    }

    private static func timestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }

    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

/// Un point dans le carré unité : x vers la droite, y vers le bas.
public struct PlanePoint: Sendable, Equatable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// Aplatit un tracé pour le dessiner sans carte.
public enum RouteProjector {
    /// Ramène le tracé dans le carré unité en gardant ses proportions, centré,
    /// nord en haut. Un tracé réduit à un point se place au centre.
    public static func unitPoints(_ route: [Coordinate]) -> [PlanePoint] {
        let valid = route.filter { $0.latitude.isFinite && $0.longitude.isFinite }
        guard let first = valid.first else { return [] }

        var minLat = first.latitude, maxLat = first.latitude
        var minLon = first.longitude, maxLon = first.longitude
        for point in valid {
            minLat = min(minLat, point.latitude)
            maxLat = max(maxLat, point.latitude)
            minLon = min(minLon, point.longitude)
            maxLon = max(maxLon, point.longitude)
        }

        // Un degré de longitude raccourcit quand on s'éloigne de l'équateur.
        let shrink = cos((minLat + maxLat) / 2 * .pi / 180)
        let width = (maxLon - minLon) * shrink
        let height = maxLat - minLat
        let extent = max(width, height)
        guard extent > 0 else {
            return valid.map { _ in PlanePoint(x: 0.5, y: 0.5) }
        }

        let offsetX = (1 - width / extent) / 2
        let offsetY = (1 - height / extent) / 2
        return valid.map { point in
            let x = (point.longitude - minLon) * shrink / extent + offsetX
            let y = (maxLat - point.latitude) / extent + offsetY
            return PlanePoint(x: x, y: y)
        }
    }
}
