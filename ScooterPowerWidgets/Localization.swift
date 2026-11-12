import Foundation

/// Texte traduit dans la langue de l'interface. La clé est le texte français.
func L(_ key: String.LocalizationValue) -> String {
    String(localized: key)
}
