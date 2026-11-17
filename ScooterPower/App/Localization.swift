import Foundation

/// Texte traduit dans la langue choisie dans les réglages de l'app. La clé est
/// le texte français.
///
/// À utiliser partout où un `String` est attendu : SwiftUI traduit de lui-même
/// les littéraux passés directement à `Text`, `Button`, etc., d'après la
/// langue posée dans l'environnement (`\.locale`).
func L(_ key: String.LocalizationValue) -> String {
    String(localized: key, bundle: AppLanguage.bundle)
}
