import XCTest
@testable import ScooterCore

final class MountCalibrationTests: XCTestCase {
    private func rad(_ d: Double) -> Double { d * .pi / 180 }

    func testUprightPhone() {
        let c = MountCalibration(gravity: Vector3(0, -1, 0))!
        XCTAssertEqual(c.forward, Vector3(0, 0, -1))
        XCTAssertEqual(c.leanAngleDegrees(gravity: Vector3(sin(rad(8)), -cos(rad(8)), 0)), 8, accuracy: 1e-6)
        XCTAssertEqual(c.leanAngleDegrees(gravity: Vector3(-sin(rad(20)), -cos(rad(20)), 0)), -20, accuracy: 1e-6)
        XCTAssertEqual(c.longitudinalAcceleration(userAccelerationG: Vector3(0, 0, -0.2)), 1.96133, accuracy: 1e-4)
        XCTAssertEqual(c.longitudinalAcceleration(userAccelerationG: Vector3(0, 0, 0.3)), -2.942, accuracy: 1e-3)
    }

    func testTiltedMountKeepsForwardHorizontal() {
        let c = MountCalibration(gravity: Vector3(0, -cos(rad(30)), -sin(rad(30))))!
        XCTAssertEqual(c.forward.dot(c.down), 0, accuracy: 1e-9)
        XCTAssertEqual(c.forward.length, 1, accuracy: 1e-9)
        XCTAssertLessThan(c.forward.z, 0)
        XCTAssertEqual(c.leanAngleDegrees(gravity: c.down), 0, accuracy: 1e-9)
    }

    func testFlatPhoneFallsBackToTopEdge() {
        let c = MountCalibration(gravity: Vector3(0, 0, -1))!
        XCTAssertEqual(c.forward, Vector3(0, 1, 0))
        XCTAssertEqual(c.leanAngleDegrees(gravity: Vector3(sin(rad(8)), 0, -cos(rad(8)))), 8, accuracy: 1e-6)
    }

    func testRejectsUnusableGravity() {
        XCTAssertNil(MountCalibration(gravity: Vector3(0, 0, 0)))
        XCTAssertNil(MountCalibration(gravity: Vector3(.nan, -1, 0)))
        let c = MountCalibration(gravity: Vector3(0, -1, 0))!
        XCTAssertEqual(c.leanAngleDegrees(gravity: Vector3(.nan, 0, 0)), 0)
        XCTAssertEqual(c.leanAngleDegrees(gravity: Vector3(0, 0, 0)), 0)
    }
}
