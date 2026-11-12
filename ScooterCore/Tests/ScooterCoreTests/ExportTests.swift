import XCTest
@testable import ScooterCore

final class ExportTests: XCTestCase {
    func testGPXDocument() {
        let route = [Coordinate(latitude: 48.8566, longitude: 2.3522), Coordinate(latitude: -17.535, longitude: -149.5696)]
        let gpx = GPXExporter.document(route: route, name: "Trajet <A & B>", date: Date(timeIntervalSince1970: 0))
        XCTAssertTrue(gpx.hasPrefix("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<gpx version=\"1.1\""))
        XCTAssertTrue(gpx.contains("xmlns=\"http://www.topografix.com/GPX/1/1\""))
        XCTAssertTrue(gpx.contains("<name>Trajet &lt;A &amp; B&gt;</name>"))
        XCTAssertTrue(gpx.contains("<time>1970-01-01T00:00:00Z</time>"))
        XCTAssertTrue(gpx.contains("<trkpt lat=\"48.856600\" lon=\"2.352200\"/>"))
        XCTAssertTrue(gpx.contains("<trkpt lat=\"-17.535000\" lon=\"-149.569600\"/>"))
        XCTAssertTrue(gpx.hasSuffix("</gpx>\n"))
        XCTAssertEqual(gpx.components(separatedBy: "<trkpt").count - 1, 2)
    }

    func testGPXWithoutDateOrPoints() {
        let gpx = GPXExporter.document(route: [], name: "Vide", date: nil)
        XCTAssertFalse(gpx.contains("<time>"))
        XCTAssertTrue(gpx.contains("<trkseg>\n    </trkseg>"))
        // Les points non finis sont écartés.
        let odd = GPXExporter.document(route: [Coordinate(latitude: .nan, longitude: 1)], name: "x", date: nil)
        XCTAssertFalse(odd.contains("<trkpt"))
    }

    func testFileNameIsSafe() {
        XCTAssertEqual(GPXExporter.fileName(for: "12 nov. 2026 à 07:36"), "ScooterPower-12-nov-2026-a-07-36")
        XCTAssertEqual(GPXExporter.fileName(for: "///"), "ScooterPower")
    }

    func testProjectionFitsUnitSquareKeepingShape() {
        // Tracé deux fois plus large que haut, à l'équateur.
        let route = [
            Coordinate(latitude: 0, longitude: 0), Coordinate(latitude: 0, longitude: 0.02),
            Coordinate(latitude: 0.01, longitude: 0.02),
        ]
        let p = RouteProjector.unitPoints(route)
        XCTAssertEqual(p.count, 3)
        XCTAssertEqual(p[0].x, 0, accuracy: 1e-9)
        XCTAssertEqual(p[1].x, 1, accuracy: 1e-9)
        // Centré verticalement : il occupe la moitié de la hauteur. Le nord est en haut.
        XCTAssertEqual(p[0].y, 0.75, accuracy: 1e-9)
        XCTAssertEqual(p[2].y, 0.25, accuracy: 1e-9)
    }

    func testProjectionDegenerateCases() {
        XCTAssertTrue(RouteProjector.unitPoints([]).isEmpty)
        let same = Coordinate(latitude: 10, longitude: 20)
        XCTAssertEqual(RouteProjector.unitPoints([same, same]), [PlanePoint(x: 0.5, y: 0.5), PlanePoint(x: 0.5, y: 0.5)])
        // Aux hautes latitudes, un degré de longitude est plus court : le tracé reste proportionné.
        let north = RouteProjector.unitPoints([
            Coordinate(latitude: 60, longitude: 0), Coordinate(latitude: 60, longitude: 0.02),
            Coordinate(latitude: 60.01, longitude: 0.02),
        ])
        // La latitude moyenne est 60,005° : le tracé est carré à un millième près.
        XCTAssertEqual(north[1].x - north[0].x, 1, accuracy: 1e-3)
        XCTAssertEqual(north[0].y - north[2].y, 1, accuracy: 1e-3)
    }
}
