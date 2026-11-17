import XCTest
@testable import ScooterCore

final class GroupRideTests: XCTestCase {
    func testLinkRoundTrip() throws {
        let link = RideLink.random()
        XCTAssertEqual(link.rideID.count, RideLink.idLength)
        XCTAssertEqual(link.url.absoluteString, "scooterpower://ride?id=\(link.rideID)")
        XCTAssertEqual(RideLink(url: link.url), link)
    }

    func testLinkAcceptsLowercaseAndRejectsOthers() throws {
        XCTAssertEqual(RideLink(url: URL(string: "scooterpower://ride?id=abcd2345")!)?.rideID, "ABCD2345")
        XCTAssertNil(RideLink(url: URL(string: "scooterpower://card?d=abc")!))
        XCTAssertNil(RideLink(url: URL(string: "scooterpower://ride?id=SHORT")!))
        XCTAssertNil(RideLink(url: URL(string: "scooterpower://ride?id=ABCD234O")!))
        XCTAssertNil(RideLink(url: URL(string: "https://ride?id=ABCD2345")!))
        XCTAssertNil(RideLink(url: URL(string: "scooterpower://ride")!))
    }

    func testRosterCapacityOrderAndColors() throws {
        var roster = GroupRoster()
        for id in ["a", "b", "c", "d", "e"] { try roster.join(id) }
        XCTAssertTrue(roster.isFull)
        XCTAssertThrowsError(try roster.join("f")) { XCTAssertEqual($0 as? GroupRoster.JoinError, .full) }
        // Rejoindre à nouveau est sans effet, même quand c'est complet.
        XCTAssertNoThrow(try roster.join("c"))
        XCTAssertEqual(roster.colorIndex(of: "c"), 2)
        roster.leave("b")
        XCTAssertEqual(roster.colorIndex(of: "c"), 1)
        XCTAssertNil(roster.colorIndex(of: "b"))
        XCTAssertNoThrow(try roster.join("f"))
        XCTAssertEqual(roster.members, ["a", "c", "d", "e", "f"])
    }

    func testRosterCleansStoredMembers() {
        let roster = GroupRoster(members: ["a", "a", "", "b", "c", "d", "e", "f"])
        XCTAssertEqual(roster.members, ["a", "b", "c", "d", "e"])
    }

    func testStaleness() {
        let now = Date()
        let position = RiderPosition(
            riderID: "a", name: "A", coordinate: Coordinate(latitude: 0, longitude: 0), speedKmh: 30,
            heading: 0, leanDegrees: 0, acceleration: 0, updatedAt: now.addingTimeInterval(-10))
        XCTAssertFalse(position.isStale(at: now))
        XCTAssertTrue(position.isStale(at: now.addingTimeInterval(60)))
    }

    func testTrailSpacingAndLimit() {
        var trail = RiderTrail()
        trail.add(Coordinate(latitude: 0, longitude: 0))
        trail.add(Coordinate(latitude: 0, longitude: 0.00001)) // ≈ 1 m : ignoré
        XCTAssertEqual(trail.points.count, 1)
        for step in 1...200 {
            trail.add(Coordinate(latitude: 0, longitude: Double(step) * 0.0001))
        }
        XCTAssertEqual(trail.points.count, RiderTrail.maxPoints)
        XCTAssertEqual(trail.points.last?.longitude ?? 0, 0.02, accuracy: 1e-9)
    }
}

final class GroupRideRecorderTests: XCTestCase {
    private func position(_ id: String, _ seconds: Double, lon: Double, speed: Double = 30) -> RiderPosition {
        RiderPosition(
            riderID: id, name: id.uppercased(), coordinate: Coordinate(latitude: 0, longitude: lon),
            speedKmh: speed, heading: 90, leanDegrees: 5, acceleration: 1,
            updatedAt: Date(timeIntervalSince1970: 1000 + seconds))
    }

    func testRecordsTracksOnACommonClock() throws {
        var recorder = GroupRideRecorder()
        recorder.add(position("a", 0, lon: 0), colorIndex: 0, isMe: true)
        recorder.add(position("a", 3, lon: 0.001), colorIndex: 0, isMe: true)
        recorder.add(position("a", 3, lon: 0.002), colorIndex: 0, isMe: true) // déjà reçu : ignoré
        recorder.add(position("b", 30, lon: 0.01), colorIndex: 1, isMe: false)
        recorder.add(position("b", 33, lon: 0.011), colorIndex: 1, isMe: false)
        let tracks = recorder.recordedTracks
        XCTAssertEqual(tracks.map(\.riderID), ["a", "b"])
        XCTAssertEqual(tracks[0].points.map(\.time), [0, 3])
        XCTAssertEqual(tracks[1].points.map(\.time), [30, 33])
        // B commence à 30 s : avant, il attend à son premier point.
        let replay = tracks[1].replay
        XCTAssertEqual(replay.duration, 33, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(replay.frame(at: 0)).coordinate.longitude, 0.01, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(replay.frame(at: 31.5)).coordinate.longitude, 0.0105, accuracy: 1e-9)
    }

    func testSinglePointRidersAreLeftOut() {
        var recorder = GroupRideRecorder()
        recorder.add(position("a", 0, lon: 0), colorIndex: 0, isMe: true)
        XCTAssertTrue(recorder.isEmpty)
    }

    func testTrackRoundTripsThroughJSON() throws {
        let track = GroupRideTrack(
            riderID: "a", name: "A", colorIndex: 2, isMe: false,
            route: [Coordinate(latitude: 0, longitude: 0), Coordinate(latitude: 0, longitude: 0.001)],
            points: [
                ReplayPoint(time: 10, speedKmh: 20, acceleration: 0, leanDegrees: 0),
                ReplayPoint(time: 13, speedKmh: 25, acceleration: 0, leanDegrees: 0),
            ])
        let decoded = try JSONDecoder().decode([GroupRideTrack].self, from: JSONEncoder().encode([track]))
        XCTAssertEqual(decoded, [track])
    }
}
