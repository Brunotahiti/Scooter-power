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
