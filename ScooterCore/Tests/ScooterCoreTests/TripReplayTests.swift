import XCTest
@testable import ScooterCore

final class TripReplayTests: XCTestCase {
    /// Trois points vers l'est, espacés d'environ 111 m.
    private let route: [Coordinate] = [
        Coordinate(latitude: 0, longitude: 0),
        Coordinate(latitude: 0, longitude: 0.001),
        Coordinate(latitude: 0, longitude: 0.002),
    ]

    private func points(_ times: [Double]) -> [ReplayPoint] {
        times.enumerated().map { index, time in
            ReplayPoint(time: time, speedKmh: Double(index) * 10, acceleration: Double(index), leanDegrees: Double(index) * 5)
        }
    }

    func testInterpolatesPositionAndValues() throws {
        let replay = TripReplay(route: route, points: points([0, 2, 4]), averageSpeedKmh: 30)
        XCTAssertTrue(replay.isRecorded)
        XCTAssertEqual(replay.duration, 4, accuracy: 1e-9)
        let frame = try XCTUnwrap(replay.frame(at: 1))
        XCTAssertEqual(frame.coordinate.longitude, 0.0005, accuracy: 1e-9)
        XCTAssertEqual(frame.speedKmh, 5, accuracy: 1e-9)
        XCTAssertEqual(frame.leanDegrees, 2.5, accuracy: 1e-9)
        XCTAssertEqual(frame.heading, 90, accuracy: 0.01)
        XCTAssertEqual(frame.index, 0)
    }

    func testClampsTimeAndReachesEnd() throws {
        let replay = TripReplay(route: route, points: points([0, 2, 4]), averageSpeedKmh: 30)
        XCTAssertEqual(try XCTUnwrap(replay.frame(at: -5)).coordinate, route[0])
        let end = try XCTUnwrap(replay.frame(at: 99))
        XCTAssertEqual(end.coordinate.longitude, 0.002, accuracy: 1e-9)
        XCTAssertEqual(end.index, 2)
    }

    func testLongPausesAreShortened() {
        let replay = TripReplay(route: route, points: points([0, 2, 300]), averageSpeedKmh: 30)
        XCTAssertEqual(replay.duration, 2 + TripReplay.maxGap, accuracy: 1e-9)
    }

    func testOldTripsReplayAtAverageSpeed() throws {
        let replay = TripReplay(route: route, points: [], averageSpeedKmh: 40)
        XCTAssertFalse(replay.isRecorded)
        // 222 m à 40 km/h ≈ 20 s.
        XCTAssertEqual(replay.duration, 20, accuracy: 0.2)
        XCTAssertEqual(try XCTUnwrap(replay.frame(at: 5)).speedKmh, 40, accuracy: 1e-9)
    }

    func testHeadingKeepsLastDirectionWhenStopped() throws {
        let stopped: [Coordinate] = route + [route[2]]
        let replay = TripReplay(route: stopped, points: points([0, 2, 4, 6]), averageSpeedKmh: 30)
        XCTAssertEqual(try XCTUnwrap(replay.frame(at: 5)).heading, 90, accuracy: 0.01)
    }

    func testBearing() {
        let origin = Coordinate(latitude: 0, longitude: 0)
        XCTAssertEqual(TripReplay.bearing(from: origin, to: Coordinate(latitude: 1, longitude: 0)), 0, accuracy: 0.01)
        XCTAssertEqual(TripReplay.bearing(from: origin, to: Coordinate(latitude: 0, longitude: -1)), 270, accuracy: 0.01)
    }

    func testSessionRecordsReplayTrackAlignedWithRoute() {
        var session = TripSession()
        session.start(at: 100)
        for step in 0..<5 {
            session.handle(LocationSample(
                timestamp: 100 + Double(step), latitude: 0, longitude: Double(step) * 0.0001,
                speed: 10, altitude: 0, horizontalAccuracy: 5))
        }
        XCTAssertEqual(session.replayTrack.count, session.statistics.route.count)
        XCTAssertEqual(session.replayTrack.first?.time, 0)
        XCTAssertEqual(session.replayTrack.last?.time, 4)
        XCTAssertEqual(session.replayTrack.last?.speedKmh ?? 0, 36, accuracy: 1e-9)
    }
}

final class SharedTripTests: XCTestCase {
    private func summary() -> TripSummary {
        TripSummary(
            distanceMeters: 1200, maxSpeedKmh: 82, averageSpeedKmh: 41, peakAcceleration: 2,
            maxLeanLeftDegrees: 20, maxLeanRightDegrees: 25, movingDuration: 100, totalDuration: 120, bestTimes: [:])
    }

    func testRoundTrip() throws {
        let route = (0..<10).map { Coordinate(latitude: 48.1234567, longitude: 2.0 + Double($0) * 0.0001) }
        let points = (0..<10).map { ReplayPoint(time: Double($0), speedKmh: 33.33, acceleration: 0.04, leanDegrees: 12.4) }
        let trip = SharedTrip(
            riderName: "Bruno", setupName: "Origine", date: Date(timeIntervalSince1970: 1_000_000),
            summary: summary(), route: route, points: points)
        let decoded = try SharedTrip(data: trip.encoded())
        XCTAssertEqual(decoded, trip)
        XCTAssertEqual(decoded.route.count, 10)
        XCTAssertEqual(decoded.points.first?.speedKmh, 33.3)
        XCTAssertEqual(decoded.route.first?.latitude ?? 0, 48.123457, accuracy: 1e-9)
        XCTAssertTrue(decoded.replay.isRecorded)
    }

    func testLimitsPointsAndNames() throws {
        let route = (0..<3000).map { Coordinate(latitude: 0, longitude: Double($0) * 0.00001) }
        let points = (0..<3000).map { ReplayPoint(time: Double($0), speedKmh: 20, acceleration: 0, leanDegrees: 0) }
        let trip = SharedTrip(
            riderName: String(repeating: "x", count: 80), setupName: "", date: Date(),
            summary: summary(), route: route, points: points)
        XCTAssertLessThanOrEqual(trip.route.count, SharedTrip.maxPoints)
        XCTAssertEqual(trip.points.count, trip.route.count)
        XCTAssertEqual(trip.riderName.count, SharedTrip.maxNameLength)
        XCTAssertLessThan(try trip.encoded().count, 120_000)
    }

    func testRejectsInvalidFiles() {
        XCTAssertThrowsError(try SharedTrip(data: Data("pas du json".utf8)))
        let oneVersionAhead = """
        {"version":99,"riderName":"a","setupName":"","date":0,"distanceMeters":0,"maxSpeedKmh":0,
        "averageSpeedKmh":0,"totalDuration":0,"route":[{"latitude":0,"longitude":0},{"latitude":0,"longitude":1}],"points":[]}
        """
        XCTAssertThrowsError(try SharedTrip(data: Data(oneVersionAhead.utf8)))
        let empty = """
        {"version":1,"riderName":"a","setupName":"","date":0,"distanceMeters":0,"maxSpeedKmh":0,
        "averageSpeedKmh":0,"totalDuration":0,"route":[],"points":[]}
        """
        XCTAssertThrowsError(try SharedTrip(data: Data(empty.utf8)))
    }

    func testOldTripWithoutPointsStillShares() throws {
        let route = (0..<5).map { Coordinate(latitude: 0, longitude: Double($0) * 0.001) }
        let trip = SharedTrip(
            riderName: "A", setupName: "", date: Date(), summary: summary(), route: route, points: [])
        let decoded = try SharedTrip(data: trip.encoded())
        XCTAssertTrue(decoded.points.isEmpty)
        XCTAssertFalse(decoded.replay.isRecorded)
    }
}
