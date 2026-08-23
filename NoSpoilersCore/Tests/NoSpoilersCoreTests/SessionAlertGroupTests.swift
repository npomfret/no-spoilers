import XCTest
@testable import NoSpoilersCore

/// The three switches the alert settings offer, and what each one turns on.
///
/// The grouping changed how the preference is expressed. It was not meant to change what anybody
/// is told about, and the last test here is the only thing that says so.
final class SessionAlertGroupTests: XCTestCase {

    func testEverySessionKindBelongsToExactlyOneGroup() {
        let covered = SessionAlertGroup.allCases.flatMap { Array($0.kinds) }
        XCTAssertEqual(Set(covered), Set(SessionKind.allCases),
                       "a session kind no group covers is one no setting can reach")
        XCTAssertEqual(covered.count, SessionKind.allCases.count,
                       "a kind in two groups makes one switch silently undo the other")
    }

    func testTheGroupsAreTheOnesAskedFor() {
        XCTAssertEqual(SessionAlertGroup.practice.kinds,
                       [.freePractice1, .freePractice2, .freePractice3])
        // Sprint Qualifying is qualifying, and the Sprint is a race. Neither is guessable from
        // the group's name, which is why the row prints its `summary` underneath.
        XCTAssertEqual(SessionAlertGroup.qualifying.kinds, [.qualifying, .sprintQualifying])
        XCTAssertEqual(SessionAlertGroup.races.kinds, [.sprint, .race])
    }

    func testExpandingGroupsUnionsTheirKinds() {
        XCTAssertEqual(SessionAlertGroup.kinds(in: []), [])
        XCTAssertEqual(SessionAlertGroup.kinds(in: [.races]), [.sprint, .race])
        XCTAssertEqual(SessionAlertGroup.kinds(in: Set(SessionAlertGroup.allCases)),
                       Set(SessionKind.allCases))
    }

    func testASummaryNamesEverySessionInTheGroupInWeekendOrder() {
        XCTAssertEqual(SessionAlertGroup.practice.summary,
                       "Free Practice 1, Free Practice 2, Free Practice 3")
        XCTAssertEqual(SessionAlertGroup.qualifying.summary, "Sprint Qualifying, Qualifying")
        XCTAssertEqual(SessionAlertGroup.races.summary, "Sprint, Race")
    }

    /// **The regression this file exists for.** `SessionAlertDefaults.groups` is
    /// `[.qualifying, .races]`, and it has to mean what the per-kind default meant before the
    /// grouping: practice out, everything else in. The default lives in the iOS target and cannot
    /// be imported here, so what is pinned is the expansion it relies on.
    func testTheDefaultGroupsExpandToTheKindsTheDefaultUsedToName() {
        XCTAssertEqual(
            SessionAlertGroup.kinds(in: [.qualifying, .races]),
            [.qualifying, .sprintQualifying, .sprint, .race]
        )
    }

    func testWeekendOrderIsATotalOrdering() {
        let orders = SessionKind.allCases.map(\.sortOrder)
        XCTAssertEqual(Set(orders).count, orders.count, "two kinds share a position in the weekend")
    }
}
