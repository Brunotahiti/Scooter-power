import XCTest
@testable import ScooterCore

final class LeaderboardTests: XCTestCase {
    func testModelKeyIsForgiving() {
        XCTAssertEqual(Leaderboard.modelKey("Yamaha  X-Max 300"), "yamahaxmax300")
        XCTAssertEqual(Leaderboard.modelKey("yamaha xmax300"), "yamahaxmax300")
        XCTAssertEqual(Leaderboard.modelKey("Piaggio Bévérly"), "piaggiobeverly")
        XCTAssertEqual(Leaderboard.modelKey("  "), "")
    }

    func testIntervalIDRoundTrip() {
        for interval in SpeedInterval.all {
            XCTAssertEqual(Leaderboard.interval(fromID: Leaderboard.intervalID(interval)), interval)
        }
        XCTAssertEqual(Leaderboard.intervalID(.zeroTo100), "0-100kmh")
        XCTAssertEqual(Leaderboard.intervalID(.zeroTo60mph), "0-60mph")
        XCTAssertNil(Leaderboard.interval(fromID: "0-999kmh"))
    }

    func testPlausibility() {
        XCTAssertFalse(Leaderboard.isPublishable(1.5, for: .zeroTo100))
        XCTAssertTrue(Leaderboard.isPublishable(7.8, for: .zeroTo100))
        XCTAssertFalse(Leaderboard.isPublishable(75, for: .zeroTo100))
        XCTAssertFalse(Leaderboard.isPublishable(.nan, for: .zeroTo50))
    }

    func testRank() {
        let times: [TimeInterval] = [4.1, 4.5, 5.0]
        XCTAssertEqual(Leaderboard.rank(of: 3.9, in: times), 1)
        XCTAssertEqual(Leaderboard.rank(of: 4.5, in: times), 3)
        XCTAssertEqual(Leaderboard.rank(of: 6, in: times), 4)
    }

    func testRecordNameIsStable() {
        XCTAssertEqual(Leaderboard.recordName(riderID: "A", modelKey: "tmax", intervalID: "0-50kmh"), "lb_A_tmax_0-50kmh")
    }
}
