import XCTest
@testable import ScooterCore

final class TripHighlightsTests: XCTestCase {
    /// Un point par seconde vers l'est ; `lon` avance de 0,0001° par seconde.
    private func loc(_ t: Double, speedKmh: Double) -> LocationSample {
        LocationSample(timestamp: t, latitude: 0, longitude: t * 0.0001, speed: speedKmh / 3.6,
                       altitude: 0, horizontalAccuracy: 5)
    }

    private func mot(_ t: Double, forwardG: Double = 0) -> MotionSample {
        MotionSample(timestamp: t, gravity: Vector3(0, -1, 0), userAcceleration: Vector3(0, 0, -forwardG))
    }

    func testSprintHighlightMarksWhereTheTargetWasReached() {
        var s = TripSession()
        s.start(at: 0)
        for i in 0...7 {
            s.handle(loc(Double(i), speedKmh: 10 * Double(i)))
        }
        let fifty = s.highlights.first { $0.kind == .sprint(.zeroTo50) }
        XCTAssertNotNil(fifty)
        XCTAssertEqual(fifty!.value, 4.9, accuracy: 1e-6)
        // Départ à t = 0,1 : point le plus proche, t = 0. Arrivée à t = 5 : point t = 5.
        XCTAssertEqual(fifty!.start!.longitude, 0, accuracy: 1e-9)
        XCTAssertEqual(fifty!.end.longitude, 0.0005, accuracy: 1e-9)
        XCTAssertNotNil(s.highlights.first { $0.kind == .sprint(.zeroTo30) })
    }

    func testOnlyTheBestRunOfEachIntervalIsKept() {
        var s = TripSession()
        s.start(at: 0)
        // Premier départ, lent : 5 km/h par seconde.
        for i in 0...11 { s.handle(loc(Double(i), speedKmh: 5 * Double(i))) }
        // Arrêt, puis départ rapide : 12,5 km/h par seconde.
        s.handle(loc(20, speedKmh: 0))
        for i in 1...5 { s.handle(loc(20 + Double(i), speedKmh: 12.5 * Double(i))) }
        let fifty = s.highlights.filter { $0.kind == .sprint(.zeroTo50) }
        XCTAssertEqual(fifty.count, 1)
        XCTAssertEqual(fifty[0].value, 3.92, accuracy: 1e-6)
        XCTAssertEqual(fifty[0].end.longitude, 0.0024, accuracy: 1e-9)
    }

    func testPeakHighlightIsWhereTheThrustPeaked() {
        var s = TripSession()
        s.start(at: 0)
        s.handle(mot(0))
        s.handle(loc(0, speedKmh: 20))
        var t = 0.02
        while t < 3 { s.handle(mot(t, forwardG: 0.1)); t += 0.02 }
        s.handle(loc(3, speedKmh: 30))
        while t < 7 { s.handle(mot(t, forwardG: 0.3)); t += 0.02 }
        s.handle(loc(7, speedKmh: 40))
        while t < 10 { s.handle(mot(t, forwardG: 0.05)); t += 0.02 }
        let peak = s.highlights.first { $0.kind == .peakAcceleration }
        XCTAssertNotNil(peak)
        XCTAssertEqual(peak!.value, s.acceleration.tripPeak, accuracy: 1e-9)
        // Le pic est atteint entre t = 3 et t = 7 : la dernière position connue est celle de t = 3.
        XCTAssertEqual(peak!.end.longitude, 0.0003, accuracy: 1e-9)
        XCTAssertNil(peak!.start)
    }

    func testThrustTrackFollowsTheRoute() {
        var s = TripSession()
        s.start(at: 0)
        s.handle(mot(0))
        s.handle(loc(0, speedKmh: 20))
        var t = 0.02
        while t < 3 { s.handle(mot(t, forwardG: 0.2)); t += 0.02 }
        s.handle(loc(3, speedKmh: 30))
        // Point rejeté (précision insuffisante) : ni tracé ni poussée.
        s.handle(LocationSample(timestamp: 4, latitude: 0, longitude: 0.0004, speed: 9, altitude: 0, horizontalAccuracy: 90))
        XCTAssertEqual(s.statistics.route.count, 2)
        XCTAssertEqual(s.thrustTrack.count, 2)
        XCTAssertEqual(s.thrustTrack[1], s.acceleration.current, accuracy: 1e-9)
    }

    func testNoHighlightsBeforeAnyLocationOrAfterReset() {
        var s = TripSession()
        s.start(at: 0)
        s.handle(mot(0))
        var t = 0.02
        while t < 3 { s.handle(mot(t, forwardG: 0.3)); t += 0.02 }
        // Pas de position connue : le pic ne peut pas être placé.
        XCTAssertTrue(s.highlights.isEmpty)
        s.reset()
        XCTAssertTrue(s.highlights.isEmpty)
        XCTAssertTrue(s.thrustTrack.isEmpty)
    }

    func testHighlightsAndThrustSurviveJSON() throws {
        let h = [
            TripHighlight(kind: .sprint(.fiftyTo90), value: 6.1,
                          start: Coordinate(latitude: 1, longitude: 2), end: Coordinate(latitude: 3, longitude: 4)),
            TripHighlight(kind: .peakAcceleration, value: 3.2, start: nil, end: Coordinate(latitude: 5, longitude: 6)),
        ]
        let data = try JSONEncoder().encode(h)
        XCTAssertEqual(try JSONDecoder().decode([TripHighlight].self, from: data), h)
    }

    func testDownsampleIndicesKeepPairsAligned() {
        XCTAssertEqual(RouteSimplifier.indices(count: 3, maxPoints: 10), [0, 1, 2])
        let idx = RouteSimplifier.indices(count: 10_000, maxPoints: 2000)
        XCTAssertEqual(idx.first, 0)
        XCTAssertEqual(idx.last, 9999)
        XCTAssertLessThanOrEqual(idx.count, 2000)
        XCTAssertEqual(idx, idx.sorted())
        XCTAssertTrue(RouteSimplifier.indices(count: 0, maxPoints: 5).isEmpty)
    }
}
