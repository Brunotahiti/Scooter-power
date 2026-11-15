import XCTest
@testable import ScooterCore

final class TripTrophiesTests: XCTestCase {
    private func trip(top: Double = 90, peak: Double = 3, left: Double = 20, right: Double = 20,
                      times: [SpeedInterval: TimeInterval] = [:]) -> TripSummary {
        TripSummary(distanceMeters: 5000, maxSpeedKmh: top, averageSpeedKmh: 40, peakAcceleration: peak,
                    maxLeanLeftDegrees: left, maxLeanRightDegrees: right, movingDuration: 400,
                    totalDuration: 450, bestTimes: times)
    }

    func testBeatenRecordsBecomeTrophiesWithThePreviousValue() {
        let history = [
            trip(top: 95, peak: 3.1, left: 25, right: 22, times: [.zeroTo50: 5.2, .fiftyTo90: 6.8]),
            trip(top: 101, peak: 2.9, left: 18, right: 28, times: [.zeroTo50: 4.9]),
        ]
        let now = trip(top: 104, peak: 3.0, left: 31, right: 12, times: [.zeroTo50: 4.6, .fiftyTo90: 7.0])
        let trophies = TripTrophies.compute(trip: now, history: history)
        XCTAssertEqual(trophies, [
            Trophy(kind: .interval(.zeroTo50), value: 4.6, previous: 4.9),
            Trophy(kind: .topSpeed, value: 104, previous: 101),
            Trophy(kind: .maxLean, value: 31, previous: 28),
        ])
    }

    func testNoTrophyWithoutHistoryOrForAFirstMeasurement() {
        let now = trip(top: 120, peak: 4, times: [.zeroTo50: 4])
        XCTAssertTrue(TripTrophies.compute(trip: now, history: []).isEmpty)
        // Premier 0–100 jamais mesuré : ce n'est pas un record battu.
        let history = [trip(times: [.zeroTo50: 5])]
        let trophies = TripTrophies.compute(trip: trip(times: [.zeroTo100: 11]), history: history)
        XCTAssertFalse(trophies.contains { $0.kind == .interval(.zeroTo100) })
    }

    func testEqualLookingValuesAreNotRecords() {
        let history = [trip(top: 100.2, peak: 3.04, left: 20.4, times: [.zeroTo50: 4.94])]
        // 100,4 s'affiche 100 comme 100,2 ; 3,02 et 3,04 s'affichent 3,0 ; 4,86 et 4,94 s'affichent 4,9.
        let now = trip(top: 100.4, peak: 3.02, left: 20.3, times: [.zeroTo50: 4.86])
        XCTAssertTrue(TripTrophies.compute(trip: now, history: history).isEmpty)
    }

    func testPeakThrustAndInvalidValues() {
        let history = [trip(peak: 3.0), trip(peak: .nan)]
        let trophies = TripTrophies.compute(trip: trip(peak: 3.5, times: [.zeroTo50: .nan]), history: history)
        XCTAssertEqual(trophies, [Trophy(kind: .peakAcceleration, value: 3.5, previous: 3.0)])
        XCTAssertTrue(TripTrophies.compute(trip: trip(top: .infinity), history: [trip()]).isEmpty)
    }

    func testImprovementPercent() {
        XCTAssertEqual(Trophy(kind: .interval(.zeroTo50), value: 4.5, previous: 5).improvementPercent, 10, accuracy: 1e-9)
        XCTAssertEqual(Trophy(kind: .topSpeed, value: 110, previous: 100).improvementPercent, 10, accuracy: 1e-9)
    }
}
