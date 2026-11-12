import XCTest
@testable import ScooterCore

final class RouteSimplifierTests: XCTestCase {
    private func route(_ n: Int) -> [Coordinate] {
        (0..<n).map { Coordinate(latitude: Double($0), longitude: -Double($0)) }
    }

    func testShortRoutesAreUntouched() {
        XCTAssertEqual(RouteSimplifier.downsample([], maxPoints: 2000), [])
        XCTAssertEqual(RouteSimplifier.downsample(route(1), maxPoints: 2000), route(1))
        XCTAssertEqual(RouteSimplifier.downsample(route(2000), maxPoints: 2000), route(2000))
    }

    func testLongRouteKeepsEndsOrderAndLimit() {
        let long = route(10_000)
        let out = RouteSimplifier.downsample(long, maxPoints: 2000)
        XCTAssertLessThanOrEqual(out.count, 2000)
        XCTAssertGreaterThan(out.count, 1900)
        XCTAssertEqual(out.first, long.first)
        XCTAssertEqual(out.last, long.last)
        XCTAssertEqual(out.map(\.latitude), out.map(\.latitude).sorted())
        XCTAssertEqual(Set(out.map(\.latitude)).count, out.count)
    }

    func testJustOverTheLimitAndTinyLimits() {
        XCTAssertEqual(RouteSimplifier.downsample(route(2001), maxPoints: 2000).count, 2000)
        XCTAssertEqual(RouteSimplifier.downsample(route(10), maxPoints: 2), [route(10)[0], route(10)[9]])
        XCTAssertEqual(RouteSimplifier.downsample(route(10), maxPoints: 0), [route(10)[0], route(10)[9]])
    }

    func testCoordinatesSurviveJSON() throws {
        let original = route(3)
        let data = try JSONEncoder().encode(original)
        XCTAssertEqual(try JSONDecoder().decode([Coordinate].self, from: data), original)
    }
}
