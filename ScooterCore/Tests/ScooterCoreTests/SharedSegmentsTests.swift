import XCTest
@testable import ScooterCore

final class SharedSegmentsTests: XCTestCase {
    func testCellsAroundTahiti() {
        let papeete = Coordinate(latitude: -17.5357, longitude: -149.5696)
        XCTAssertEqual(SharedSegments.cell(for: papeete), "-176_-1496")
        let near = SharedSegments.nearbyCells(around: papeete)
        XCTAssertEqual(near.count, 9)
        XCTAssertTrue(near.contains("-176_-1496"))
        XCTAssertTrue(near.contains("-175_-1495"))
        // Deux trajets dans la même zone : pas de doublon.
        let cells = SharedSegments.cells(around: [papeete, Coordinate(latitude: -17.54, longitude: -149.57)])
        XCTAssertEqual(cells.count, 9)
    }

    func testPlausibility() {
        XCTAssertTrue(SharedSegments.isPlausible(seconds: 60, lengthMeters: 1000))   // 60 km/h
        XCTAssertFalse(SharedSegments.isPlausible(seconds: 10, lengthMeters: 1000))  // 360 km/h
        XCTAssertFalse(SharedSegments.isPlausible(seconds: 1000, lengthMeters: 1000)) // 3,6 km/h
        XCTAssertFalse(SharedSegments.isPlausible(seconds: .nan, lengthMeters: 1000))
    }

    func testPathRoundTrip() {
        let path = [Coordinate(latitude: -17.123456, longitude: -149.654321), Coordinate(latitude: -17.2, longitude: -149.7)]
        let back = SharedSegments.decodePath(SharedSegments.encodePath(path))
        XCTAssertEqual(back.count, 2)
        XCTAssertEqual(back[0].latitude, -17.123456, accuracy: 1e-6)
        XCTAssertEqual(SharedSegments.timeRecordName(segmentID: "S", riderID: "R"), "st_S_R")
    }
}
