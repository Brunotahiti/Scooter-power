import Foundation

/// Règles des classements en ligne entre scooters du même modèle.
public enum Leaderboard {
    /// Clé de modèle commune : « Yamaha  X-Max 300 » et « yamaha xmax300 » donnent « yamahaxmax300 ».
    public static func modelKey(_ model: String) -> String {
        let folded: String = model.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        return String(folded.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.map(Character.init))
    }

    /// Identifiant stable d'une plage : « 0-100kmh », « 0-60mph ».
    public static func intervalID(_ interval: SpeedInterval) -> String {
        "\(interval.from)-\(interval.to)\(interval.unit.rawValue)"
    }

    public static func interval(fromID id: String) -> SpeedInterval? {
        SpeedInterval.all.first { intervalID($0) == id }
    }

    /// Un temps est publié s'il est plausible (moins de 1 g de moyenne, moins d'une minute).
    public static func isPublishable(_ seconds: TimeInterval, for interval: SpeedInterval) -> Bool {
        seconds.isFinite && seconds >= interval.minPlausibleTime && seconds < 60
    }

    /// Nom d'enregistrement CloudKit : un seul temps par pilote, modèle et plage.
    public static func recordName(riderID: String, modelKey: String, intervalID: String) -> String {
        "lb_" + riderID + "_" + String(modelKey.prefix(60)) + "_" + intervalID
    }

    /// Rang (à partir de 1) d'un temps dans une liste triée du plus rapide au plus lent.
    public static func rank(of seconds: TimeInterval, in sorted: [TimeInterval]) -> Int {
        (sorted.firstIndex { $0 > seconds } ?? sorted.count) + 1
    }
}
