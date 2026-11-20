import XCTest
@testable import ScooterCore

final class RewardsTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        c.firstWeekday = 2
        return c
    }()

    /// Lundi 2 novembre 2026, 10 h UTC.
    private let monday = Date(timeIntervalSince1970: 1_793_613_600)

    private func ride(days: Double, hour: Double = 0, km: Double = 10, won: Bool? = nil) -> RideFact {
        RideFact(date: monday.addingTimeInterval(days * 86_400 + hour * 3600), distanceMeters: km * 1000,
                 movingSeconds: km * 120, maxSpeedKmh: 80, raceWon: won)
    }

    func testFirstTripAndDistanceBadges() {
        let rides = (0..<12).map { ride(days: Double($0), km: 10) }
        let badges = Set(Rewards.badges(rides, calendar: calendar).map(\.badge))
        XCTAssertTrue(badges.contains(.firstTrip))
        XCTAssertTrue(badges.contains(.trips10))
        XCTAssertTrue(badges.contains(.km100))
        XCTAssertFalse(badges.contains(.km1000))
        XCTAssertFalse(badges.contains(.longRide50))
    }

    func testTimeOfDayAndRaces() {
        // 6 h, 22 h (10 h + 12 h) et 12 h.
        let rides = [ride(days: 0, hour: -4), ride(days: 1, hour: 12), ride(days: 2, hour: 2, won: true)]
        let badges = Set(Rewards.badges(rides, calendar: calendar).map(\.badge))
        XCTAssertTrue(badges.contains(.earlyBird))
        XCTAssertTrue(badges.contains(.nightRider))
        XCTAssertTrue(badges.contains(.firstRaceWin))
        let day = Set(Rewards.badges([ride(days: 0, hour: 2)], calendar: calendar).map(\.badge))
        XCTAssertFalse(day.contains(.nightRider))
        XCTAssertFalse(day.contains(.earlyBird))
    }

    func testTinyTripsDoNotCount() {
        let rides = [RideFact(date: monday, distanceMeters: 50, movingSeconds: 20, maxSpeedKmh: 5)]
        XCTAssertTrue(Rewards.badges(rides, calendar: calendar).isEmpty)
    }

    func testWeekStreak() {
        // Trois semaines d'affilée, puis rien cette semaine : la série tient encore.
        let rides = [ride(days: -14), ride(days: -7), ride(days: 0)]
        XCTAssertEqual(Rewards.weekStreak(rides, now: monday.addingTimeInterval(3 * 86_400), calendar: calendar), 3)
        XCTAssertEqual(Rewards.weekStreak(rides, now: monday.addingTimeInterval(9 * 86_400), calendar: calendar), 3)
        // Deux semaines sans rouler : la série est perdue.
        XCTAssertEqual(Rewards.weekStreak(rides, now: monday.addingTimeInterval(16 * 86_400), calendar: calendar), 0)
        let four = (0..<4).map { ride(days: Double(-7 * $0)) }
        XCTAssertTrue(Rewards.badges(four, calendar: calendar).map(\.badge).contains(.weekStreak4))
    }

    func testWeekAndYearRecap() {
        let rides = [ride(days: 0, km: 12), ride(days: 2, km: 30, won: true), ride(days: 9, km: 5)]
        let week = Rewards.weekRecap(rides, containing: monday.addingTimeInterval(86_400), calendar: calendar)
        XCTAssertEqual(week.trips, 2)
        XCTAssertEqual(week.distanceMeters, 42_000, accuracy: 0.1)
        XCTAssertEqual(week.longestTripMeters, 30_000, accuracy: 0.1)
        XCTAssertEqual(week.racesWon, 1)
        XCTAssertEqual(week.favouriteWeekday, 4) // mercredi
        let year = Rewards.yearRecap(rides, year: 2026, calendar: calendar)
        XCTAssertEqual(year.trips, 3)
        XCTAssertEqual(year.favouriteHour, 10)
    }
}
