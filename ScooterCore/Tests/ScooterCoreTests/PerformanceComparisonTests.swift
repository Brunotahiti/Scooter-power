import XCTest
@testable import ScooterCore

final class PerformanceComparisonTests: XCTestCase {
    private func stats(top: Double, peak: Double, lean: Double, times: [SpeedInterval: TimeInterval]) -> PerformanceStats {
        PerformanceStats(trips: [
            TripSummary(distanceMeters: 10_000, maxSpeedKmh: top, averageSpeedKmh: 40, peakAcceleration: peak,
                        maxLeanLeftDegrees: lean, maxLeanRightDegrees: 0, movingDuration: 900,
                        totalDuration: 1000, bestTimes: times),
        ])
    }

    private func delta(_ metric: StatMetric, _ a: PerformanceStats, _ b: PerformanceStats) -> StatDelta {
        PerformanceComparison.deltas(baseline: a, modified: b).first { $0.metric == metric }!
    }

    func testHigherIsBetterMetric() {
        let before = stats(top: 100, peak: 3, lean: 20, times: [:])
        let after = stats(top: 110, peak: 2.85, lean: 20, times: [:])
        let speed = delta(.topSpeed, before, after)
        XCTAssertEqual(speed.percent!, 10, accuracy: 1e-9)
        XCTAssertEqual(speed.verdict, .better)
        XCTAssertEqual(speed.baseline, 100)
        XCTAssertEqual(speed.modified, 110)
        let peak = delta(.bestPeakAcceleration, before, after)
        XCTAssertEqual(peak.percent!, -5, accuracy: 1e-9)
        XCTAssertEqual(peak.verdict, .worse)
    }

    func testLowerIsBetterForTimes() {
        let before = stats(top: 100, peak: 3, lean: 20, times: [.zeroTo50: 5.0, .fiftyTo90: 8.0])
        let after = stats(top: 100, peak: 3, lean: 20, times: [.zeroTo50: 4.5, .fiftyTo90: 8.8])
        let sprint = delta(.intervalBest(.zeroTo50), before, after)
        // Le temps baisse de 10 % : c'est mieux.
        XCTAssertEqual(sprint.percent!, -10, accuracy: 1e-9)
        XCTAssertEqual(sprint.verdict, .better)
        let roll = delta(.intervalBest(.fiftyTo90), before, after)
        XCTAssertEqual(roll.percent!, 10, accuracy: 1e-9)
        XCTAssertEqual(roll.verdict, .worse)
        XCTAssertEqual(delta(.intervalAverage(.zeroTo50), before, after).verdict, .better)
    }

    func testTinyChangeIsSame() {
        let before = stats(top: 100, peak: 3, lean: 20, times: [:])
        let after = stats(top: 100.3, peak: 3, lean: 20, times: [:])
        let speed = delta(.topSpeed, before, after)
        XCTAssertEqual(speed.verdict, .same)
        XCTAssertEqual(speed.percent!, 0.3, accuracy: 1e-9)
    }

    func testMissingDataHasNoVerdict() {
        let before = stats(top: 100, peak: 3, lean: 20, times: [.zeroTo50: 5])
        let after = stats(top: 100, peak: 3, lean: 20, times: [:])
        let sprint = delta(.intervalBest(.zeroTo50), before, after)
        XCTAssertNil(sprint.percent)
        XCTAssertEqual(sprint.verdict, .unknown)
        XCTAssertEqual(sprint.baseline, 5)
        XCTAssertNil(sprint.modified)
        // Aucune des deux configurations n'a de 0–100 : la ligne existe, sans verdict.
        XCTAssertEqual(delta(.intervalBest(.zeroTo100), before, after).verdict, .unknown)
        let empty = PerformanceStats(trips: [])
        XCTAssertEqual(delta(.topSpeed, empty, after).verdict, .unknown)
    }

    func testRowsCoverEveryMetricInOrder() {
        let s = stats(top: 100, peak: 3, lean: 20, times: [:])
        let metrics = PerformanceComparison.deltas(baseline: s, modified: s).map(\.metric)
        var expected: [StatMetric] = [.topSpeed, .averageTopSpeed, .overallAverageSpeed,
                                      .bestPeakAcceleration, .averagePeakAcceleration]
        for interval in SpeedInterval.all {
            expected.append(.intervalBest(interval))
            expected.append(.intervalAverage(interval))
        }
        expected.append(.maxLean)
        XCTAssertEqual(metrics, expected)
    }
}
