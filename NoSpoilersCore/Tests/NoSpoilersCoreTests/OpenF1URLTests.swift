import XCTest
@testable import NoSpoilersCore

/// The two OpenF1 URLs, pinned character for character.
///
/// A wrong URL here does not fail — OpenF1 answers a malformed query exactly as it answers an
/// empty one, and the poller answers both by coming back in two minutes. No amount of logging
/// separates those, so the separation has to happen at build time. This file is that.
///
/// It is not hypothetical. Until 2026-08-17 `session_name` went out double-encoded, because
/// `URL(string:)` re-encodes an already-encoded string when the rest of it is not a valid URL —
/// and the bare `>` in OpenF1's filter syntax made it not valid. Every multi-word name was sent
/// as `Practice%25201`, so **session-end confirmation had never worked for FP1, FP2, FP3 or
/// Sprint Qualifying**, silently, for as long as the feature had existed.
final class OpenF1URLTests: XCTestCase {

    /// 2026-08-17T13:00:00Z. Mid-year on purpose: `sessionsURL` takes the year from
    /// `Calendar.current`, so a fixture near a year boundary would assert differently depending
    /// on where the machine running it is.
    private let startsAt = Date(timeIntervalSince1970: 1_786_971_600)

    private func session(_ kind: SessionKind) -> Session {
        Session(round: 14, grandPrixName: "Belgian Grand Prix",
                location: "Spa-Francorchamps", kind: kind, startsAt: startsAt)
    }

    func testTheSessionLookupWindowIsFifteenMinutesEitherSideOfTheScheduledStart() throws {
        let url = try OpenF1Client.sessionsURL(for: session(.race))

        XCTAssertEqual(url.absoluteString,
                       "https://api.openf1.org/v1/sessions"
                       + "?year=2026"
                       + "&session_name=Race"
                       + "&date_start%3E=2026-08-17T12:45:00Z"
                       + "&date_start%3C=2026-08-17T13:15:00Z")
    }

    func testAMultiWordSessionNameIsEncodedExactlyOnce() throws {
        // The regression. `%2520` is a request for a session literally named "Sprint%20Qualifying",
        // which OpenF1 has never had and never will.
        let url = try OpenF1Client.sessionsURL(for: session(.sprintQualifying))

        XCTAssertTrue(url.absoluteString.contains("&session_name=Sprint%20Qualifying"),
                      "unexpected: \(url.absoluteString)")
        XCTAssertFalse(url.absoluteString.contains("%25"), "double-encoded: \(url.absoluteString)")
    }

    func testEveryKindOfSessionCanBeAskedForByItsOpenF1Name() throws {
        for kind in SessionKind.allCases {
            let url = try OpenF1Client.sessionsURL(for: session(kind))
            let expected = kind.openF1SessionName.replacingOccurrences(of: " ", with: "%20")

            XCTAssertTrue(url.absoluteString.contains("&session_name=\(expected)&"),
                          "\(kind.rawValue): \(url.absoluteString)")
        }
    }

    func testAURLFoundationWouldRewriteIsRefusedRatherThanSent() {
        // The exact string the old code built, and the reason the bug was invisible: Foundation
        // accepts it and quietly returns something else. Since the builders above can no longer
        // produce one, the guard is asserted directly.
        let rewritten = "https://api.openf1.org/v1/sessions"
            + "?session_name=Sprint%20Qualifying"
            + "&date_start>=2026-08-17T12:45:00Z"

        XCTAssertNotNil(URL(string: rewritten), "precondition: Foundation accepts it — that is the trap")
        XCTAssertThrowsError(try OpenF1Client.url(rewritten)) { error in
            XCTAssertEqual(error as? OpenF1Error, .malformedURL(rewritten))
        }
    }

    func testAnAlreadyEncodedURLPassesThroughUntouched() throws {
        let clean = "https://api.openf1.org/v1/sessions?session_name=Sprint%20Qualifying"

        XCTAssertEqual(try OpenF1Client.url(clean).absoluteString, clean)
    }

    func testTheEndConfirmationAsksOnlyForTheSessionFinishedRecord() throws {
        let url = try OpenF1Client.sessionFinishedURL(forSessionKey: 9999)

        XCTAssertEqual(url.absoluteString,
                       "https://api.openf1.org/v1/race_control"
                       + "?session_key=9999"
                       + "&category=SessionStatus"
                       + "&message=SESSION%20FINISHED")
    }
}
