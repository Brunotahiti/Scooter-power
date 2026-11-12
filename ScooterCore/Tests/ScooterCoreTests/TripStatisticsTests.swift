import XCTest
@testable import ScooterCore

final class TripStatisticsTests: XCTestCase {
    private func s(_ t: Double, lon: Double, speed: Double = 10, acc: Double = 5, alt: Double = 24) -> LocationSample {
        LocationSample(timestamp: t, latitude: 0, longitude: lon, speed: speed, altitude: alt, horizontalAccuracy: acc)
    }

    private func started() -> TripStatistics {
        var t = TripStatistics()
        t.start(at: 0)
        return t
    }

    func testDistanceMaxAverage() {
        var t = started()
        t.add(s(0, lon: 0))
        t.add(s(10, lon: 0.001))
        t.add(s(20, lon: 0.002, speed: 12))
        XCTAssertEqual(t.distanceMeters, 222.39, accuracy: 0.05)
        XCTAssertEqual(t.movingDuration, 20, accuracy: 1e-9)
        XCTAssertEqual(t.maxSpeedKmh, 43.2, accuracy: 1e-9)
        XCTAssertEqual(t.averageSpeedKmh, 40.03, accuracy: 0.01)
        XCTAssertEqual(t.altitudeMeters, 24)
        XCTAssertEqual(t.route.count, 3)
        XCTAssertEqual(t.currentSpeedKmh(at: 21)!, 43.2, accuracy: 1e-9)
    }

    func testAverageIsZeroWithoutMovement() {
        XCTAssertEqual(started().averageSpeedKmh, 0)
    }

    func testSlowIntervalIsNotMoving() {
        var t = started()
        t.add(s(0, lon: 0))
        t.add(s(10, lon: 0.00001, speed: 0.5))
        XCTAssertEqual(t.movingDuration, 0)
        XCTAssertGreaterThan(t.distanceMeters, 0)
    }

    func testInvalidSamplesIgnored() {
        var t = started()
        t.add(s(0, lon: 0, acc: 80))
        t.add(s(1, lon: 0, acc: -1))
        t.add(s(2, lon: 0, speed: -1))
        t.add(s(3, lon: .nan))
        XCTAssertTrue(t.route.isEmpty)
        XCTAssertNil(t.currentSpeedKmh(at: 3))
    }

    func testDuplicateAndOutOfOrderIgnored() {
        var t = started()
        t.add(s(10, lon: 0.001))
        t.add(s(10, lon: 0.002))
        t.add(s(5, lon: 0.003))
        XCTAssertEqual(t.route.count, 1)
        XCTAssertEqual(t.distanceMeters, 0)
    }

    func testJumpRejected() {
        var t = started()
        t.add(s(0, lon: 0))
        t.add(s(1, lon: 0.01))
        t.add(s(2, lon: 0.0002))
        XCTAssertEqual(t.route.count, 2)
        XCTAssertEqual(t.distanceMeters, 22.24, accuracy: 0.05)
    }

    func testPauseExcludesTimeAndGap() {
        var t = started()
        t.add(s(0, lon: 0))
        t.add(s(10, lon: 0.001))
        t.pause(at: 10)
        t.pause(at: 12)
        t.add(s(15, lon: 0.002))
        t.resume(at: 30)
        t.resume(at: 31)
        t.add(s(30, lon: 0.003))
        t.add(s(40, lon: 0.004))
        XCTAssertEqual(t.distanceMeters, 222.39, accuracy: 0.05)
        XCTAssertEqual(t.movingDuration, 20, accuracy: 1e-9)
        XCTAssertEqual(t.totalDuration(at: 40), 20, accuracy: 1e-9)
    }

    func testTotalDurationFrozenWhilePaused() {
        var t = started()
        t.pause(at: 10)
        XCTAssertEqual(t.totalDuration(at: 15), 10, accuracy: 1e-9)
    }

    func testStaleSpeedIsNil() {
        var t = started()
        t.add(s(0, lon: 0))
        XCTAssertNotNil(t.currentSpeedKmh(at: 5))
        XCTAssertNil(t.currentSpeedKmh(at: 5.1))
    }

    func testNothingBeforeStartOrAfterStop() {
        var t = TripStatistics()
        t.add(s(0, lon: 0))
        t.pause(at: 1)
        t.resume(at: 2)
        XCTAssertTrue(t.route.isEmpty)
        XCTAssertEqual(t.totalDuration(at: 50), 0)
        t.start(at: 0)
        t.add(s(1, lon: 0))
        t.stop(at: 10)
        t.add(s(11, lon: 0.001))
        XCTAssertEqual(t.route.count, 1)
        XCTAssertEqual(t.totalDuration(at: 99), 10, accuracy: 1e-9)
    }
}
