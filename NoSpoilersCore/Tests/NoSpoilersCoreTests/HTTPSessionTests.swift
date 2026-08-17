import XCTest
@testable import NoSpoilersCore

/// The timeout policy is a decision, and this is the only place it is executable.
///
/// Nothing else can see it: no test makes a real request, and the difference between an 8-second
/// bound and Apple's 60 shows up only on a network that is failing. Without these assertions the
/// numbers are a comment, and the way this drifted the first time was by omission — two call sites
/// that simply never said anything.
final class HTTPSessionTests: XCTestCase {

    func testTheTimeoutsAreTheOnesWrittenDown() {
        let configuration = HTTPSession.shared.configuration
        // 8s of silence, not 8s for the whole request: `timeoutIntervalForRequest` is an idle
        // timeout and resets each time data arrives. `timeoutIntervalForResource` is the total.
        XCTAssertEqual(configuration.timeoutIntervalForRequest, 8)
        XCTAssertEqual(configuration.timeoutIntervalForResource, 20)
    }

    /// Stated as "tighter than the default" rather than against 60 and 604800, so that Apple
    /// moving its defaults reads as what it is — irrelevant — instead of as a failure here.
    func testTheBoundsAreTighterThanTheOnesWeWouldHaveInherited() {
        let ours = HTTPSession.shared.configuration
        let theirs = URLSession.shared.configuration
        XCTAssertLessThan(ours.timeoutIntervalForRequest, theirs.timeoutIntervalForRequest)
        XCTAssertLessThan(ours.timeoutIntervalForResource, theirs.timeoutIntervalForResource)
    }

    /// Ephemeral because `ScheduleFetcher` runs in the widget extension, where Apple advises
    /// against `.shared`. A zero disk capacity is the observable half of that: `ScheduleCache` is
    /// the caching layer, and a cached "no release yet" or "record not published yet" would be
    /// exactly the wrong answer for the other two callers.
    func testNothingFetchedIsWrittenToADiskCache() throws {
        let cache = try XCTUnwrap(HTTPSession.shared.configuration.urlCache)
        XCTAssertEqual(cache.diskCapacity, 0)
    }

    func testEverySiteGetsTheSameSession() {
        XCTAssertTrue(HTTPSession.shared === HTTPSession.shared,
                      "a computed property here would build a session per request")
        XCTAssertFalse(HTTPSession.shared === URLSession.shared)
    }
}
