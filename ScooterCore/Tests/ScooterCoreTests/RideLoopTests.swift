import XCTest
@testable import ScooterCore

final class RideLoopTests: XCTestCase {
    let start = Coordinate(latitude: -17.53, longitude: -149.56)

    func testWaypointsFormALoopOfTheRightSize() {
        let points = RideLoop.waypoints(start: start, meters: 30_000, bearing: 45)
        XCTAssertEqual(points.count, 3)
        var loop: Double = TripStatistics.haversine(start, points[0])
        loop += TripStatistics.haversine(points[0], points[1])
        loop += TripStatistics.haversine(points[1], points[2])
        loop += TripStatistics.haversine(points[2], start)
        // À vol d'oiseau, environ 30 km / 1,35 × (carré inscrit ≈ 0,9 du cercle).
        XCTAssertEqual(loop, 30_000 / 1.35 * 0.9, accuracy: 3_000)
        // La boucle part du côté demandé (nord-est).
        XCTAssertGreaterThan(points[1].latitude, start.latitude - 0.01)
    }

    func testCurvinessPrefersWindingRoads() {
        let straight: [Coordinate] = (0...100).map { RideLoop.destination(from: start, bearing: 0, meters: Double($0) * 50) }
        var winding: [Coordinate] = [start]
        for index in 1...100 {
            let bearing: Double = index % 4 < 2 ? 30 : -30
            winding.append(RideLoop.destination(from: winding.last!, bearing: bearing, meters: 50))
        }
        XCTAssertLessThan(RideLoop.curviness(straight), 1)
        XCTAssertGreaterThan(RideLoop.curviness(winding), 200)
    }

    func testOverlapDetectsOutAndBack() {
        let out: [Coordinate] = (0...60).map { RideLoop.destination(from: start, bearing: 90, meters: Double($0) * 50) }
        let outAndBack: [Coordinate] = out + out.reversed()
        XCTAssertGreaterThan(RideLoop.overlap(outAndBack), 0.4)
        XCTAssertLessThan(RideLoop.overlap(out), 0.05)
        XCTAssertGreaterThan(RideLoop.score(route: out, meters: 3000, target: 3000),
                             RideLoop.score(route: outAndBack, meters: 3000, target: 3000) - 1)
    }
}
