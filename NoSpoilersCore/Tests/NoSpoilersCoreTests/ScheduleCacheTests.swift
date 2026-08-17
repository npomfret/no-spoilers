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

    /// Replaces `testIsFresh`, which went with `isFresh` and `cacheTTL` on 2026-08-17 — nothing
    /// enforced the TTL and nothing should, since the widget has to draw whatever it has rather
    /// than nothing at all.
    ///
    /// `cachedAt` outlived them, and now has no reader anywhere in product code. This is the only
    /// thing standing between it and the next person removing an unused field: it is the sole
    /// record of when a cache was written, and any real freshness rule would start from it.
    func testTheEnvelopeStampsWhenItWasWritten() throws {
        let cache = ScheduleCache()
        let before = Date()
        try cache.save([], for: nil)

        let raw = try JSONSerialization.jsonObject(
            with: Data(contentsOf: try cache.cacheFileURL(for: nil))) as? [String: Any]
        let stamp = try XCTUnwrap(raw?["cachedAt"] as? String, "no cachedAt on disk: \(raw ?? [:])")
        let cachedAt = try XCTUnwrap(ISO8601DateFormatter().date(from: stamp), "not ISO 8601: \(stamp)")

        // Tolerant by a few seconds rather than strictly ordered: `.iso8601` encodes whole
        // seconds, so a stamp taken microseconds after `before` can land just behind it.
        XCTAssertEqual(cachedAt.timeIntervalSince1970,
                       before.timeIntervalSince1970, accuracy: 5)
    }
}
