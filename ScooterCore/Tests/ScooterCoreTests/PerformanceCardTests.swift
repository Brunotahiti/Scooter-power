import XCTest
@testable import ScooterCore

final class PerformanceCardTests: XCTestCase {
    private var stats: PerformanceStats {
        PerformanceStats(trips: [
            TripSummary(distanceMeters: 12_000, maxSpeedKmh: 112, averageSpeedKmh: 48, peakAcceleration: 3.4,
                        maxLeanLeftDegrees: 31, maxLeanRightDegrees: 27, movingDuration: 900, totalDuration: 1000,
                        bestTimes: [.zeroTo50: 4.6, .zeroTo100: 11.2, .fiftyTo90: 6.1]),
            TripSummary(distanceMeters: 8000, maxSpeedKmh: 104, averageSpeedKmh: 44, peakAcceleration: 3.0,
                        maxLeanLeftDegrees: 22, maxLeanRightDegrees: 25, movingDuration: 650, totalDuration: 700,
                        bestTimes: [.zeroTo50: 5.0]),
        ])
    }

    private let date = Date(timeIntervalSince1970: 1_800_000_000)

    func testLinkRoundTripKeepsEverythingCompared() throws {
        let card = PerformanceCard(riderName: "Bruno", setupName: "Variateur sport", date: date, stats: stats)
        let link = card.link
        XCTAssertTrue(link.absoluteString.hasPrefix("scooterpower://card?d="))
        let back = try PerformanceCard(link: link)
        XCTAssertEqual(back, card)
        XCTAssertEqual(back.riderName, "Bruno")
        XCTAssertEqual(back.setupName, "Variateur sport")
        XCTAssertEqual(back.date, date)

        // Les chiffres reconstruits donnent la même comparaison que les originaux, à
        // l'arrondi près (dixième de km/h, centième de seconde).
        let original = PerformanceComparison.deltas(baseline: stats, modified: stats)
        let rebuilt = PerformanceComparison.deltas(baseline: back.stats, modified: stats)
        XCTAssertEqual(original.count, rebuilt.count)
        for (a, b) in zip(original, rebuilt) {
            XCTAssertEqual(a.metric, b.metric)
            XCTAssertEqual(a.baseline == nil, b.baseline == nil, "\(a.metric)")
            if let x = a.baseline, let y = b.baseline {
                XCTAssertEqual(x, y, accuracy: 0.05, "\(a.metric)")
            }
        }
        XCTAssertEqual(back.stats.intervals[.zeroTo50], stats.intervals[.zeroTo50])
        XCTAssertEqual(back.stats.tripCount, 2)
    }

    func testLinkIsShortEnoughForAQRCode() {
        let card = PerformanceCard(riderName: String(repeating: "é", count: 30), setupName: String(repeating: "x", count: 40),
                                   date: date, stats: stats)
        XCTAssertLessThan(card.link.absoluteString.utf8.count, 1200)
    }

    func testNamesAreCleanedAndBounded() throws {
        let card = PerformanceCard(riderName: "  " + String(repeating: "a", count: 80) + "\n", setupName: "",
                                   date: date, stats: stats)
        XCTAssertEqual(card.riderName.count, PerformanceCard.maxNameLength)
        XCTAssertEqual(card.setupName, "")
        let unnamed = PerformanceCard(riderName: "   ", setupName: "x", date: date, stats: stats)
        XCTAssertEqual(unnamed.riderName, "")
    }

    func testRejectsAnythingThatIsNotACard() {
        let bad = [
            "https://example.com/card?d=abc",
            "scooterpower://other?d=abc",
            "scooterpower://card",
            "scooterpower://card?d=",
            "scooterpower://card?d=%%%",
            "scooterpower://card?d=bm90IGpzb24",
        ]
        for text in bad {
            XCTAssertThrowsError(try PerformanceCard(link: URL(string: text) ?? URL(string: "x:")!), text)
        }
        XCTAssertNil(PerformanceCard(text: "bonjour"))
    }

    func testFindsTheLinkInsideAPastedMessage() throws {
        let card = PerformanceCard(riderName: "Teva", setupName: "Origine", date: date, stats: stats)
        let message = "Voici mes perfs Scooter Power ! " + card.link.absoluteString + " À toi de battre ça."
        XCTAssertEqual(PerformanceCard(text: message), card)
    }

    func testRejectsInvalidNumbersAndUnknownIntervals() throws {
        func link(_ json: String) -> URL {
            let data = Data(json.utf8).base64EncodedString()
                .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
            return URL(string: "scooterpower://card?d=" + data)!
        }
        // Mauvaise version de format.
        XCTAssertThrowsError(try PerformanceCard(link: link(#"{"v":99,"n":"a","s":"b","t":0,"st":{}}"#)))
        // Valeurs négatives ou plages inconnues : ignorées, sans planter.
        let odd = try PerformanceCard(link: link(
            #"{"v":1,"n":"a","s":"b","t":0,"st":{"ts":-5,"bp":3,"iv":[{"f":0,"t":50,"b":4,"a":5,"c":2},{"f":7,"t":9,"b":1,"a":1,"c":1},{"f":0,"t":30,"b":-1,"a":2,"c":1}]}}"#))
        XCTAssertEqual(odd.stats.topSpeedKmh, 0)
        XCTAssertEqual(odd.stats.bestPeakAcceleration, 3)
        XCTAssertEqual(Array(odd.stats.intervals.keys), [.zeroTo50])
    }
}
