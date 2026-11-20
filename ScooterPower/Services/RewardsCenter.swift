import Foundation
import ScooterCore
import UserNotifications

extension TripRecord {
    /// Ce que ce trajet apporte aux récompenses.
    var rideFact: RideFact {
        RideFact(date: startDate, distanceMeters: distanceMeters, movingSeconds: movingDuration,
                 maxSpeedKmh: maxSpeedKmh, raceWon: raceWon)
    }
}

extension Badge {
    var title: String {
        switch self {
        case .firstTrip: return L("Premier trajet")
        case .trips10: return L("10 trajets")
        case .trips50: return L("50 trajets")
        case .trips100: return L("100 trajets")
        case .km100: return L("100 km")
        case .km1000: return L("1 000 km")
        case .km5000: return L("5 000 km")
        case .km10000: return L("10 000 km")
        case .longRide50: return L("Grande balade")
        case .longRide100: return L("Long voyage")
        case .earlyBird: return L("Lève-tôt")
        case .nightRider: return L("Pilote de nuit")
        case .weekStreak4: return L("Un mois de suite")
        case .weekStreak12: return L("Trois mois de suite")
        case .firstRaceWin: return L("Premier ghost battu")
        case .raceWins10: return L("Chasseur de ghosts")
        }
    }

    var detail: String {
        switch self {
        case .firstTrip: return L("Enregistrer un premier trajet.")
        case .trips10: return L("Enregistrer 10 trajets.")
        case .trips50: return L("Enregistrer 50 trajets.")
        case .trips100: return L("Enregistrer 100 trajets.")
        case .km100: return L("Parcourir 100 km au total.")
        case .km1000: return L("Parcourir 1 000 km au total.")
        case .km5000: return L("Parcourir 5 000 km au total.")
        case .km10000: return L("Parcourir 10 000 km au total.")
        case .longRide50: return L("Faire un trajet de 50 km d'une traite.")
        case .longRide100: return L("Faire un trajet de 100 km d'une traite.")
        case .earlyBird: return L("Partir entre 5 h et 7 h du matin.")
        case .nightRider: return L("Partir entre 21 h et 5 h.")
        case .weekStreak4: return L("Rouler 4 semaines d'affilée.")
        case .weekStreak12: return L("Rouler 12 semaines d'affilée.")
        case .firstRaceWin: return L("Gagner une course contre un ghost.")
        case .raceWins10: return L("Gagner 10 courses contre un ghost.")
        }
    }
}

/// Badges gagnés et bilan de la semaine : annonce après un trajet, rappel du dimanche.
@MainActor
enum RewardsCenter {
    private static let weeklyID = "weeklyRecap"

    /// Après un trajet : annonce les badges qu'il vient de débloquer.
    static func tripSaved(previous: [TripRecord], with trip: TripRecord) {
        let before: Set<Badge> = Set(Rewards.badges(previous.map(\.rideFact)).map(\.badge))
        let all: [TripRecord] = previous + [trip]
        let after: [Badge] = Rewards.badges(all.map(\.rideFact)).map(\.badge)
        let new: [Badge] = after.filter { !before.contains($0) }
        for badge in new {
            LocalNotifier.post(id: "badge-" + badge.rawValue, title: L("Nouveau badge : \(badge.title)"), body: badge.detail)
        }
        if let first = new.first, AppSettings.shared.voiceEnabled {
            Announcer.shared.say(L("Nouveau badge : \(first.title) !"))
        }
        scheduleWeeklyRecap(trips: all)
    }

    /// Programme le bilan du dimanche 18 h avec les chiffres de la semaine en cours.
    static func scheduleWeeklyRecap(trips: [TripRecord], now: Date = Date()) {
        let calendar = Calendar.current
        let rides: [RideFact] = trips.map(\.rideFact)
        let week: RideRecap = Rewards.weekRecap(rides, containing: now)
        let streak: Int = Rewards.weekStreak(rides, now: now)
        guard let sunday = calendar.nextDate(
            after: now, matching: DateComponents(hour: 18, minute: 0, weekday: 1), matchingPolicy: .nextTime) else { return }
        let units: UnitSystem = AppSettings.shared.units
        let content = UNMutableNotificationContent()
        content.sound = .default
        if week.trips == 0 {
            guard streak > 0 else {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [weeklyID])
                return
            }
            content.title = L("Ta série est en jeu 🔥")
            content.body = L("\(String(streak)) semaines d'affilée : un petit trajet aujourd'hui pour la prolonger !")
        } else {
            let distance: String = Formatters.decimal(units.distance(fromMeters: week.distanceMeters), digits: 0)
                + " " + units.distanceUnit
            content.title = L("Ta semaine en scooter")
            content.body = week.trips == 1
                ? L("1 trajet, \(distance). Série : \(String(streak)) semaine(s) 🔥")
                : L("\(String(week.trips)) trajets, \(distance). Série : \(String(streak)) semaine(s) 🔥")
        }
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: sunday)
        let request = UNNotificationRequest(
            identifier: weeklyID, content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
        UNUserNotificationCenter.current().add(request)
    }
}
