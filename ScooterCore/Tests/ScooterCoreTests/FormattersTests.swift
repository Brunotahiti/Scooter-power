import XCTest
@testable import ScooterCore

final class FormattersTests: XCTestCase {
    func testDuration() {
        XCTAssertEqual(Formatters.duration(1002), "00:16:42")
        XCTAssertEqual(Formatters.duration(1085.9), "00:18:05")
        XCTAssertEqual(Formatters.duration(65105), "18:05:05")
        XCTAssertEqual(Formatters.duration(-3), "00:00:00")
        XCTAssertEqual(Formatters.duration(.nan), "00:00:00")
    }

    func testDecimal() {
        XCTAssertEqual(Formatters.decimal(12.84, digits: 1), "12,8")
        XCTAssertEqual(Formatters.decimal(68.4, digits: 0), "68")
        XCTAssertEqual(Formatters.decimal(.infinity, digits: 1), "--")
    }

    func testSigned() {
        XCTAssertEqual(Formatters.signed(2.8, digits: 1), "+2,8")
        XCTAssertEqual(Formatters.signed(-1.3, digits: 1), "\u{2212}1,3")
        XCTAssertEqual(Formatters.signed(0, digits: 1), "0,0")
        XCTAssertEqual(Formatters.signed(-0.04, digits: 1), "0,0")
    }
}
