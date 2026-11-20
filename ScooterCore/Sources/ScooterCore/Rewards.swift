import Foundation

/// Ce qu'un trajet apporte aux récompenses (indépendant de SwiftData).
public struct RideFact: Sendable, Equatable {
    public var date: Date
    public var distanceMeters: Double
    public var movingSeconds: TimeInterval
    public var maxSpeedKmh: Double
    /// Vrai : course contre le ghost gagnée ; faux : perdue ; nil : pas de course.
    public var raceWon: Bool?

    public init(date: Date, distanceMeters: Double, movingSeconds: TimeInterval, maxSpeedKmh: Double, raceWon: Bool? = nil) {
        self.date = date
        self.distanceMeters = distanceMeters
        self.movingSeconds = movingSeconds
        self.maxSpeedKmh = maxSpeedKmh
        self.raceWon = raceWon
    }
}

/// Les badges à débloquer. Aucun ne récompense la vitesse : on salue la
/// régularité, la distance et les défis, pas la prise de risque.
public enum Badge: String, CaseIterable, Sendable, Codable {
    case firstTrip, trips10, trips50, trips100
    case km100, km1000, km5000, km10000
    case longRide50, longRide100
    case earlyBird, nightRider
    case weekStreak4, weekStreak12
    case firstRaceWin, raceWins10

    public var icon: String {
        switch self {
        case .firstTrip: return "flag.fill"
        case .trips10, .trips50, .trips100: return "repeat"
        case .km100, .km1000, .km5000, .km10000: return "road.lanes"
        case .longRide50, .longRide100: return "map.fill"
        case .earlyBird: return "sunrise.fill"
        case .nightRider: return "moon.stars.fill"
        case .weekStreak4, .weekStreak12: return "flame.fill"
        case .firstRaceWin, .raceWins10: return "trophy.fill"
        }
    }
}

/// Un badge débloqué, avec la date du trajet qui l'a apporté.
public struct UnlockedBadge: Sendable, Equatable {
    public var badge: Badge
    public var date: Date
}

/// Bilan d'une période (semaine ou année).
public struct RideRecap: Sendable, Equatable {
    public var start: Date
    public var end: Date
    public var trips: Int
    public var distanceMeters: Double
    public var movingSeconds: TimeInterval
    public var topSpeedKmh: Double
    public var longestTripMeters: Double
    public var racesWon: Int
    /// Jour de la semaine le plus roulé (1 = dimanche … 7 = samedi), nil sans trajet.
    public var favouriteWeekday: Int?
    /// Heure de départ la plus fréquente (0–23), nil sans trajet.
    public var favouriteHour: Int?
}

public enum Rewards {
    /// Badges débloqués, dans l'ordre où ils l'ont été.
    public static func badges(_ rides: [RideFact], calendar: Calendar = .current) -> [UnlockedBadge] {
        let sorted: [RideFact] = rides.sorted { $0.date < $1.date }
        var unlocked: [Badge: Date] = [:]
        var count = 0
        var total: Double = 0
        var wins = 0
        var weeks: [Date] = []
        func unlock(_ badge: Badge, _ date: Date) {
            if unlocked[badge] == nil { unlocked[badge] = date }
        }
        for ride in sorted where ride.distanceMeters >= 200 {
            count += 1
            total += ride.distanceMeters
            if count >= 1 { unlock(.firstTrip, ride.date) }
            if count >= 10 { unlock(.trips10, ride.date) }
            if count >= 50 { unlock(.trips50, ride.date) }
            if count >= 100 { unlock(.trips100, ride.date) }
            if total >= 100_000 { unlock(.km100, ride.date) }
            if total >= 1_000_000 { unlock(.km1000, ride.date) }
            if total >= 5_000_000 { unlock(.km5000, ride.date) }
            if total >= 10_000_000 { unlock(.km10000, ride.date) }
            if ride.distanceMeters >= 50_000 { unlock(.longRide50, ride.date) }
            if ride.distanceMeters >= 100_000 { unlock(.longRide100, ride.date) }
            let hour: Int = calendar.component(.hour, from: ride.date)
            if hour >= 5 && hour < 7 { unlock(.earlyBird, ride.date) }
            if hour >= 21 || hour < 5 { unlock(.nightRider, ride.date) }
            if ride.raceWon == true {
                wins += 1
                unlock(.firstRaceWin, ride.date)
                if wins >= 10 { unlock(.raceWins10, ride.date) }
            }
            if let week = calendar.dateInterval(of: .weekOfYear, for: ride.date)?.start, weeks.last != week {
                weeks.append(week)
                let streak: Int = streakLength(weeks, calendar: calendar)
                if streak >= 4 { unlock(.weekStreak4, ride.date) }
                if streak >= 12 { unlock(.weekStreak12, ride.date) }
            }
        }
        return unlocked.map { UnlockedBadge(badge: $0.key, date: $0.value) }.sorted { $0.date < $1.date }
    }

    /// Nombre de semaines d'affilée avec au moins un trajet, jusqu'à aujourd'hui.
    /// La semaine en cours compte si l'on a roulé ; sinon la série court encore
    /// depuis la semaine dernière (on a jusqu'à dimanche pour la prolonger).
    public static func weekStreak(_ rides: [RideFact], now: Date, calendar: Calendar = .current) -> Int {
        let weeks: Set<Date> = Set(rides.filter { $0.distanceMeters >= 200 }.compactMap {
            calendar.dateInterval(of: .weekOfYear, for: $0.date)?.start
        })
        guard var week = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return 0 }
        if !weeks.contains(week) {
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: week) else { return 0 }
            week = previous
        }
        var streak = 0
        while weeks.contains(week) {
            streak += 1
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: week) else { break }
            week = previous
        }
        return streak
    }

    /// Longueur de la série qui se termine à la dernière semaine de la liste (triée).
    static func streakLength(_ weeks: [Date], calendar: Calendar) -> Int {
        guard var current = weeks.last else { return 0 }
        var streak = 1
        for week in weeks.dropLast().reversed() {
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: current), previous == week else { break }
            streak += 1
            current = week
        }
        return streak
    }

    /// Bilan des trajets entre `start` (inclus) et `end` (exclu).
    public static func recap(_ rides: [RideFact], from start: Date, to end: Date, calendar: Calendar = .current) -> RideRecap {
        let inside: [RideFact] = rides.filter { $0.date >= start && $0.date < end && $0.distanceMeters >= 200 }
        var weekdays: [Int: Double] = [:]
        var hours: [Int: Int] = [:]
        for ride in inside {
            weekdays[calendar.component(.weekday, from: ride.date), default: 0] += ride.distanceMeters
            hours[calendar.component(.hour, from: ride.date), default: 0] += 1
        }
        return RideRecap(
            start: start, end: end, trips: inside.count,
            distanceMeters: inside.reduce(0) { $0 + $1.distanceMeters },
            movingSeconds: inside.reduce(0) { $0 + $1.movingSeconds },
            topSpeedKmh: inside.map(\.maxSpeedKmh).max() ?? 0,
            longestTripMeters: inside.map(\.distanceMeters).max() ?? 0,
            racesWon: inside.filter { $0.raceWon == true }.count,
            favouriteWeekday: weekdays.max { $0.value < $1.value || ($0.value == $1.value && $0.key > $1.key) }?.key,
            favouriteHour: hours.max { $0.value < $1.value || ($0.value == $1.value && $0.key > $1.key) }?.key)
    }

    /// Bilan de la semaine qui contient `date`.
    public static func weekRecap(_ rides: [RideFact], containing date: Date, calendar: Calendar = .current) -> RideRecap {
        let interval = calendar.dateInterval(of: .weekOfYear, for: date) ?? DateInterval(start: date, duration: 7 * 86_400)
        return recap(rides, from: interval.start, to: interval.end, calendar: calendar)
    }

    /// Bilan de l'année civile `year`.
    public static func yearRecap(_ rides: [RideFact], year: Int, calendar: Calendar = .current) -> RideRecap {
        let start: Date = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? Date()
        let end: Date = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1)) ?? Date()
        return recap(rides, from: start, to: end, calendar: calendar)
    }
}
