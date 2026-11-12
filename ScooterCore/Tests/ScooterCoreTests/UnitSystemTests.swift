import XCTest
@testable import ScooterCore

final class UnitSystemTests: XCTestCase {
    override func tearDown() {
        Formatters.decimalSeparator = ","
        super.tearDown()
    }

    func testMetricIsIdentity() {
        let u = UnitSystem.metric
        XCTAssertEqual(u.speed(fromKmh: 68), 68)
        XCTAssertEqual(u.kmh(fromSpeed: 68), 68)
        XCTAssertEqual(u.distance(fromMeters: 12_800), 12.8, accuracy: 1e-9)
        XCTAssertEqual(u.altitude(fromMeters: 24), 24)
        XCTAssertEqual([u.speedUnit, u.distanceUnit, u.altitudeUnit], ["km/h", "km", "m"])
        XCTAssertEqual(u.speedometerMax, 140)
        XCTAssertEqual(u.speedometerLabelStep, 20)
    }

    func testImperialConversions() {
        let u = UnitSystem.imperial
        XCTAssertEqual(u.speed(fromKmh: 100), 62.137, accuracy: 0.001)
        XCTAssertEqual(u.kmh(fromSpeed: 62.137), 100, accuracy: 0.001)
        XCTAssertEqual(u.distance(fromMeters: 1609.344), 1, accuracy: 1e-9)
        XCTAssertEqual(u.altitude(fromMeters: 100), 328.084, accuracy: 0.001)
        XCTAssertEqual([u.speedUnit, u.distanceUnit, u.altitudeUnit], ["mph", "mi", "ft"])
        XCTAssertEqual(u.speedometerMax, 90)
        XCTAssertEqual(u.speedometerLabelStep, 10)
    }

    func testRoundTripAndRawValues() {
        for u in UnitSystem.allCases {
            XCTAssertEqual(u.kmh(fromSpeed: u.speed(fromKmh: 87.3)), 87.3, accuracy: 1e-9)
            XCTAssertEqual(UnitSystem(rawValue: u.rawValue), u)
        }
    }

    func testDecimalSeparatorFollowsTheSetting() {
        XCTAssertEqual(Formatters.decimal(12.84, digits: 1), "12,8")
        Formatters.decimalSeparator = "."
        XCTAssertEqual(Formatters.decimal(12.84, digits: 1), "12.8")
        XCTAssertEqual(Formatters.signed(-1.3, digits: 1), "\u{2212}1.3")
        XCTAssertEqual(Formatters.signed(-0.04, digits: 1), "0.0")
        XCTAssertEqual(Formatters.decimal(68.4, digits: 0), "68")
    }
}
