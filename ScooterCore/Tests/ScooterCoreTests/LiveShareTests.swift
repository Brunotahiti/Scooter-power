import XCTest
@testable import ScooterCore

final class LiveShareTests: XCTestCase {
    func testTrailIsThinnedAndRoundTrips() {
        let route: [Coordinate] = (0...1000).map { Coordinate(latitude: -17.5 + Double($0) * 0.00001, longitude: -149.5) }
        let text = LiveShare.encodeTrail(route, spacing: 15, maxPoints: 400)
        let back = LiveShare.decodeTrail(text)
        XCTAssertLessThan(back.count, 120)
        XCTAssertEqual(back.last!.latitude, route.last!.latitude, accuracy: 1e-5)
        XCTAssertEqual(back.first!.latitude, -17.5, accuracy: 1e-5)
        XCTAssertLessThanOrEqual(LiveShare.decodeTrail(LiveShare.encodeTrail(route, spacing: 0, maxPoints: 50)).count, 50)
        XCTAssertTrue(LiveShare.decodeTrail("").isEmpty)
    }

    func testIDAndLink() {
        let id = LiveShare.newID()
        XCTAssertEqual(id.count, 32)
        XCTAssertNotEqual(id, LiveShare.newID())
        XCTAssertEqual(LiveShare.link(id: id)?.absoluteString, "https://brunotahiti.github.io/Scooter-power/live/?id=" + id)
    }
}
