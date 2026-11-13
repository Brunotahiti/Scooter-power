import XCTest
@testable import ScooterCore

final class TripComparisonTests: XCTestCase {
    private func trip(distance: Double = 10_000, max: Double = 90, average: Double = 45, peak: Double = 3,
                      left: Double = 20, right: Double = 20, moving: Double = 900, total: Double = 1000,
                      best50: Double? = nil, best80: Double? = nil) -> TripSummary {
        TripSummary(distanceMeters: distance, maxSpeedKmh: max, averageSpeedKmh: average, peakAcceleration: peak,
                    maxLeanLeftDegrees: left, maxLeanRightDegrees: right, movingDuration: moving,
                    totalDuration: total, best50: best50, best80: best80)
    }

    private func row(_ metric: ComparisonMetric, _ a: TripSummary, _ b: TripSummary) -> ComparisonRow {
        TripComparison.rows(a, b).first { $0.metric == metric }!
    }

    func testOneRowPerMetricInDisplayOrder() {
        let rows = TripComparison.rows(trip(), trip())
        XCTAssertEqual(rows.map(\.metric), [
            .distance, .movingDuration, .totalDuration, .maxSpeed, .averageSpeed,
            .sprint30, .sprint50, .sprint80, .sprint100, .roll90, .roll100,
            .peakAcceleration, .maxLeanLeft, .maxLeanRight,
        ])
    }

    func testHigherIsBetterMetrics() {
        XCTAssertEqual(row(.maxSpeed, trip(max: 95), trip(max: 88)).winner, .first)
        XCTAssertEqual(row(.averageSpeed, trip(average: 40), trip(average: 52)).winner, .second)
        XCTAssertEqual(row(.peakAcceleration, trip(peak: 3.6), trip(peak: 2.8)).winner, .first)
        XCTAssertEqual(row(.maxLeanLeft, trip(left: 18), trip(left: 31)).winner, .second)
        XCTAssertEqual(row(.maxLeanRight, trip(right: 25), trip(right: 12)).winner, .first)
    }

    func testLowerIsBetterForSprints() {
        XCTAssertEqual(row(.sprint50, trip(best50: 4.2), trip(best50: 4.9)).winner, .first)
        XCTAssertEqual(row(.sprint80, trip(best80: 9.9), trip(best80: 8.7)).winner, .second)
    }

    func testEveryAccelerationIntervalIsCompared() {
        let a = TripSummary(distanceMeters: 0, maxSpeedKmh: 0, averageSpeedKmh: 0, peakAcceleration: 0,
                            maxLeanLeftDegrees: 0, maxLeanRightDegrees: 0, movingDuration: 0, totalDuration: 0,
                            bestTimes: [.zeroTo30: 2.1, .fiftyTo90: 6.4, .fiftyTo100: 9.0])
        let b = TripSummary(distanceMeters: 0, maxSpeedKmh: 0, averageSpeedKmh: 0, peakAcceleration: 0,
                            maxLeanLeftDegrees: 0, maxLeanRightDegrees: 0, movingDuration: 0, totalDuration: 0,
                            bestTimes: [.zeroTo30: 2.6, .fiftyTo90: 5.8])
        XCTAssertEqual(row(.sprint30, a, b).winner, .first)
        XCTAssertEqual(row(.roll90, a, b).winner, .second)
        XCTAssertEqual(row(.roll90, a, b).second, 5.8)
        XCTAssertEqual(row(.roll100, a, b).winner, .first)
        XCTAssertEqual(row(.sprint50, a, b).winner, .none)
        XCTAssertEqual(ComparisonMetric.sprint100.interval, .zeroTo100)
    }

    func testBestTimesAndLegacyFieldsAgree() {
        let s = trip(best50: 4.2, best80: 9.1)
        XCTAssertEqual(s.bestTimes, [.zeroTo50: 4.2, .zeroTo80: 9.1])
        XCTAssertEqual(s.best50, 4.2)
        XCTAssertEqual(s.best(.zeroTo80), 9.1)
        XCTAssertNil(s.best(.fiftyTo90))
    }

    func testMissingSprintLosesAndBothMissingHaveNoWinner() {
        let withTime = row(.sprint50, trip(best50: 5), trip(best50: nil))
        XCTAssertEqual(withTime.winner, .first)
        XCTAssertEqual(withTime.first, 5)
        XCTAssertNil(withTime.second)
        XCTAssertEqual(row(.sprint50, trip(best50: nil), trip(best50: 6)).winner, .second)
        XCTAssertEqual(row(.sprint80, trip(), trip()).winner, .none)
    }

    func testDistanceAndDurationsAreNeutral() {
        XCTAssertEqual(row(.distance, trip(distance: 5000), trip(distance: 20_000)).winner, .none)
        XCTAssertEqual(row(.movingDuration, trip(moving: 100), trip(moving: 5000)).winner, .none)
        XCTAssertEqual(row(.totalDuration, trip(total: 100), trip(total: 5000)).winner, .none)
        XCTAssertEqual(row(.distance, trip(distance: 5000), trip(distance: 20_000)).second, 20_000)
    }

    func testValuesThatDisplayTheSameAreATie() {
        // Affichées « 92 km/h » toutes les deux : aucun gagnant.
        XCTAssertEqual(row(.maxSpeed, trip(max: 92.2), trip(max: 91.8)).winner, .tie)
        // Affichées « 4,2 s » toutes les deux.
        XCTAssertEqual(row(.sprint50, trip(best50: 4.21), trip(best50: 4.24)).winner, .tie)
        // « 2,8 » contre « 2,9 » : la différence se voit, il y a un gagnant.
        XCTAssertEqual(row(.peakAcceleration, trip(peak: 2.84), trip(peak: 2.86)).winner, .second)
        XCTAssertEqual(row(.maxLeanLeft, trip(left: 20.4), trip(left: 19.6)).winner, .tie)
    }

    func testNonFiniteValuesNeverWin() {
        XCTAssertEqual(row(.maxSpeed, trip(max: .nan), trip(max: 50)).winner, .second)
        XCTAssertEqual(row(.maxSpeed, trip(max: .infinity), trip(max: .nan)).winner, .none)
    }
}
