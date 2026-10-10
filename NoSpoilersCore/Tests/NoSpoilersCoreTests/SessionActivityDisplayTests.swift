import XCTest
@testable import NoSpoilersCore

/// What a Live Activity draws once its stale date has passed.
///
/// Four combinations, all pinned, because the failure is silent in the one place it happens: a
/// Lock Screen nobody is attached to. The bug this guards against was found on a user's phone on
/// 2026-09-05 — *In Progress*, in red, an hour after the session's grace window closed — and it
/// was there because nothing read `isStale` at all.
final class SessionActivityDisplayTests: XCTestCase {

    func testUpcomingBeforeItsStartDrawsUpcoming() {
        XCTAssertEqual(SessionActivityDisplay(phase: .upcoming, isStale: false), .upcoming)
    }

    func testUpcomingPastItsStartKeepsTheScheduledStartPresentation() {
        XCTAssertEqual(SessionActivityDisplay(phase: .upcoming, isStale: true), .live)
    }

    func testLiveBeforeItsEndDrawsLive() {
        XCTAssertEqual(SessionActivityDisplay(phase: .live, isStale: false), .live)
    }

    func testLivePastItsEstimatedEndDoesNotClaimTheSessionFinished() {
        XCTAssertEqual(SessionActivityDisplay(phase: .live, isStale: true), .unconfirmed)
    }
    func testAnUnconfirmedFinishRemainsUnconfirmedInEitherStaleState() {
        XCTAssertEqual(SessionActivityDisplay(phase: .unconfirmed, isStale: false), .unconfirmed)
        XCTAssertEqual(SessionActivityDisplay(phase: .unconfirmed, isStale: true), .unconfirmed)
    }
}
