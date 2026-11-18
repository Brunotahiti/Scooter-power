import XCTest
@testable import ScooterCore

final class WidgetSnapshotTests: XCTestCase {
    func testRoundTrip() {
        let defaults = UserDefaults(suiteName: "WidgetSnapshotTests")!
        defaults.removePersistentDomain(forName: "WidgetSnapshotTests")
        XCTAssertNil(WidgetSnapshot.load(from: defaults))
        WidgetSnapshot.placeholder.save(to: defaults)
        XCTAssertEqual(WidgetSnapshot.load(from: defaults), WidgetSnapshot.placeholder)
    }

    func testDailyTotals() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let trips: [(date: Date, distance: Double)] = [
            (now, 10), (now.addingTimeInterval(-3600), 5),
            (now.addingTimeInterval(-86_400 * 2), 7), (now.addingTimeInterval(-86_400 * 9), 99),
        ]
        let totals = WidgetSnapshot.dailyTotals(trips, now: now, calendar: calendar)
        XCTAssertEqual(totals.count, 7)
        XCTAssertEqual(totals[6], 15)
        XCTAssertEqual(totals[4], 7)
        XCTAssertEqual(totals.reduce(0, +), 22)
    }
}
