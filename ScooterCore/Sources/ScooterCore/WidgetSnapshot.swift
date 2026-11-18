import Foundation

/// Résumé écrit par l'app pour le widget d'écran d'accueil, avec des textes
/// déjà mis en forme dans la langue et les unités de l'app.
public struct WidgetSnapshot: Codable, Sendable, Equatable {
    /// Groupe d'apps partagé entre l'app et l'extension des widgets.
    public static let appGroup = "group.com.brunotahiti.ScooterPower"
    static let key = "widgetSnapshot"

    public var weekTitle: String
    public var weekDistance: String
    public var weekTrips: String
    public var lastTitle: String
    public var lastDistance: String?
    public var lastMaxSpeed: String?
    public var lastDate: Date?
    public var startTitle: String
    public var emptyTitle: String
    /// Kilomètres (ou miles) des 7 derniers jours, du plus ancien à aujourd'hui.
    public var dailyDistances: [Double]

    public init(weekTitle: String, weekDistance: String, weekTrips: String, lastTitle: String,
                lastDistance: String?, lastMaxSpeed: String?, lastDate: Date?, startTitle: String,
                emptyTitle: String, dailyDistances: [Double]) {
        self.weekTitle = weekTitle
        self.weekDistance = weekDistance
        self.weekTrips = weekTrips
        self.lastTitle = lastTitle
        self.lastDistance = lastDistance
        self.lastMaxSpeed = lastMaxSpeed
        self.lastDate = lastDate
        self.startTitle = startTitle
        self.emptyTitle = emptyTitle
        self.dailyDistances = dailyDistances
    }

    /// Exemple affiché dans la galerie des widgets.
    public static let placeholder = WidgetSnapshot(
        weekTitle: "This week", weekDistance: "84 km", weekTrips: "6 trips", lastTitle: "Last trip",
        lastDistance: "18.4 km", lastMaxSpeed: "112 km/h", lastDate: Date(), startTitle: "Start",
        emptyTitle: "No trips yet", dailyDistances: [12, 0, 22, 8, 0, 24, 18])

    public static func load(from defaults: UserDefaults?) -> WidgetSnapshot? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    public func save(to defaults: UserDefaults?) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults?.set(data, forKey: Self.key)
    }

    /// Distances par jour sur les 7 derniers jours (le dernier élément est aujourd'hui).
    public static func dailyTotals(_ trips: [(date: Date, distance: Double)], now: Date,
                                   calendar: Calendar = .current) -> [Double] {
        let today: Date = calendar.startOfDay(for: now)
        var totals = [Double](repeating: 0, count: 7)
        for trip in trips {
            let day: Date = calendar.startOfDay(for: trip.date)
            guard let offset = calendar.dateComponents([.day], from: day, to: today).day,
                  offset >= 0, offset < 7 else { continue }
            totals[6 - offset] += trip.distance
        }
        return totals
    }
}
