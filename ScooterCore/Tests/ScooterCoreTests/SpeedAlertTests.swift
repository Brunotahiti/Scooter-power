import XCTest
@testable import ScooterCore

final class SpeedAlertTests: XCTestCase {
    private func run(_ alert: inout SpeedAlert, _ speeds: [Double?], threshold: Double = 80, enabled: Bool = true) -> [Bool] {
        speeds.map { alert.update(speedKmh: $0, thresholdKmh: threshold, enabled: enabled) }
    }

    func testFiresOnceWhenCrossingUpward() {
        var a = SpeedAlert()
        XCTAssertEqual(run(&a, [70, 79, 80, 81, 90, 85]), [false, false, false, true, false, false])
        XCTAssertTrue(a.isOver)
    }

    func testRearmsOnlyBelowHysteresis() {
        var a = SpeedAlert()
        // 78 est sous le seuil mais dans la marge de 3 km/h : pas de nouvelle alerte en repassant 80.
        XCTAssertEqual(run(&a, [85, 78, 82]), [true, false, false])
        XCTAssertTrue(a.isOver)
        XCTAssertEqual(run(&a, [76, 81]), [false, true])
    }

    func testIsOverClearsBelowHysteresis() {
        var a = SpeedAlert()
        _ = run(&a, [85, 78])
        XCTAssertTrue(a.isOver)
        _ = run(&a, [76.9])
        XCTAssertFalse(a.isOver)
    }

    func testDisabledOrUnknownSpeedNeverFiresAndClears() {
        var a = SpeedAlert()
        XCTAssertEqual(run(&a, [120], enabled: false), [false])
        XCTAssertFalse(a.isOver)
        _ = run(&a, [120])
        XCTAssertTrue(a.isOver)
        XCTAssertEqual(run(&a, [nil]), [false])
        XCTAssertFalse(a.isOver)
        XCTAssertEqual(run(&a, [.nan, 120]), [false, true])
        _ = run(&a, [120], enabled: false)
        XCTAssertFalse(a.isOver)
    }

    func testRaisingTheThresholdClearsTheAlert() {
        var a = SpeedAlert()
        _ = run(&a, [85])
        XCTAssertEqual(run(&a, [85], threshold: 110), [false])
        XCTAssertFalse(a.isOver)
    }
}
