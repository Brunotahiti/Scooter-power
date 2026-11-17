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
