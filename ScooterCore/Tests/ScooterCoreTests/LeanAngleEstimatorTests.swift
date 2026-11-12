import XCTest
@testable import ScooterCore

final class LeanAngleEstimatorTests: XCTestCase {
    private func g(_ deg: Double) -> Vector3 {
        let r = deg * .pi / 180
        return Vector3(sin(r), -cos(r), 0)
    }

    private func feed(_ e: inout LeanAngleEstimator, deg: Double, from t0: Double, seconds: Double) {
        let n = Int((seconds * 50).rounded())
        for i in 0..<n {
            e.update(gravity: g(deg), timestamp: t0 + Double(i) * 0.02)
        }
    }

    func testConvergesAndReportsSide() {
        var e = LeanAngleEstimator()
        XCTAssertTrue(e.calibrate(gravity: g(0)))
        feed(&e, deg: 8, from: 0, seconds: 2)
        XCTAssertEqual(e.angleDegrees, 8, accuracy: 0.1)
        XCTAssertEqual(e.side, .right)
        feed(&e, deg: -15, from: 2, seconds: 2)
        XCTAssertEqual(e.angleDegrees, -15, accuracy: 0.1)
        XCTAssertEqual(e.side, .left)
        XCTAssertEqual(e.maxRightDegrees, 8, accuracy: 0.1)
        XCTAssertEqual(e.maxLeftDegrees, 15, accuracy: 0.1)
    }

    func testUprightBelowOneDegree() {
        var e = LeanAngleEstimator()
        e.calibrate(gravity: g(0))
        feed(&e, deg: 0.5, from: 0, seconds: 1)
        XCTAssertEqual(e.side, .upright)
    }

    func testClampedTo60() {
        var e = LeanAngleEstimator()
        e.calibrate(gravity: g(0))
        feed(&e, deg: 80, from: 0, seconds: 2)
        XCTAssertEqual(e.angleDegrees, 60, accuracy: 1e-9)
        XCTAssertEqual(e.maxRightDegrees, 60, accuracy: 1e-9)
    }

    func testCalibrationOffsetAndRecalibration() {
        var e = LeanAngleEstimator()
        e.calibrate(gravity: g(5))
        feed(&e, deg: 5, from: 0, seconds: 1)
        XCTAssertEqual(e.angleDegrees, 0, accuracy: 0.05)
        feed(&e, deg: 25, from: 1, seconds: 2)
        XCTAssertEqual(e.maxRightDegrees, 20, accuracy: 0.1)
        e.calibrate(gravity: g(25))
        XCTAssertEqual(e.maxRightDegrees, 0)
    }

    func testUncalibratedOrBadInputStaysZero() {
        var e = LeanAngleEstimator()
        feed(&e, deg: 30, from: 0, seconds: 1)
        XCTAssertEqual(e.angleDegrees, 0)
        XCTAssertFalse(e.calibrate(gravity: Vector3(0, 0, 0)))
        XCTAssertNil(e.calibration)
        e.calibrate(gravity: g(0))
        e.update(gravity: Vector3(.nan, 0, 0), timestamp: 5)
        XCTAssertTrue(e.angleDegrees.isFinite)
    }

    func testGapSnapsToNewValue() {
        var e = LeanAngleEstimator()
        e.calibrate(gravity: g(0))
        feed(&e, deg: 0, from: 0, seconds: 1)
        e.update(gravity: g(12), timestamp: 30)
        XCTAssertEqual(e.angleDegrees, 12, accuracy: 1e-6)
    }
}
