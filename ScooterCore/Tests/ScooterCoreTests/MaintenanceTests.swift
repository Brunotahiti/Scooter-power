import XCTest
@testable import ScooterCore

final class MaintenanceTests: XCTestCase {
    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func days(_ n: Int) -> Date { start.addingTimeInterval(Double(n) * 86_400) }

    func testKilometresOk() {
        let s = MaintenanceStatus.compute(intervalKm: 5000, intervalMonths: nil, lastDoneKm: 10_000,
                                          lastDoneDate: start, currentKm: 12_000, now: start, calendar: calendar)
        XCTAssertEqual(s.remainingKm, 3000)
        XCTAssertEqual(s.progress, 0.4, accuracy: 1e-9)
        XCTAssertEqual(s.state, .ok)
    }

    func testKilometresSoonThenDue() {
        let soon = MaintenanceStatus.compute(intervalKm: 5000, intervalMonths: nil, lastDoneKm: 0,
                                             lastDoneDate: start, currentKm: 4600, now: start, calendar: calendar)
        XCTAssertEqual(soon.state, .soon)
        let due = MaintenanceStatus.compute(intervalKm: 5000, intervalMonths: nil, lastDoneKm: 0,
                                            lastDoneDate: start, currentKm: 5200, now: start, calendar: calendar)
        XCTAssertEqual(due.state, .due)
        XCTAssertEqual(due.remainingKm, -200)
        XCTAssertEqual(due.progress, 1)
    }

    func testMonthsDrivesStateWhenLittleRidden() {
        let s = MaintenanceStatus.compute(intervalKm: 5000, intervalMonths: 12, lastDoneKm: 0,
                                          lastDoneDate: start, currentKm: 800, now: days(350), calendar: calendar)
        XCTAssertEqual(s.state, .soon)
        XCTAssertNotNil(s.remainingDays)
        let late = MaintenanceStatus.compute(intervalKm: 5000, intervalMonths: 12, lastDoneKm: 0,
                                             lastDoneDate: start, currentKm: 800, now: days(400), calendar: calendar)
        XCTAssertEqual(late.state, .due)
        XCTAssertLessThan(late.remainingDays ?? 0, 0)
    }

    func testFuelEconomyFullToFull() {
        // Premier plein ignoré ; 9 + 10 L sur 500 km → 3,8 L/100 km.
        let fills = [FuelFill(odometerKm: 1000, liters: 12), FuelFill(odometerKm: 1250, liters: 9),
                     FuelFill(odometerKm: 1500, liters: 10)]
        XCTAssertEqual(FuelEconomy.litersPer100Km(fills.shuffled()) ?? 0, 3.8, accuracy: 1e-9)
        XCTAssertNil(FuelEconomy.litersPer100Km([fills[0]]))
        XCTAssertEqual(FuelEconomy.mpg(fromLitersPer100Km: 4.7), 50.05, accuracy: 0.01)
    }

    func testDefaultIntervalsExist() {
        for kind in MaintenanceKind.allCases {
            let interval = kind.defaultInterval
            XCTAssertTrue(interval.km != nil || interval.months != nil, "\(kind)")
        }
    }
}
