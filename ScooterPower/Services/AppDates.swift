import Foundation

/// Dates affichées dans la langue de l'app, avec les conventions
/// de la région de l'iPhone (ordre jour/mois, heure sur 12 ou 24 h) :
/// « 16 Nov 2026 at 19:57 » en France, « Nov 16, 2026 at 7:57 PM » aux États-Unis.
enum AppDates {
    static var locale: Locale { AppLanguage.current.locale }

    static func dateTime(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(locale))
    }

    static func day(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(locale))
    }

    static func time(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(locale))
    }
}
