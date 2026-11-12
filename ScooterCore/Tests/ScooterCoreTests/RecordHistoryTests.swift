import XCTest
@testable import ScooterCore

final class RecordHistoryTests: XCTestCase {
    private func day(_ n: Int) -> Date { Date(timeIntervalSinceReferenceDate: Double(n) * 86_400) }

    func testProgressionKeepsOnlyImprovementsInDateOrder() {
        // Les trajets arrivent du plus récent au plus ancien, comme dans l'historique.
        let trips: [RecordHistory.Trip] = [
            .init(date: day(4), times: [.zeroTo50: 4.6]),
            .init(date: day(3), times: [.zeroTo50: 5.0]),
            .init(date: day(2), times: [.zeroTo50: 4.9, .fiftyTo90: 7.0]),
            .init(date: day(1), times: [.zeroTo50: 5.2]),
        ]
        let p = RecordHistory.progression(trips)
        XCTAssertEqual(p[.zeroTo50], [
            RecordPoint(time: 5.2, date: day(1), tripIndex: 3),
            RecordPoint(time: 4.9, date: day(2), tripIndex: 2),
            RecordPoint(time: 4.6, date: day(4), tripIndex: 0),
        ])
        XCTAssertEqual(p[.fiftyTo90], [RecordPoint(time: 7.0, date: day(2), tripIndex: 2)])
        XCTAssertNil(p[.zeroTo80])
    }

    func testCurrentRecordIsTheLastPoint() {
        let trips: [RecordHistory.Trip] = [
            .init(date: day(1), times: [.zeroTo30: 2.4]),
            .init(date: day(2), times: [.zeroTo30: 2.1]),
        ]
        XCTAssertEqual(RecordHistory.progression(trips)[.zeroTo30]?.last?.time, 2.1)
    }

    func testEqualLookingTimeIsNotAnImprovement() {
        let trips: [RecordHistory.Trip] = [
            .init(date: day(1), times: [.zeroTo50: 4.94]),
            .init(date: day(2), times: [.zeroTo50: 4.86]),
        ]
        // Tous deux affichés « 4,9 s » : un seul point.
        XCTAssertEqual(RecordHistory.progression(trips)[.zeroTo50]?.count, 1)
    }

    func testInvalidTimesAndEmptyHistory() {
        XCTAssertTrue(RecordHistory.progression([]).isEmpty)
        let trips: [RecordHistory.Trip] = [.init(date: day(1), times: [.zeroTo50: .nan, .zeroTo30: 0, .zeroTo80: -2])]
        XCTAssertTrue(RecordHistory.progression(trips).isEmpty)
    }
}
