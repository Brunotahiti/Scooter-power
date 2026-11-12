import XCTest
@testable import ScooterCore

final class TripSessionTests: XCTestCase {
    private func loc(_ t: Double, lon: Double, speed: Double = 10) -> LocationSample {
        LocationSample(timestamp: t, latitude: 0, longitude: lon, speed: speed, altitude: 24, horizontalAccuracy: 5)
    }

    private func mot(_ t: Double, lean deg: Double = 0, forwardG: Double = 0, yaw: Double = 0) -> MotionSample {
        let r = deg * .pi / 180
        let gravity = Vector3(sin(r), -cos(r), 0)
        return MotionSample(timestamp: t, gravity: gravity,
                            userAcceleration: Vector3(0, 0, -forwardG),
                            rotationRate: gravity.scaled(yaw))
    }

    private func feed(_ s: inout TripSession, from t0: Double, seconds: Double, lean: Double = 0,
                      forwardG: Double = 0, yaw: Double = 0) {
        let n = Int((seconds * 50).rounded())
        for i in 0..<n {
            s.handle(mot(t0 + Double(i) * 0.02, lean: lean, forwardG: forwardG, yaw: yaw))
        }
    }

    func testLifecycle() {
        var s = TripSession()
        XCTAssertEqual(s.state, .idle)
        s.pause(at: 0)
        s.resume(at: 0)
        s.finish(at: 0)
        XCTAssertEqual(s.state, .idle)
        s.start(at: 0)
        XCTAssertEqual(s.state, .recording)
        s.start(at: 5)
        s.resume(at: 5)
        XCTAssertEqual(s.state, .recording)
        s.pause(at: 10)
        XCTAssertEqual(s.state, .paused)
        s.finish(at: 20)
        XCTAssertEqual(s.state, .finished)
        XCTAssertEqual(s.summary(at: 99).totalDuration, 10, accuracy: 1e-9)
        s.pause(at: 30)
        s.start(at: 30)
        XCTAssertEqual(s.state, .finished)
        s.reset()
        XCTAssertEqual(s.state, .idle)
        XCTAssertEqual(s.summary(at: 0).totalDuration, 0)
    }

    func testIgnoresSamplesWhenIdleOrFinished() {
        var s = TripSession()
        s.handle(loc(0, lon: 0))
        s.handle(mot(0))
        XCTAssertTrue(s.statistics.route.isEmpty)
        XCTAssertNil(s.lean.calibration)
        s.start(at: 0)
        s.handle(loc(1, lon: 0))
        s.finish(at: 2)
        s.handle(loc(3, lon: 0.001))
        XCTAssertEqual(s.statistics.route.count, 1)
    }

    func testFirstMotionSampleCalibratesThenFeedsBoth() {
        var s = TripSession()
        s.start(at: 0)
        s.handle(mot(0, lean: 5))
        feed(&s, from: 0.02, seconds: 3, lean: 13, forwardG: 0.2)
        XCTAssertEqual(s.lean.angleDegrees, 8, accuracy: 0.2)
        XCTAssertEqual(s.acceleration.current, 1.96, accuracy: 0.05)
        s.recalibrate()
        s.handle(mot(3.02, lean: 13))
        s.handle(mot(3.04, lean: 13))
        XCTAssertEqual(s.lean.angleDegrees, 0, accuracy: 0.05)
    }

    func testFailedCalibrationRetries() {
        var s = TripSession()
        s.start(at: 0)
        s.handle(MotionSample(timestamp: 0, gravity: Vector3(0, 0, 0), userAcceleration: Vector3(0, 0, 0)))
        XCTAssertNil(s.lean.calibration)
        XCTAssertEqual(s.acceleration.current, 0)
        s.handle(mot(0.02))
        XCTAssertNotNil(s.lean.calibration)
    }

    func testPauseKeepsSensorsButFreezesStatistics() {
        var s = TripSession()
        s.start(at: 0)
        s.handle(mot(0))
        s.handle(loc(0, lon: 0))
        s.handle(loc(10, lon: 0.001))
        s.pause(at: 10)
        s.handle(loc(20, lon: 0.002))
        feed(&s, from: 10, seconds: 2, lean: 10)
        XCTAssertEqual(s.statistics.distanceMeters, 111.19, accuracy: 0.05)
        XCTAssertEqual(s.lean.angleDegrees, 10, accuracy: 0.2)
    }

    func testPauseDoesNotRecordExtremes() {
        // À l'arrêt sur la béquille, l'inclinaison s'affiche mais ne compte pas dans le résumé.
        var s = TripSession()
        s.start(at: 0)
        s.handle(mot(0))
        s.pause(at: 1)
        feed(&s, from: 1, seconds: 3, lean: -15, forwardG: 0.3)
        XCTAssertEqual(s.lean.angleDegrees, -15, accuracy: 0.2)
        XCTAssertEqual(s.acceleration.current, 2.94, accuracy: 0.05)
        let r = s.summary(at: 4)
        XCTAssertEqual(r.maxLeanLeftDegrees, 0)
        XCTAssertEqual(r.peakAcceleration, 0)
    }

    func testSprintMeasuredWhileRecording() {
        var s = TripSession()
        s.start(at: 0)
        for i in 0...9 {
            s.handle(loc(Double(i), lon: 0, speed: 10.0 * Double(i) / 3.6))
        }
        let r = s.summary(at: 9)
        XCTAssertEqual(r.best50!, 4.9, accuracy: 1e-6)
        XCTAssertEqual(r.best80!, 7.9, accuracy: 1e-6)
        XCTAssertEqual(s.sprint.last50!, 4.9, accuracy: 1e-6)
    }

    func testPauseCancelsSprintAndInvalidFixesAreNotTimed() {
        var s = TripSession()
        s.start(at: 0)
        s.handle(loc(0, lon: 0, speed: 0))
        s.handle(loc(1, lon: 0, speed: 10 / 3.6))
        XCTAssertTrue(s.sprint.isRunning)
        s.pause(at: 2)
        XCTAssertFalse(s.sprint.isRunning)
        s.resume(at: 3)
        s.handle(loc(4, lon: 0, speed: 60 / 3.6))
        XCTAssertNil(s.summary(at: 4).best50)

        s.handle(loc(5, lon: 0, speed: 0))
        s.handle(LocationSample(timestamp: 6, latitude: 0, longitude: 0, speed: 10 / 3.6,
                                altitude: 0, horizontalAccuracy: 200))
        XCTAssertFalse(s.sprint.isRunning)
    }

    func testLeanUsesTurnPhysicsAtSpeedAndFallsBackWhenSpeedIsStale() {
        var s = TripSession()
        s.start(at: 0)
        s.handle(mot(0))
        s.handle(loc(0, lon: 0, speed: 15))
        feed(&s, from: 0.02, seconds: 3, yaw: 0.3)
        XCTAssertEqual(s.lean.angleDegrees, 24.65, accuracy: 0.1)
        // Plus de point GPS depuis 5 s : retour à la mesure par gravité, qui lit 0.
        feed(&s, from: 3.02, seconds: 6, yaw: 0.3)
        XCTAssertEqual(s.lean.angleDegrees, 0, accuracy: 0.1)
    }

    func testSummaryAndRestart() {
        var s = TripSession()
        s.start(at: 0)
        s.handle(mot(0))
        s.handle(loc(0, lon: 0))
        s.handle(loc(10, lon: 0.001, speed: 12))
        // Virage à gauche équilibré à 12 m/s : le lacet correspond aux 9° d'inclinaison.
        feed(&s, from: 0.02, seconds: 3, lean: -9, forwardG: 0.3, yaw: -0.12943)
        s.finish(at: 10)
        let r = s.summary(at: 50)
        XCTAssertEqual(r.distanceMeters, 111.19, accuracy: 0.05)
        XCTAssertEqual(r.maxSpeedKmh, 43.2, accuracy: 1e-9)
        XCTAssertEqual(r.maxLeanLeftDegrees, 9, accuracy: 0.2)
        XCTAssertEqual(r.maxLeanRightDegrees, 0)
        XCTAssertEqual(r.peakAcceleration, 2.94, accuracy: 0.05)
        XCTAssertEqual(r.totalDuration, 10, accuracy: 1e-9)
        s.reset()
        s.start(at: 100)
        XCTAssertEqual(s.summary(at: 100), TripSummary(
            distanceMeters: 0, maxSpeedKmh: 0, averageSpeedKmh: 0, peakAcceleration: 0,
            maxLeanLeftDegrees: 0, maxLeanRightDegrees: 0, movingDuration: 0, totalDuration: 0,
            best50: nil, best80: nil))
    }
}
