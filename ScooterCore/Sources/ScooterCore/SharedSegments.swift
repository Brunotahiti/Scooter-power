import Foundation

/// Segments partagés avec la communauté : chacun voit les segments de sa
/// région, avec un classement ; le meilleur temps est le « Roi de la route ».
public enum SharedSegments {
    /// Zone géographique d'environ 11 km de côté (0,1°), pour trouver les segments proches.
    public static func cell(for point: Coordinate) -> String {
        let lat = Int((point.latitude * 10).rounded(.down))
        let lon = Int((point.longitude * 10).rounded(.down))
        return "\(lat)_\(lon)"
    }

    /// La zone du point et ses 8 voisines.
    public static func nearbyCells(around point: Coordinate) -> [String] {
        let lat = Int((point.latitude * 10).rounded(.down))
        let lon = Int((point.longitude * 10).rounded(.down))
        var cells: [String] = []
        for dLat in -1...1 {
            for dLon in -1...1 {
                cells.append("\(lat + dLat)_\(lon + dLon)")
            }
        }
        return cells
    }

    /// Zones couvrant une liste de points (départs des derniers trajets), sans doublon.
    public static func cells(around points: [Coordinate], limit: Int = 30) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for point in points {
            for cell in nearbyCells(around: point) where !seen.contains(cell) {
                seen.insert(cell)
                result.append(cell)
            }
        }
        return Array(result.prefix(limit))
    }

    /// Temps publiable : vitesse moyenne entre 5 et 150 km/h sur le segment.
    public static func isPlausible(seconds: TimeInterval, lengthMeters: Double) -> Bool {
        guard seconds.isFinite, seconds > 0, lengthMeters > 0 else { return false }
        let kmh: Double = lengthMeters / seconds * 3.6
        return kmh >= 5 && kmh <= 150
    }

    /// Tracé complet du segment : « lat,lon;lat,lon » à 6 décimales (≈ 10 cm).
    public static func encodePath(_ path: [Coordinate]) -> String {
        path.map { String(format: "%.6f,%.6f", $0.latitude, $0.longitude) }.joined(separator: ";")
    }

    public static func decodePath(_ text: String) -> [Coordinate] {
        LiveShare.decodeTrail(text)
    }

    /// Nom d'enregistrement d'un temps : un seul par pilote et par segment.
    public static func timeRecordName(segmentID: String, riderID: String) -> String {
        "st_" + segmentID + "_" + riderID
    }
}
