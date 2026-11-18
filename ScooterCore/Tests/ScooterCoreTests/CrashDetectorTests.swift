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

    /// Téléphone à 50° : scooter penché au sol, pas couché à plat.
    private let tilted50 = Vector3(sin(50 * Double.pi / 180), -cos(50 * Double.pi / 180), 0)

    /// Choc franc pendant 0,3 s (pas une pointe isolée).
    private func crash(_ d: inout CrashDetector, at t: Double, speed: Double) {
        var time = t
        while time < t + 0.3 {
            _ = d.addMotion(time: time, gravity: upright, userAcceleration: Vector3(5, 0, 0))
            time += 0.02
        }
    }

    func testScooterLaidDownAfterRidingTriggers() {
        var d = detector()
        XCTAssertFalse(run(&d, from: 0, to: 10, gravity: upright, speed: 50))
        // Chute : le téléphone se couche, la vitesse tombe.
        XCTAssertFalse(run(&d, from: 10.1, to: 13.5, gravity: onItsSide, speed: 0))
        XCTAssertTrue(run(&d, from: 13.6, to: 15, gravity: onItsSide, speed: 0))
        XCTAssertEqual(d.lastTrigger?.reason, .laidDown)
        XCTAssertEqual(d.lastTrigger?.tiltDegrees ?? 0, 90, accuracy: 0.5)
        XCTAssertEqual(d.lastTrigger?.speedBeforeKmh ?? 0, 50, accuracy: 0.01)
    }

    func testImpactStopAndTiltTriggers() {
        var d = detector()
        _ = run(&d, from: 0, to: 5, gravity: upright, speed: 40)
        crash(&d, at: 5.02, speed: 40)
        XCTAssertFalse(run(&d, from: 5.4, to: 6.5, gravity: tilted50, speed: 0))
        XCTAssertTrue(run(&d, from: 6.6, to: 8, gravity: tilted50, speed: 0))
        XCTAssertEqual(d.lastTrigger?.reason, .impactThenStop)
        XCTAssertGreaterThanOrEqual(d.lastTrigger?.peakG ?? 0, 5)
    }

    func testHardBrakingToARedLightDoesNothing() {
        var d = detector()
        _ = run(&d, from: 0, to: 5, gravity: upright, speed: 50)
        // Grosse secousse puis arrêt au feu : le scooter reste droit.
        crash(&d, at: 5.02, speed: 50)
        XCTAssertFalse(run(&d, from: 5.4, to: 40, gravity: upright, speed: 0))
    }

    func testVibrationSpikesDoNotCountAsImpact() {
        var d = detector()
        _ = run(&d, from: 0, to: 5, gravity: upright, speed: 40)
        // Pointes isolées à 6 g entre des mesures calmes (vibrations du guidon).
        var t = 5.0
        while t < 7 {
            let spike: Bool = Int((t * 50).rounded()) % 5 == 0
            _ = d.addMotion(time: t, gravity: upright, userAcceleration: Vector3(spike ? 6 : 0.2, 0, 0))
            t += 0.02
        }
        // Arrêt, téléphone un peu penché sur son support : rien.
        XCTAssertFalse(run(&d, from: 7, to: 30, gravity: tilted50, speed: 0))
    }

    func testPotholeWithoutStopDoesNothing() {
        var d = detector()
        _ = run(&d, from: 0, to: 5, gravity: upright, speed: 40)
        crash(&d, at: 5.02, speed: 40)
        XCTAssertFalse(run(&d, from: 5.4, to: 20, gravity: upright, speed: 38))
    }

    func testPhonePickedUpAtRedLightDoesNothing() {
        var d = detector()
        _ = run(&d, from: 0, to: 5, gravity: upright, speed: 50)
        XCTAssertFalse(run(&d, from: 5.1, to: 12, gravity: upright, speed: 0))
        // Arrêté depuis 7 s, le pilote prend le téléphone en main.
        XCTAssertFalse(run(&d, from: 12.1, to: 30, gravity: onItsSide, speed: 0))
    }

    func testParkedScooterOnKickstandDoesNothing() {
        var d = detector()
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

    func testReferenceFollowsPhoneWhenTripStartedInHand() {
        // Calibré téléphone à plat dans la main, puis posé à la verticale sur le guidon.
        var d = CrashDetector()
        d.calibrate(gravity: Vector3(0, 0, -1))
        _ = run(&d, from: 0, to: 30, gravity: upright, speed: 40)
        XCTAssertLessThan(CrashDetector.angleDegrees(d.reference!, upright), 5)
        // Arrêt normal : aucune alerte.
        XCTAssertFalse(run(&d, from: 30.1, to: 60, gravity: upright, speed: 0))
    }

    func testCooldownPreventsRepeatedAlerts() {
        var d = detector()
        _ = run(&d, from: 0, to: 5, gravity: upright, speed: 50)
        XCTAssertTrue(run(&d, from: 5.1, to: 10, gravity: onItsSide, speed: 0))
        XCTAssertFalse(run(&d, from: 10.1, to: 30, gravity: onItsSide, speed: 0))
    }

    func testAngle() {
        XCTAssertEqual(CrashDetector.angleDegrees(upright, onItsSide), 90, accuracy: 1e-9)
        XCTAssertEqual(CrashDetector.angleDegrees(upright, upright), 0, accuracy: 1e-6)
    }
}
