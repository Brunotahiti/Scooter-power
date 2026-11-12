import Foundation

/// Texte traduit dans la langue de l'interface. La clé est le texte français.
///
/// À utiliser partout où un `String` est attendu : SwiftUI ne traduit de
/// lui-même que les littéraux passés directement à `Text`, `Button`, etc.
func L(_ key: String.LocalizationValue) -> String {
    String(localized: key)
}
