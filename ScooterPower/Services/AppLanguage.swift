import Foundation
import ObjectiveC
import ScooterCore

/// Langue de l'app, choisie dans ses réglages : anglais par défaut, quelle
/// que soit la langue de l'iPhone.
enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case french = "fr"

    static let defaultsKey = "appLanguage"

    var id: String { rawValue }

    /// Nom de la langue dans cette langue, pour le sélecteur.
    var nativeName: String {
        switch self {
        case .english: return "English"
        case .french: return "Français"
        }
    }

    /// Langue enregistrée, ou l'anglais.
    static var stored: AppLanguage {
        UserDefaults.standard.string(forKey: defaultsKey).flatMap(AppLanguage.init) ?? .english
    }

    /// Langue en cours, lue par `L(_:)` à chaque texte.
    private(set) static var current: AppLanguage = stored
    /// Dossier des traductions de la langue en cours (`en.lproj`, `fr.lproj`).
    private(set) static var bundle: Bundle = lprojBundle(for: stored)

    private static func lprojBundle(for language: AppLanguage) -> Bundle {
        guard let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path)
        else { return .main }
        return bundle
    }

    /// Langue de l'interface, avec les conventions de la région de l'iPhone
    /// (ordre jour/mois, heure sur 12 ou 24 h).
    var locale: Locale {
        let region: String = Locale.current.region?.identifier ?? (self == .french ? "FR" : "US")
        return Locale(identifier: rawValue + "_" + region)
    }

    /// Applique la langue : textes, séparateur décimal, et langue d'iOS pour
    /// l'app (demandes d'autorisation, écran verrouillé) au prochain lancement.
    static func apply(_ language: AppLanguage) {
        installOverride()
        current = language
        bundle = lprojBundle(for: language)
        Formatters.decimalSeparator = language == .french ? "," : "."
        UserDefaults.standard.set(language.rawValue, forKey: defaultsKey)
        UserDefaults.standard.set([language.rawValue], forKey: "AppleLanguages")
    }
}

// MARK: - Langue de toute l'app

extension AppLanguage {
    private static var overrideInstalled = false

    /// Fait passer toutes les traductions de l'app par la langue choisie.
    ///
    /// Sans cela, les textes que SwiftUI traduit de lui-même (`Text("…")`,
    /// `Button("…")`…) suivraient la langue de l'iPhone, et l'écran mélangerait
    /// français et anglais. `Bundle.main` est remplacé par une sous-classe qui
    /// lit les traductions dans `en.lproj` ou `fr.lproj` selon le réglage.
    fileprivate static func installOverride() {
        guard !overrideInstalled else { return }
        overrideInstalled = true
        object_setClass(Bundle.main, LanguageBundle.self)
    }
}

/// `Bundle.main`, dont les traductions viennent de la langue choisie dans l'app.
private final class LanguageBundle: Bundle {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        let chosen: Bundle = AppLanguage.bundle
        // `AppLanguage.bundle` vaut `Bundle.main` si le dossier .lproj manque : pas de boucle.
        guard chosen !== self else {
            return super.localizedString(forKey: key, value: value, table: tableName)
        }
        return chosen.localizedString(forKey: key, value: value, table: tableName)
    }
}
