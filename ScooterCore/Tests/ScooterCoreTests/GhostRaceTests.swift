import XCTest
@testable import ScooterCore

final class GhostRaceTests: XCTestCase {
    /// Ligne droite vers le nord, un point tous les 10 m.
    private let metersPerDegree = 111_320.0
    private func point(_ meters: Double) -> Coordinate {
        Coordinate(latitude: 48 + meters / 111_195, longitude: 2)
    }

    /// Ghost : 10 s d'attente au départ, puis 10 m/s sur 1 km.
    private func ghost() -> GhostRace {
        var route: [Coordinate] = []
        var times: [TimeInterval] = []
        route.append(point(0)); times.append(0)
        for step in 0...100 {
            route.append(point(Double(step) * 10))
            times.append(10 + Double(step))
        }
        return GhostRace(route: route, times: times)!
    }

    func testRejectsShortOrMismatchedRoutes() {
        XCTAssertNil(GhostRace(route: [point(0), point(100)], times: [0, 10]))
        XCTAssertNil(GhostRace(route: [point(0), point(500)], times: [0]))
    }

    func testWaitsForStartThenRaces() {
        var race = ghost()
        let far = race.update(time: 0, coordinate: Coordinate(latitude: 48.01, longitude: 2.01))
        XCTAssertEqual(far.phase, .waitingForStart)
        XCTAssertGreaterThan(far.distanceToStart ?? 0, 1000)
        // Attente au départ : le chrono ne part pas.
        XCTAssertEqual(race.update(time: 100, coordinate: point(0)).phase, .waitingForStart)
        XCTAssertEqual(race.update(time: 130, coordinate: point(20)).phase, .waitingForStart)
        XCTAssertEqual(race.update(time: 132, coordinate: point(45)).phase, .racing)
    }

    func testFasterRiderIsAhead() {
        var race = ghost()
        _ = race.update(time: 0, coordinate: point(0))
        _ = race.update(time: 1, coordinate: point(40))
        // 12,5 m/s contre 10 m/s : après 400 m de plus, 8 s d'avance environ.
        let status = race.update(time: 33, coordinate: point(440))
        XCTAssertEqual(status.phase, .racing)
        XCTAssertEqual(status.gapSeconds ?? 0, 8, accuracy: 0.6)
        XCTAssertGreaterThan(status.gapMeters ?? 0, 0)
        XCTAssertGreaterThan(status.progress, status.ghostProgress)
        XCTAssertFalse(status.offRoute)
    }

    func testSlowerRiderIsBehindAndFinishes() {
        var race = ghost()
        _ = race.update(time: 0, coordinate: point(0))
        _ = race.update(time: 1, coordinate: point(40))
        let behind = race.update(time: 81, coordinate: point(440))
        XCTAssertLessThan(behind.gapSeconds ?? 0, -30)
        let end = race.update(time: 200, coordinate: point(990))
        XCTAssertEqual(end.phase, .finished)
        XCTAssertNotNil(end.finishTime)
        XCTAssertEqual(end.ghostFinishTime ?? 0, 92.5, accuracy: 1)
        XCTAssertLessThan(end.gapSeconds ?? 0, 0)
    }

    func testOffRouteKeepsProgress() {
        var race = ghost()
        _ = race.update(time: 0, coordinate: point(0))
        _ = race.update(time: 1, coordinate: point(40))
        _ = race.update(time: 20, coordinate: point(240))
        let away = race.update(time: 21, coordinate: Coordinate(latitude: 48.0022, longitude: 2.01))
        XCTAssertTrue(away.offRoute)
        XCTAssertEqual(away.phase, .racing)
        XCTAssertEqual(away.progress, 0.24, accuracy: 0.02)
    }

    func testGhostCoordinateFollowsTime() {
        let race = ghost()
        XCTAssertEqual(race.ghostDistance(atTime: 0), 40, accuracy: 0.01)
        XCTAssertEqual(race.ghostTime(atDistance: 540), 50, accuracy: 0.01)
        let middle = race.coordinate(atDistance: 500)
        XCTAssertEqual(middle.latitude, point(500).latitude, accuracy: 1e-6)
    }

    func testMakeUsesRecordedTimesOrAverageSpeed() {
        let route: [Coordinate] = (0...50).map { point(Double($0) * 10) }
        // Arrêt de 30 s au milieu : gardé tel quel.
        let points: [ReplayPoint] = (0...50).map {
            ReplayPoint(time: Double($0) + ($0 > 25 ? 30 : 0), speedKmh: 36, acceleration: 0, leanDegrees: 0)
        }
        let recorded = GhostRace.make(route: route, points: points, averageSpeedKmh: 36)
        XCTAssertEqual(recorded?.ghostTime(atDistance: 500) ?? 0, 76, accuracy: 0.01)
        let estimated = GhostRace.make(route: route, points: [], averageSpeedKmh: 36)
        XCTAssertEqual(estimated?.ghostTime(atDistance: 500) ?? 0, 46, accuracy: 0.5)
    }

    func testResultKeepsTheRaceForReplay() {
        var race = ghost()
        _ = race.update(time: 0, coordinate: point(0))
        _ = race.update(time: 1, coordinate: point(40))
        _ = race.update(time: 40, coordinate: point(500))
        let end = race.update(time: 80, coordinate: point(990))
        XCTAssertEqual(end.phase, .finished)
        let result = GhostRaceResult(title: "Ghost", race: race, status: end, raceStart: 100)
        XCTAssertEqual(result.won, true)
        XCTAssertEqual(result.ghostTimes.count, race.route.count)
        let ghost = result.ghostReplay()
        // Le ghost passe la ligne au bout de `lead` secondes de revisualisation.
        let atStart = ghost.frame(at: GhostRaceResult.lead)!
        XCTAssertEqual(atStart.coordinate.latitude, point(40).latitude, accuracy: 2e-5)
        // Mon trajet : seuls les points de la course sont gardés.
        let route: [Coordinate] = (0...200).map { point(Double($0) * 5) }
        let points: [ReplayPoint] = route.indices.map { ReplayPoint(time: 90 + Double($0) * 0.5, speedKmh: 36, acceleration: 0, leanDegrees: 0) }
        let mine = result.riderReplay(route: route, points: points)
        XCTAssertEqual(mine.route.count, 2 * Int(79 + 3 + 3) + 1)
        XCTAssertEqual(mine.points.first!.time, 0, accuracy: 1e-9)
        var lost = result
        lost.riderTime = 200
        XCTAssertEqual(lost.won, false)
        lost.finished = false
        XCTAssertNil(lost.won)
    }
}
