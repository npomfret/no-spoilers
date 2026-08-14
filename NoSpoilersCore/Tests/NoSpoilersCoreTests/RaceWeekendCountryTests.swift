import XCTest
@testable import NoSpoilersCore

/// The feed is not ours and its Grand Prix naming changes. `countryCode` has to be able to say
/// "I don't know" without that being a crash or a lie.
final class RaceWeekendCountryTests: XCTestCase {
    func testKnownGrandPrixResolvesToACountryCode() {
        XCTAssertEqual(makeWeekend(name: "Australian").countryCode, "AU")
    }

    /// Round 16 of the live 2026 feed. It matches nothing in the mapping, which used to yield `""`
    /// — and `ScheduleStore` used to `precondition` on the code being non-empty, so this weekend
    /// becoming the next session would have crashed the macOS app rather than dropped a flag.
    func testUnmappedGrandPrixNameHasNoCountryCode() {
        XCTAssertNil(makeWeekend(name: "Bahrain Grand Prix (Malaysia)").countryCode)
    }

    func testUnrecognisedNameHasNoCountryCode() {
        XCTAssertNil(makeWeekend(name: "Some Grand Prix The Feed Invented").countryCode)
    }

    private func makeWeekend(name: String) -> RaceWeekend {
        RaceWeekend(
            round: 1,
            name: name,
            location: "Somewhere",
            sessions: [.race: Date(timeIntervalSince1970: 1_000_000)]
        )
    }
}
