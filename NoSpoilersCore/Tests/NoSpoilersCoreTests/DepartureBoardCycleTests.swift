import XCTest
@testable import NoSpoilersCore

final class DepartureBoardCycleTests: XCTestCase {
    private let cycle = DepartureBoardCycle(holdDuration: 5, rowInterval: 0.5)

    override func setUp() {
        super.setUp()
        executionTimeAllowance = 1
    }

    func testHoldsCountdownsThenChangesOnlyOneRowAtEachStep() {
        XCTAssertEqual(faces(at: 0), [.primary, .primary, .primary])
        XCTAssertEqual(faces(at: 4.99), [.primary, .primary, .primary])
        XCTAssertEqual(faces(at: 5), [.alternate, .primary, .primary])
        XCTAssertEqual(faces(at: 5.49), [.alternate, .primary, .primary])
        XCTAssertEqual(faces(at: 5.5), [.alternate, .alternate, .primary])
        XCTAssertEqual(faces(at: 6), [.alternate, .alternate, .alternate])
    }

    func testHoldsDatesThenReturnsToCountdownsInTheSameRowOrder() {
        XCTAssertEqual(faces(at: 6), [.alternate, .alternate, .alternate])
        XCTAssertEqual(faces(at: 10.99), [.alternate, .alternate, .alternate])
        XCTAssertEqual(faces(at: 11), [.primary, .alternate, .alternate])
        XCTAssertEqual(faces(at: 11.5), [.primary, .primary, .alternate])
        XCTAssertEqual(faces(at: 12), [.primary, .primary, .primary])
        XCTAssertEqual(faces(at: 16.99), [.primary, .primary, .primary])
        XCTAssertEqual(faces(at: 17), [.alternate, .primary, .primary])
    }

    func testSingleSessionHasBothReadableHoldsWithoutAStagger() {
        XCTAssertEqual(cycle.face(after: 4.99, rowIndex: 0, rowCount: 1), .primary)
        XCTAssertEqual(cycle.face(after: 5, rowIndex: 0, rowCount: 1), .alternate)
        XCTAssertEqual(cycle.face(after: 9.99, rowIndex: 0, rowCount: 1), .alternate)
        XCTAssertEqual(cycle.face(after: 10, rowIndex: 0, rowCount: 1), .primary)
    }

    func testClockCorrectionsAndMissedTicksDoNotRequireReplayingTransitions() {
        XCTAssertEqual(faces(at: -30), [.primary, .primary, .primary])
        XCTAssertEqual(faces(at: 1205.5), [.alternate, .alternate, .primary])
        XCTAssertEqual(faces(at: 1211.5), [.primary, .primary, .alternate])
        XCTAssertEqual(faces(at: 0), [.primary, .primary, .primary])
    }

    func testLongerScheduleFinishesItsSweepBeforeTheNextHold() {
        XCTAssertEqual(faces(at: 7, count: 6), [.alternate, .alternate, .alternate, .alternate, .alternate, .primary])
        XCTAssertEqual(faces(at: 7.5, count: 6), Array(repeating: .alternate, count: 6))
        XCTAssertEqual(faces(at: 12.49, count: 6), Array(repeating: .alternate, count: 6))
        XCTAssertEqual(faces(at: 12.5, count: 6), [.primary, .alternate, .alternate, .alternate, .alternate, .alternate])
    }

    private func faces(at elapsed: TimeInterval, count: Int = 3) -> [DepartureBoardCycle.Face] {
        (0..<count).map { cycle.face(after: elapsed, rowIndex: $0, rowCount: count) }
    }
}
