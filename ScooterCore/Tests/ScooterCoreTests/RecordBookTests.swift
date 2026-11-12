import XCTest
@testable import ScooterCore

final class RecordBookTests: XCTestCase {
    func testFirstTimeSetsTheRecordWithoutBeatingAnything() {
        var book = RecordBook()
        XCTAssertEqual(book.submit(.zeroTo50, time: 5.2), .first)
        XCTAssertEqual(book.records[.zeroTo50], 5.2)
    }

    func testFasterTimeBeatsTheRecordAndReportsTheOldOne() {
        var book = RecordBook(records: [.zeroTo50: 5.2])
        XCTAssertEqual(book.submit(.zeroTo50, time: 4.8), .beaten(previous: 5.2))
        XCTAssertEqual(book.records[.zeroTo50], 4.8)
        // Le record suivant se mesure contre le nouveau.
        XCTAssertEqual(book.submit(.zeroTo50, time: 5.0), .notARecord)
        XCTAssertEqual(book.submit(.zeroTo50, time: 4.5), .beaten(previous: 4.8))
    }

    func testSlowerOrEqualLookingTimeIsNotARecord() {
        var book = RecordBook(records: [.fiftyTo90: 6.4])
        XCTAssertEqual(book.submit(.fiftyTo90, time: 7.0), .notARecord)
        // 6,36 s s'affiche « 6,4 s », comme le record : pas battu.
        XCTAssertEqual(book.submit(.fiftyTo90, time: 6.36), .notARecord)
        XCTAssertEqual(book.records[.fiftyTo90], 6.4)
        // 6,34 s s'affiche « 6,3 s » : battu.
        XCTAssertEqual(book.submit(.fiftyTo90, time: 6.34), .beaten(previous: 6.4))
    }

    func testIntervalsAreIndependent() {
        var book = RecordBook(records: [.zeroTo30: 2.0])
        XCTAssertEqual(book.submit(.zeroTo50, time: 9.9), .first)
        XCTAssertEqual(book.submit(.zeroTo30, time: 2.5), .notARecord)
    }

    func testInvalidTimesAreIgnored() {
        var book = RecordBook(records: [.zeroTo50: 5])
        XCTAssertEqual(book.submit(.zeroTo50, time: 0), .notARecord)
        XCTAssertEqual(book.submit(.zeroTo50, time: -1), .notARecord)
        XCTAssertEqual(book.submit(.zeroTo50, time: .nan), .notARecord)
        XCTAssertEqual(book.submit(.zeroTo80, time: .infinity), .notARecord)
        XCTAssertEqual(book.records, [.zeroTo50: 5])
    }

    func testBestOfSeveralTripsKeepsTheLowestValidTime() {
        let best = RecordBook.best(of: [
            [.zeroTo50: 5.2, .fiftyTo90: 7.0],
            [.zeroTo50: 4.9],
            [:],
            [.zeroTo50: .nan, .fiftyTo90: 6.1, .zeroTo30: 0],
        ])
        XCTAssertEqual(best, [.zeroTo50: 4.9, .fiftyTo90: 6.1])
        XCTAssertEqual(RecordBook.best(of: []), [:])
    }

    func testMergeOnlyImproves() {
        var book = RecordBook(records: [.zeroTo50: 5, .zeroTo30: 2])
        book.merge([.zeroTo50: 4, .zeroTo30: 3, .zeroTo80: 9])
        XCTAssertEqual(book.records, [.zeroTo50: 4, .zeroTo30: 2, .zeroTo80: 9])
    }
}
