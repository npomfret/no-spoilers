import XCTest
@testable import NoSpoilersCore

final class ScheduleCacheTests: XCTestCase {
    func testRoundTrip() throws {
        let weekend = RaceWeekend(
            round: 1,
            name: "Australian",
            location: "Melbourne",
            sessions: [.race: Date(timeIntervalSince1970: 1_742_000_000),
                       .qualifying: Date(timeIntervalSince1970: 1_741_900_000)]
        )
        let cache = ScheduleCache()
        // nil appGroupID → macOS caches directory (available in package tests)
        try cache.save([weekend], for: nil)
        let loaded = try cache.load(for: nil)
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].round, 1)
        XCTAssertEqual(loaded[0].name, "Australian")
        let raceTime = try XCTUnwrap(loaded[0].sessions[.race]).timeIntervalSince1970
        XCTAssertEqual(raceTime, 1_742_000_000.0, accuracy: 1)
    }

    func testIsFresh() throws {
        let cache = ScheduleCache()
        try cache.save([], for: nil)
        XCTAssertTrue(cache.isFresh(for: nil))
    }
}
