import XCTest
@testable import ScooterCore

final class CrashDetectorTests: XCTestCase {
    private let upright = Vector3(0, -1, 0)
    /// Téléphone couché sur le côté : gravité tournée de 90°.
    private let onItsSide = Vector3(1, 0, 0)
    private let still = Vector3(0, 0, 0)

    private func detector() -> CrashDetector {
        var d = CrashDetector()
        d.calibrate(gravity: upright)
        return d
    }

    /// Fait avancer le temps de `from` à `to` par pas de 0,1 s ; renvoie vrai si une alerte part.
    private func run(_ d: inout CrashDetector, from: Double, to: Double, gravity: Vector3,
                     acceleration: Vector3 = Vector3(0, 0, 0), speed: Double? = nil) -> Bool {
        var fired = false
        var t = from
        while t <= to + 1e-9 {
            if let speed { d.addSpeed(time: t, kmh: speed) }
            if d.addMotion(time: t, gravity: gravity, userAcceleration: acceleration) { fired = true }
            t += 0.1
        }
        return fired
    }

    func testScooterLaidDownAfterRidingTriggers() {
        var d = detector()
        XCTAssertFalse(run(&d, from: 0, to: 10, gravity: upright, speed: 50))
        // Chute : le téléphone se couche, la vitesse tombe.
        XCTAssertFalse(run(&d, from: 10.1, to: 11.5, gravity: onItsSide, speed: 0))
        XCTAssertTrue(run(&d, from: 11.6, to: 13.5, gravity: onItsSide, speed: 0))
    }

    func testImpactThenStopTriggers() {
        var d = detector()
        _ = run(&d, from: 0, to: 5, gravity: upright, speed: 40)
        XCTAssertFalse(d.addMotion(time: 5.1, gravity: upright, userAcceleration: Vector3(5, 0, 0)))
        XCTAssertTrue(run(&d, from: 5.2, to: 9, gravity: upright, speed: 0))
        XCTAssertEqual(d.lastTrigger?.reason, .impactThenStop)
        XCTAssertEqual(d.lastTrigger?.peakG ?? 0, 5, accuracy: 0.01)
        XCTAssertEqual(d.lastTrigger?.speedBeforeKmh ?? 0, 40, accuracy: 0.01)
    }

    func testLaidDownTriggerDescribesTilt() {
        var d = detector()
        _ = run(&d, from: 0, to: 10, gravity: upright, speed: 50)
        _ = run(&d, from: 10.1, to: 13.5, gravity: onItsSide, speed: 0)
        XCTAssertEqual(d.lastTrigger?.reason, .laidDown)
        XCTAssertEqual(d.lastTrigger?.tiltDegrees ?? 0, 90, accuracy: 0.5)
        XCTAssertEqual(d.lastTrigger?.speedBeforeKmh ?? 0, 50, accuracy: 0.01)
    }

    func testPotholeWithoutStopDoesNothing() {
        var d = detector()
        _ = run(&d, from: 0, to: 5, gravity: upright, speed: 40)
        _ = d.addMotion(time: 5.1, gravity: upright, userAcceleration: Vector3(6, 0, 0))
        XCTAssertFalse(run(&d, from: 5.2, to: 20, gravity: upright, speed: 38))
    }

    func testParkedScooterOnKickstandDoesNothing() {
        var d = detector()
        // Arrêté depuis longtemps, puis penché sur la béquille.
        XCTAssertFalse(run(&d, from: 0, to: 5, gravity: upright, speed: 50))
        XCTAssertFalse(run(&d, from: 5.1, to: 30, gravity: upright, speed: 0))
        XCTAssertFalse(run(&d, from: 30.1, to: 60, gravity: onItsSide, speed: 0))
    }

    func testBriefTiltDuringRideDoesNothing() {
        var d = detector()
        _ = run(&d, from: 0, to: 5, gravity: upright, speed: 50)
        XCTAssertFalse(run(&d, from: 5.1, to: 6.0, gravity: onItsSide, speed: 50))
        XCTAssertFalse(run(&d, from: 6.1, to: 15, gravity: upright, speed: 50))
    }

    func testCooldownPreventsRepeatedAlerts() {
        var d = detector()
        _ = run(&d, from: 0, to: 5, gravity: upright, speed: 50)
        XCTAssertTrue(run(&d, from: 5.1, to: 9, gravity: onItsSide, speed: 0))
        XCTAssertFalse(run(&d, from: 9.1, to: 30, gravity: onItsSide, speed: 0))
    }

    func testAngle() {
        XCTAssertEqual(CrashDetector.angleDegrees(upright, onItsSide), 90, accuracy: 1e-9)
        XCTAssertEqual(CrashDetector.angleDegrees(upright, upright), 0, accuracy: 1e-6)
    }
}
