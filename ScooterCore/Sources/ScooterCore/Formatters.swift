import Foundation

/// Formatage des nombres, sans `Locale` pour rester identique sur toutes les
/// plateformes. Le séparateur décimal se règle une fois au lancement.
public enum Formatters {
    /// Virgule par défaut (français). L'app le remplace par celui de la langue
    /// de l'interface au démarrage.
    public static var decimalSeparator = ","

    /// `HH:MM:SS`. Les durées négatives ou non finies donnent `00:00:00`.
    public static func duration(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds > 0 else { return "00:00:00" }
        let total = Int(min(seconds, 359_999))
        return String(format: "%02d:%02d:%02d", total / 3600, (total / 60) % 60, total % 60)
    }

    /// Nombre à virgule décimale. `--` pour une valeur non finie.
    public static func decimal(_ value: Double, digits: Int) -> String {
        guard value.isFinite else { return "--" }
        let text = String(format: "%.\(max(0, digits))f", value)
        return text.replacingOccurrences(of: ".", with: decimalSeparator)
    }

    /// Comme `decimal`, avec un signe explicite : `+2,8`, `−1,3`, `0,0`.
    public static func signed(_ value: Double, digits: Int) -> String {
        guard value.isFinite else { return "--" }
        let magnitude = decimal(abs(value), digits: digits)
        // Le signe est décidé après arrondi, pour ne jamais afficher « −0,0 ».
        let isZero = !magnitude.contains { $0.isNumber && $0 != "0" }
        if isZero { return magnitude }
        return (value < 0 ? "\u{2212}" : "+") + magnitude
    }
}
