import XCTest
@testable import ScooterCore

final class AutoTripDetectorTests: XCTestCase {
    private func feedIdle(_ d: inout AutoTripDetector, from: Int, to: Int, kmh: Double) -> Int? {
        for t in from...to where d.idleSample(time: Double(t), kmh: kmh) { return t }
        return nil
    }

    func testStartsAfterSustainedSpeed() {
        var d = AutoTripDetector()
        XCTAssertNil(feedIdle(&d, from: 0, to: 30, kmh: 8))     // marche ou vélo lent
        XCTAssertEqual(feedIdle(&d, from: 31, to: 60, kmh: 30), 46)
    }

    func testShortBurstOrGPSGapDoesNotStart() {
        var d = AutoTripDetector()
        XCTAssertNil(feedIdle(&d, from: 0, to: 10, kmh: 40))
        XCTAssertNil(feedIdle(&d, from: 11, to: 12, kmh: 2))     // arrêt : on recommence
        XCTAssertNil(feedIdle(&d, from: 13, to: 20, kmh: 40))
        // Trou de mesures de 30 s : le compte repart à zéro.
        XCTAssertNil(feedIdle(&d, from: 50, to: 60, kmh: 40))
    }

    func testStopsAfterThreeMinutesStill() {
        var d = AutoTripDetector()
        for t in 0..<100 { XCTAssertFalse(d.ridingSample(time: Double(t), kmh: 40)) }
        // Feu rouge de 60 s : rien.
        for t in 100..<160 { XCTAssertFalse(d.ridingSample(time: Double(t), kmh: 0)) }
        for t in 160..<200 { XCTAssertFalse(d.ridingSample(time: Double(t), kmh: 35)) }
        var stopped: Int?
        for t in 200...400 where d.ridingSample(time: Double(t), kmh: 1) {
            stopped = t
            break
        }
        XCTAssertEqual(stopped, 380)
    }
}
