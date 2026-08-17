import XCTest
@testable import NoSpoilersCore

/// Every line this app writes has to survive `jq`. These assert the two things that can break
/// that and are invisible until a trace is being read under pressure: the line must always be
/// parseable JSON, and it must always carry `msg`.
final class LogChannelTests: XCTestCase {

    /// Parse a line the way a reader actually does, and fail with the line itself if it will
    /// not go through — a broken line is unreadable in an assertion message otherwise.
    private func parse(_ line: String, file: StaticString = #filePath, line number: UInt = #line) -> [String: Any] {
        guard let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            XCTFail("not JSON: \(line)", file: file, line: number)
            return [:]
        }
        return object
    }

    func testLineIsOneJSONObjectCarryingItsMessage() {
        let line = LogLine.json("timeline built", ["entries": 4, "truncated": false])

        XCTAssertFalse(line.contains("\n"), "a log line must be one line: \(line)")
        let parsed = parse(line)
        XCTAssertEqual(parsed["msg"] as? String, "timeline built")
        XCTAssertEqual(parsed["entries"] as? Int, 4)
        XCTAssertEqual(parsed["truncated"] as? Bool, false)
    }

    func testFieldNamedMsgIsDroppedRatherThanShadowingTheMessage() {
        // Two `msg` keys is legal JSON and `jq` takes the last, which would quietly replace the
        // one field every line is guaranteed to have.
        let line = LogLine.json("real message", ["msg": "impostor", "keep": 1])

        let parsed = parse(line)
        XCTAssertEqual(parsed["msg"] as? String, "real message")
        XCTAssertEqual(parsed["keep"] as? Int, 1)
        XCTAssertEqual(parsed["_dropped"] as? Int, 1)
    }

    func testOversizedFieldIsDroppedWholeAndTheLineStillParses() {
        // `os_log` truncates a long message, and half a JSON object is not JSON — one oversized
        // field would otherwise break `fromjson` for the whole pass.
        let line = LogLine.json("big", ["huge": String(repeating: "x", count: 4096), "small": 7])

        XCTAssertLessThanOrEqual(line.utf8.count, LogLine.byteBudget)
        let parsed = parse(line)
        XCTAssertEqual(parsed["msg"] as? String, "big")
        XCTAssertEqual(parsed["small"] as? Int, 7, "a later small field must still fit")
        XCTAssertNil(parsed["huge"], "an oversized value is dropped whole, never truncated")
        XCTAssertEqual(parsed["_dropped"] as? Int, 1)
    }

    func testQuotesNewlinesAndControlCharactersAreEscaped() {
        let nasty = "say \"hi\"\nline\ttwo\\end\u{0007}"
        let parsed = parse(LogLine.json("escaping", ["text": nasty]))
        XCTAssertEqual(parsed["text"] as? String, nasty)
    }

    func testNonFiniteNumbersGoOutAsStringsRatherThanBreakingTheLine() {
        // JSON has no NaN and no infinity; emitting one produces a line no parser accepts.
        let parsed = parse(LogLine.json("numbers", ["nan": Double.nan, "inf": Double.infinity]))
        XCTAssertEqual(parsed["nan"] as? String, "nan")
        XCTAssertEqual(parsed["inf"] as? String, "inf")
    }

    func testMissingValueIsNullRatherThanAPlaceholderWord() {
        // A reader can tell null from a value that happens to read "none".
        let absent: Int? = nil
        let parsed = parse(LogLine.json("optional", ["gone": absent, "here": Int?(3)]))
        XCTAssertTrue(parsed["gone"] is NSNull)
        XCTAssertEqual(parsed["here"] as? Int, 3)
    }

    func testDatesAreISO8601SoTheyMatchTheFeedAndTheCache() {
        let date = Date(timeIntervalSince1970: 1_786_955_763)
        let parsed = parse(LogLine.json("when", ["at": date]))
        XCTAssertEqual(parsed["at"] as? String, "2026-08-17T08:36:03Z")
    }

    // MARK: - The vocabulary rule

    func testSessionKindLogsTheFeedsKeyNotItsDisplayName() {
        // A trace has to match the fixture that produced it, and be readable beside one taken
        // on a device in another language. `displayName` is localized; `rawValue` is the feed.
        XCTAssertEqual(LogLine.compact(SessionKind.race.logValue), "gp")
        XCTAssertEqual(LogLine.compact(SessionKind.freePractice1.logValue), "fp1")
    }

    func testWeekendLogsRoundShortNameAndSessionCountAndNothingElse() {
        let weekend = RaceWeekend(
            round: 14,
            name: "Belgian",
            location: "Spa-Francorchamps",
            sessions: [.freePractice1: Date(timeIntervalSince1970: 0),
                       .race: Date(timeIntervalSince1970: 3600)]
        )
        let parsed = parse(LogLine.json("weekend", ["w": weekend]))
        let fields = parsed["w"] as? [String: Any] ?? [:]

        XCTAssertEqual(fields["round"] as? Int, 14)
        XCTAssertEqual(fields["name"] as? String, "Belgian")
        XCTAssertEqual(fields["sessions"] as? Int, 2)
        // Pinned deliberately: a weekend rides along in lines that are about something else, so
        // widening it widens every one of them against the byte budget. A line that is about
        // the sessions logs them itself.
        XCTAssertEqual(Set(fields.keys), ["round", "name", "sessions"])
    }

    func testSessionLogsTheJoinKeyItsKindAndItsStart() {
        let session = Session(round: 14, grandPrixName: "Belgian Grand Prix",
                              location: "Spa-Francorchamps", kind: .race,
                              startsAt: Date(timeIntervalSince1970: 1_786_955_763))
        let parsed = parse(LogLine.json("session", ["s": session]))
        let fields = parsed["s"] as? [String: Any] ?? [:]

        // `id` is what SessionEndConfirmer stores confirmed end times under, so a session in a
        // trace can be matched to a stored confirmation without a translation step.
        XCTAssertEqual(fields["id"] as? String, "14-gp")
        XCTAssertEqual(fields["kind"] as? String, "gp")
        XCTAssertEqual(fields["startsAt"] as? String, "2026-08-17T08:36:03Z")
    }
}
