import XCTest
@testable import ScooterCore

final class DemoTripTests: XCTestCase {
    func testSamplesStayPlausible() {
        let d = DemoTrip()
        for i in 0..<6000 {
            let t = Double(i) * 0.1
            let l = d.location(at: t)
            let m = d.motion(at: t)
            XCTAssertEqual(l.timestamp, t)
            XCTAssertEqual(m.timestamp, t)
            XCTAssertTrue((0...30).contains(l.speed))
            XCTAssertEqual(l.horizontalAccuracy, 5)
            XCTAssertEqual(m.gravity.length, 1, accuracy: 1e-9)
            XCTAssertLessThan(abs(m.userAcceleration.z) * 9.80665, 4)
        }
    }

    func testDrivesASessionEndToEnd() {
        let d = DemoTrip()
        var s = TripSession()
        s.start(at: 0)
        for i in 0..<3000 {
            let t = Double(i) * 0.02
            s.handle(d.motion(at: t))
            if i % 50 == 0 { s.handle(d.location(at: t)) }
        }
        let r = s.summary(at: 60)
        XCTAssertGreaterThan(r.distanceMeters, 300)
        XCTAssertLessThan(r.distanceMeters, 1800)
        XCTAssertGreaterThan(r.maxSpeedKmh, 30)
        XCTAssertLessThanOrEqual(r.maxSpeedKmh, 108)
        XCTAssertGreaterThan(r.maxLeanRightDegrees, 5)
        XCTAssertGreaterThan(r.peakAcceleration, 0.5)
        XCTAssertFalse(s.statistics.route.isEmpty)
    }
}
