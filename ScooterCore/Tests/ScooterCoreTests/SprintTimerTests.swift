import XCTest
@testable import ScooterCore

final class SprintTimerTests: XCTestCase {
    /// Accélération constante de `rate` km/h par seconde, un point par seconde, départ à t = `start`.
    private func launch(_ timer: inout SprintTimer, start: Double, rate: Double, seconds: Int) {
        for i in 1...seconds {
            timer.add(timestamp: start + Double(i), speedKmh: rate * Double(i))
        }
    }

    func testMeasuresBothTargetsWithInterpolation() {
        var t = SprintTimer()
        t.add(timestamp: 0, speedKmh: 0)
        launch(&t, start: 0, rate: 8, seconds: 11)
        // Départ interpolé au passage de 1 km/h : t = 0,125. 50 km/h à 6,25 ; 80 km/h à 10.
        XCTAssertEqual(t.last50!, 6.125, accuracy: 1e-6)
        XCTAssertEqual(t.last80!, 9.875, accuracy: 1e-6)
        XCTAssertEqual(t.best50!, 6.125, accuracy: 1e-6)
        XCTAssertFalse(t.isRunning)
    }

    func testStandingStartAlsoTimesThirtyAndEighty() {
        var t = SprintTimer()
        t.add(timestamp: 0, speedKmh: 0)
        launch(&t, start: 0, rate: 8, seconds: 11)
        // 30 km/h franchi à t = 3,75 ; départ à 0,125.
        XCTAssertEqual(t.last(.zeroTo30)!, 3.625, accuracy: 1e-6)
        XCTAssertEqual(t.best(.zeroTo50)!, 6.125, accuracy: 1e-6)
        XCTAssertEqual(t.best(.zeroTo80)!, 9.875, accuracy: 1e-6)
        XCTAssertEqual(t.bestTimes[.zeroTo30]!, 3.625, accuracy: 1e-6)
    }

    // MARK: - Reprises lancées

    /// Vitesses successives, un point par seconde à partir de `start`.
    private func feed(_ timer: inout SprintTimer, start: Double, speeds: [Double]) {
        for (i, v) in speeds.enumerated() {
            timer.add(timestamp: start + Double(i), speedKmh: v)
        }
    }

    func testRollingFiftyToNinetyAndHundred() {
        var t = SprintTimer()
        feed(&t, start: 0, speeds: [40, 40, 45, 55, 65, 75, 85, 95, 105])
        // 50 km/h franchi à t = 2,5 ; 90 à t = 6,5 ; 100 à t = 7,5.
        XCTAssertEqual(t.last(.fiftyTo90)!, 4.0, accuracy: 1e-6)
        XCTAssertEqual(t.last(.fiftyTo100)!, 5.0, accuracy: 1e-6)
        XCTAssertFalse(t.isRolling)
        // Pas de départ arrêté : rien d'autre n'est mesuré.
        XCTAssertNil(t.last(.zeroTo50))
    }

    func testRollingIsTimedDuringAStandingStartToo() {
        var t = SprintTimer()
        t.add(timestamp: 0, speedKmh: 0)
        launch(&t, start: 0, rate: 10, seconds: 10)
        XCTAssertEqual(t.last(.fiftyTo90)!, 4.0, accuracy: 1e-6)
        XCTAssertEqual(t.last(.fiftyTo100)!, 5.0, accuracy: 1e-6)
    }

    func testRollingNeedsToCrossFiftyUpward() {
        var t = SprintTimer()
        feed(&t, start: 0, speeds: [60, 70, 80, 90, 100, 110])
        XCTAssertNil(t.last(.fiftyTo90))
        XCTAssertFalse(t.isRolling)
    }

    func testLiftingOffCancelsRollingThenItRearmsBelowFifty() {
        var t = SprintTimer()
        feed(&t, start: 0, speeds: [40, 55, 70, 62])
        XCTAssertFalse(t.isRolling)
        feed(&t, start: 4, speeds: [95, 105])
        XCTAssertNil(t.last(.fiftyTo90))
        // Retour sous 50 km/h, puis nouvelle reprise.
        feed(&t, start: 6, speeds: [45, 55, 65, 75, 85, 95])
        XCTAssertEqual(t.last(.fiftyTo90)!, 4.0, accuracy: 1e-6)
        XCTAssertNil(t.last(.fiftyTo100))
        XCTAssertTrue(t.isRolling)
        XCTAssertEqual(t.activeElapsed(at: 12)!, 5.5, accuracy: 1e-6)
    }

    func testRollingGapPauseAndImplausibleJump() {
        var t = SprintTimer()
        feed(&t, start: 0, speeds: [45, 55])
        t.add(timestamp: 6, speedKmh: 95)
        XCTAssertNil(t.last(.fiftyTo90))

        feed(&t, start: 10, speeds: [45, 55])
        XCTAssertTrue(t.isRolling)
        t.cancelRun()
        XCTAssertFalse(t.isRolling)
        feed(&t, start: 12, speeds: [95])
        XCTAssertNil(t.last(.fiftyTo90))

        // 45 → 120 km/h en une seconde : saut GPS.
        feed(&t, start: 20, speeds: [45, 120])
        XCTAssertNil(t.last(.fiftyTo90))
        XCTAssertNil(t.last(.fiftyTo100))
    }

    func testRollingBestKeepsFastest() {
        var t = SprintTimer()
        feed(&t, start: 0, speeds: [45, 55, 65, 75, 85, 95])
        feed(&t, start: 10, speeds: [40, 50, 55, 60, 65, 70, 75, 80, 85, 90])
        XCTAssertEqual(t.last(.fiftyTo90)!, 8.0, accuracy: 1e-6)
        XCTAssertEqual(t.best(.fiftyTo90)!, 4.0, accuracy: 1e-6)
    }

    func testResultsLogEveryMeasurementInOrder() {
        var t = SprintTimer()
        XCTAssertTrue(t.results.isEmpty)
        t.add(timestamp: 0, speedKmh: 0)
        launch(&t, start: 0, rate: 10, seconds: 10)
        XCTAssertEqual(t.results.map(\.interval), [.zeroTo30, .zeroTo50, .zeroTo80, .fiftyTo90, .fiftyTo100])
        XCTAssertEqual(t.results[1].time, 4.9, accuracy: 1e-6)
        // Un second départ, plus lent, s'ajoute au journal sans remplacer le premier.
        t.add(timestamp: 20, speedKmh: 0)
        launch(&t, start: 20, rate: 5, seconds: 7)
        XCTAssertEqual(t.results.count, 6)
        XCTAssertEqual(t.results[5].interval, .zeroTo30)
        XCTAssertEqual(t.results[5].time, 5.8, accuracy: 1e-6)
    }

    func testIntervalLabels() {
        XCTAssertEqual(SpeedInterval.all.map(\.label), ["0–30", "0–50", "0–80", "50–90", "50–100"])
    }

    func testNothingWithoutStandstill() {
        var t = SprintTimer()
        t.add(timestamp: 0, speedKmh: 20)
        launch(&t, start: 0, rate: 10, seconds: 9)
        XCTAssertNil(t.last50)
        XCTAssertFalse(t.isRunning)
    }

    func testRunningAndElapsed() {
        var t = SprintTimer()
        t.add(timestamp: 10, speedKmh: 0)
        XCTAssertFalse(t.isRunning)
        XCTAssertNil(t.runElapsed(at: 10))
        t.add(timestamp: 11, speedKmh: 10)
        XCTAssertTrue(t.isRunning)
        XCTAssertEqual(t.runElapsed(at: 12)!, 1.9, accuracy: 1e-6)
    }

    func testSlowingDownCancelsButKeepsFifty() {
        var t = SprintTimer()
        t.add(timestamp: 0, speedKmh: 0)
        launch(&t, start: 0, rate: 10, seconds: 6)
        XCTAssertNotNil(t.last50)
        t.add(timestamp: 7, speedKmh: 56)
        XCTAssertFalse(t.isRunning)
        t.add(timestamp: 8, speedKmh: 90)
        XCTAssertNil(t.last80)
        XCTAssertNotNil(t.best50)
    }

    func testSmallDipDoesNotCancel() {
        var t = SprintTimer()
        t.add(timestamp: 0, speedKmh: 0)
        t.add(timestamp: 1, speedKmh: 20)
        t.add(timestamp: 2, speedKmh: 18)
        XCTAssertTrue(t.isRunning)
    }

    func testCreepingBeforeLaunchIsNotTimed() {
        // Avancer au pas dans une file, puis accélérer franchement.
        var t = SprintTimer()
        t.add(timestamp: 0, speedKmh: 0)
        for i in 1...18 { t.add(timestamp: Double(i), speedKmh: 2) }
        for i in 1...5 { t.add(timestamp: 18 + Double(i), speedKmh: 2 + 10 * Double(i)) }
        // Départ compté au dernier point au pas (t = 18) ; 50 km/h atteint à t = 22,8.
        XCTAssertEqual(t.last50!, 4.8, accuracy: 1e-6)
    }

    func testSlowFirstSecondStillCountsFromStandstill() {
        var t = SprintTimer()
        t.add(timestamp: 0, speedKmh: 0)
        t.add(timestamp: 1, speedKmh: 3)
        t.add(timestamp: 2, speedKmh: 20)
        t.add(timestamp: 3, speedKmh: 40)
        t.add(timestamp: 4, speedKmh: 60)
        // Départ interpolé à t = 1/3 ; 50 km/h à t = 3,5.
        XCTAssertEqual(t.last50!, 3.5 - 1.0 / 3.0, accuracy: 1e-6)
    }

    func testBestKeepsFastestAndLastKeepsLatest() {
        var t = SprintTimer()
        t.add(timestamp: 0, speedKmh: 0)
        launch(&t, start: 0, rate: 10, seconds: 9)
        let first = t.last50!
        t.add(timestamp: 20, speedKmh: 0)
        t.add(timestamp: 21, speedKmh: 0)
        launch(&t, start: 21, rate: 5, seconds: 17)
        XCTAssertGreaterThan(t.last50!, first)
        XCTAssertEqual(t.best50!, first, accuracy: 1e-9)
    }

    func testGapTimeoutAndManualCancel() {
        var t = SprintTimer()
        t.add(timestamp: 0, speedKmh: 0)
        t.add(timestamp: 1, speedKmh: 10)
        t.add(timestamp: 5, speedKmh: 60)
        XCTAssertFalse(t.isRunning)
        XCTAssertNil(t.last50)

        t.add(timestamp: 10, speedKmh: 0)
        for i in 1...61 { t.add(timestamp: 10 + Double(i), speedKmh: 30) }
        XCTAssertFalse(t.isRunning)

        t.add(timestamp: 100, speedKmh: 0)
        t.add(timestamp: 101, speedKmh: 10)
        t.cancelRun()
        XCTAssertFalse(t.isRunning)
        t.add(timestamp: 102, speedKmh: 60)
        XCTAssertNil(t.last50)
    }

    func testImplausibleJumpAndBadInputRejected() {
        var t = SprintTimer()
        t.add(timestamp: 0, speedKmh: 0)
        t.add(timestamp: 1, speedKmh: 95)
        XCTAssertNil(t.last50)
        XCTAssertNil(t.last80)
        t.add(timestamp: 2, speedKmh: .nan)
        t.add(timestamp: 2, speedKmh: 0)
        t.add(timestamp: 1, speedKmh: 0)
        XCTAssertFalse(t.isRunning)
    }
}
