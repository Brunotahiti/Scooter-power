import Foundation
import ScooterCore
import WidgetKit

/// Met à jour le widget d'écran d'accueil après chaque trajet, et quand la
/// langue ou les unités changent. Les textes sont prêts à afficher.
@MainActor
enum WidgetSync {
    static func update(trips: [TripRecord]) {
        let settings = AppSettings.shared
        let units: UnitSystem = settings.units
        let now = Date()
        let weekStart: Date = Calendar.current.date(byAdding: .day, value: -6, to: Calendar.current.startOfDay(for: now)) ?? now
        let week: [TripRecord] = trips.filter { $0.startDate >= weekStart }
        let weekMeters: Double = week.reduce(0) { $0 + $1.distanceMeters }
        let last: TripRecord? = trips.max { $0.startDate < $1.startDate }
        let daily: [Double] = WidgetSnapshot.dailyTotals(
            trips.map { (date: $0.startDate, distance: units.distance(fromMeters: $0.distanceMeters)) }, now: now)

        let snapshot = WidgetSnapshot(
            weekTitle: L("7 derniers jours"),
            weekDistance: distance(weekMeters, units: units, digits: 0),
            weekTrips: week.count == 1 ? L("1 trajet") : L("\(String(week.count)) trajets"),
            lastTitle: L("Dernier trajet"),
            lastDistance: last.map { distance($0.distanceMeters, units: units, digits: 1) },
            lastMaxSpeed: last.map {
                Formatters.decimal(units.speed(fromKmh: $0.maxSpeedKmh), digits: 0) + " " + units.speedUnit
            },
            lastDate: last?.startDate,
            startTitle: L("Démarrer"),
            emptyTitle: L("Aucun trajet"),
            dailyDistances: daily)
        snapshot.save(to: UserDefaults(suiteName: WidgetSnapshot.appGroup))
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func distance(_ meters: Double, units: UnitSystem, digits: Int) -> String {
        Formatters.decimal(units.distance(fromMeters: meters), digits: digits) + " " + units.distanceUnit
    }
}
