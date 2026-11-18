import XCTest
@testable import ScooterCore

final class SegmentTests: XCTestCase {
    private func north(_ meters: Double, east: Double = 0) -> Coordinate {
        Coordinate(latitude: 48 + meters / 111_195, longitude: 2 + east / 74_400)
    }

    /// Ligne droite de 2 km, un point tous les 10 m, à `speed` m/s.
    private func straight(speed: Double, from: Double = 0, to: Double = 2000) -> ([Coordinate], [TimeInterval]) {
        let route: [Coordinate] = stride(from: from, through: to, by: 10).map { north($0) }
        let times: [TimeInterval] = route.indices.map { Double($0) * 10 / speed }
        return (route, times)
    }

    func testCutKeepsTheChosenPortion() throws {
        let (route, _) = straight(speed: 10)
        let segment = try XCTUnwrap(Segment.cut(route: route, from: 0.25, to: 0.75))
        XCTAssertEqual(segment.length, 1000, accuracy: 2)
        XCTAssertEqual(segment.path.first!.latitude, north(500).latitude, accuracy: 1e-6)
        XCTAssertNil(Segment.cut(route: route, from: 0.5, to: 0.52))
    }

    func testPassIsTimedBetweenGates() throws {
        let (route, _) = straight(speed: 10)
        let segment = try XCTUnwrap(Segment.cut(route: route, from: 0.25, to: 0.75))
        let (ride, times) = straight(speed: 20)
        let passes = segment.passes(route: ride, times: times)
        XCTAssertEqual(passes.count, 1)
        XCTAssertEqual(passes[0].duration, 50, accuracy: 0.5)
    }

    func testOppositeDirectionAndDetourDoNotCount() throws {
        let (route, _) = straight(speed: 10)
        let segment = try XCTUnwrap(Segment.cut(route: route, from: 0.25, to: 0.75))
        let (ride, times) = straight(speed: 10)
        XCTAssertTrue(segment.passes(route: Array(ride.reversed()), times: times).isEmpty)
        // Détour de 300 m vers l'est au milieu du segment.
        var detour: [Coordinate] = ride
        for index in detour.indices where index >= 90 && index <= 110 {
            detour[index] = north(Double(index) * 10, east: 300)
        }
        XCTAssertTrue(segment.passes(route: detour, times: times).isEmpty)
    }

    func testTwoLapsGiveTwoPasses() throws {
        let (route, _) = straight(speed: 10)
        let segment = try XCTUnwrap(Segment.cut(route: route, from: 0.1, to: 0.4))
        let (lap, _) = straight(speed: 10, from: 0, to: 1000)
        let back: [Coordinate] = Array(lap.reversed().dropFirst())
        let again: [Coordinate] = Array(lap[1...])
        var ride: [Coordinate] = lap
        ride.append(contentsOf: back)
        ride.append(contentsOf: again)
        let times: [TimeInterval] = ride.indices.map { Double($0) }
        let passes = segment.passes(route: ride, times: times)
        // Aller, retour (sens inverse : ignoré), aller : deux passages de 60 s.
        XCTAssertEqual(passes.count, 2)
        XCTAssertEqual(passes[0].duration, 60, accuracy: 1)
        XCTAssertEqual(passes[1].duration, 60, accuracy: 1)
        XCTAssertEqual(segment.bestPass(route: ride, times: times)?.duration ?? 0, 60, accuracy: 1)
    }
}
