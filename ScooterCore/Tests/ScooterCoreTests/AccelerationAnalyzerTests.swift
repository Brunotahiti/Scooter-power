import XCTest
@testable import ScooterCore

final class AccelerationAnalyzerTests: XCTestCase {
    private func feed(_ a: inout AccelerationAnalyzer, _ value: Double, from t0: Double, seconds: Double) {
        let n = Int((seconds * 50).rounded())
        for i in 0..<n {
            a.addSensor(timestamp: t0 + Double(i) * 0.02, longitudinal: value)
        }
    }

    func testLevels() {
        XCTAssertEqual(AccelerationAnalyzer.level(for: 2.8), .acceleratingHard)
        XCTAssertEqual(AccelerationAnalyzer.level(for: 2.5), .acceleratingHard)
        XCTAssertEqual(AccelerationAnalyzer.level(for: 1.0), .accelerating)
        XCTAssertEqual(AccelerationAnalyzer.level(for: 0.79), .stable)
        XCTAssertEqual(AccelerationAnalyzer.level(for: -0.79), .stable)
        XCTAssertEqual(AccelerationAnalyzer.level(for: -0.8), .braking)
        XCTAssertEqual(AccelerationAnalyzer.level(for: -2.5), .brakingHard)
    }

    func testConvergesWithoutGPS() {
        var a = AccelerationAnalyzer()
        feed(&a, 0, from: 0, seconds: 1)
        feed(&a, 2.8, from: 1, seconds: 3)
        XCTAssertEqual(a.current, 2.8, accuracy: 0.02)
        XCTAssertEqual(a.level, .acceleratingHard)
        XCTAssertEqual(a.gaugePosition, 0.7, accuracy: 0.01)
    }

    func testHistoryIsThirtySecondWindow() {
        var a = AccelerationAnalyzer()
        feed(&a, 1, from: 0, seconds: 10)
        XCTAssertEqual(a.history.count, 40)
        feed(&a, 1, from: 10, seconds: 40)
        XCTAssertEqual(a.history.count, 120)
    }

    func testPeakLeavesWindowButTripPeakStays() {
        var a = AccelerationAnalyzer()
        feed(&a, 3.6, from: 0, seconds: 3)
        feed(&a, 1, from: 3, seconds: 5)
        XCTAssertEqual(a.peak, 3.6, accuracy: 0.05)
        feed(&a, 1, from: 8, seconds: 35)
        XCTAssertEqual(a.peak, 1, accuracy: 0.05)
        XCTAssertEqual(a.tripPeak, 3.6, accuracy: 0.05)
    }

    func testPeakIsNeverNegative() {
        var a = AccelerationAnalyzer()
        XCTAssertEqual(a.peak, 0)
        feed(&a, -3, from: 0, seconds: 3)
        XCTAssertEqual(a.peak, 0)
        XCTAssertEqual(a.tripPeak, 0)
    }

    func testGaugeClamped() {
        var a = AccelerationAnalyzer()
        feed(&a, 10, from: 0, seconds: 3)
        XCTAssertEqual(a.gaugePosition, 1)
        feed(&a, -10, from: 3, seconds: 3)
        XCTAssertEqual(a.gaugePosition, -1)
    }

    func testGPSRemovesSensorBias() {
        var a = AccelerationAnalyzer()
        for s in 0..<30 {
            a.addGPSSpeed(timestamp: 1000 + Double(s), speed: 10)
            feed(&a, 1.0, from: Double(s), seconds: 1)
        }
        XCTAssertEqual(a.current, 0, accuracy: 0.1)
    }

    func testGPSKeepsRealAcceleration() {
        var a = AccelerationAnalyzer()
        for s in 0..<30 {
            a.addGPSSpeed(timestamp: Double(s), speed: 2.0 * Double(s))
            feed(&a, 2.0, from: Double(s), seconds: 1)
        }
        XCTAssertEqual(a.current, 2, accuracy: 0.1)
    }

    func testGapSnapsAndKeepsHistoryBounded() {
        var a = AccelerationAnalyzer()
        feed(&a, 0, from: 0, seconds: 2)
        let before = a.history.count
        a.addSensor(timestamp: 500, longitudinal: 3)
        XCTAssertEqual(a.current, 3, accuracy: 1e-9)
        XCTAssertEqual(a.history.count, before + 1)
    }

    func testBadInputIgnored() {
        var a = AccelerationAnalyzer()
        feed(&a, 1, from: 0, seconds: 2)
        a.addSensor(timestamp: 2, longitudinal: .nan)
        a.addGPSSpeed(timestamp: 0, speed: -1)
        a.addGPSSpeed(timestamp: 1, speed: .infinity)
        a.addGPSSpeed(timestamp: 5, speed: 3)
        a.addGPSSpeed(timestamp: 5, speed: 9)
        feed(&a, 1, from: 2.02, seconds: 1)
        XCTAssertEqual(a.current, 1, accuracy: 0.02)
    }
}
