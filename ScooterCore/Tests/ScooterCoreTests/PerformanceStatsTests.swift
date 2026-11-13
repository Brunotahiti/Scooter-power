import XCTest
@testable import ScooterCore

final class PerformanceStatsTests: XCTestCase {
    private func trip(distance: Double, moving: Double, total: Double, max: Double, peak: Double,
                      left: Double, right: Double, times: [SpeedInterval: TimeInterval] = [:]) -> TripSummary {
        TripSummary(distanceMeters: distance, maxSpeedKmh: max,
                    averageSpeedKmh: moving > 0 ? distance / moving * 3.6 : 0, peakAcceleration: peak,
                    maxLeanLeftDegrees: left, maxLeanRightDegrees: right,
                    movingDuration: moving, totalDuration: total, bestTimes: times)
    }

    private var trips: [TripSummary] {
        [
            trip(distance: 10_000, moving: 900, total: 1000, max: 92, peak: 3.0, left: 20, right: 28,
                 times: [.zeroTo50: 5.0, .fiftyTo90: 7.0]),
            trip(distance: 5000, moving: 300, total: 400, max: 110, peak: 4.0, left: 32, right: 12,
                 times: [.zeroTo50: 4.0]),
            trip(distance: 0, moving: 0, total: 30, max: 0, peak: 0, left: 0, right: 0),
        ]
    }

    func testTotalsAndMaxima() {
        let s = PerformanceStats(trips: trips)
        XCTAssertEqual(s.tripCount, 3)
        XCTAssertEqual(s.totalDistanceMeters, 15_000)
        XCTAssertEqual(s.totalMovingDuration, 1200)
        XCTAssertEqual(s.totalDuration, 1430)
        XCTAssertEqual(s.topSpeedKmh, 110)
        // Moyenne générale : distance totale sur temps de roulage total.
        XCTAssertEqual(s.overallAverageSpeedKmh, 45, accuracy: 1e-9)
        XCTAssertEqual(s.bestTripAverageSpeedKmh, 60, accuracy: 1e-9)
        XCTAssertEqual(s.bestPeakAcceleration, 4)
        XCTAssertEqual(s.maxLeanLeftDegrees, 32)
        XCTAssertEqual(s.maxLeanRightDegrees, 28)
    }

    func testAveragesIgnoreTripsWithoutMovement() {
        let s = PerformanceStats(trips: trips)
        // Le trajet à l'arrêt ne tire pas les moyennes vers zéro.
        XCTAssertEqual(s.averagePeakAcceleration, 3.5, accuracy: 1e-9)
        XCTAssertEqual(s.averageTopSpeedKmh, 101, accuracy: 1e-9)
        // Inclinaison maximale de chaque trajet, le plus grand des deux côtés : 28 et 32.
        XCTAssertEqual(s.averageMaxLeanDegrees, 30, accuracy: 1e-9)
    }

    func testIntervalStats() {
        let s = PerformanceStats(trips: trips)
        let fifty = s.intervals[.zeroTo50]!
        XCTAssertEqual(fifty.best, 4.0)
        XCTAssertEqual(fifty.worst, 5.0)
        XCTAssertEqual(fifty.average, 4.5, accuracy: 1e-9)
        XCTAssertEqual(fifty.count, 2)
        let roll = s.intervals[.fiftyTo90]!
        XCTAssertEqual(roll, PerformanceStats.IntervalStats(best: 7, average: 7, worst: 7, count: 1))
        XCTAssertNil(s.intervals[.zeroTo100])
    }

    func testEmptyAndInvalid() {
        let empty = PerformanceStats(trips: [])
        XCTAssertEqual(empty.tripCount, 0)
        XCTAssertEqual(empty.overallAverageSpeedKmh, 0)
        XCTAssertEqual(empty.averagePeakAcceleration, 0)
        XCTAssertTrue(empty.intervals.isEmpty)

        let odd = PerformanceStats(trips: [
            trip(distance: .nan, moving: 100, total: 100, max: .infinity, peak: .nan, left: .nan, right: 5,
                 times: [.zeroTo50: .nan, .zeroTo30: -1, .zeroTo80: 9]),
        ])
        XCTAssertEqual(odd.totalDistanceMeters, 0)
        XCTAssertEqual(odd.topSpeedKmh, 0)
        XCTAssertEqual(odd.bestPeakAcceleration, 0)
        XCTAssertEqual(odd.maxLeanRightDegrees, 5)
        XCTAssertEqual(Array(odd.intervals.keys), [.zeroTo80])
    }
}
