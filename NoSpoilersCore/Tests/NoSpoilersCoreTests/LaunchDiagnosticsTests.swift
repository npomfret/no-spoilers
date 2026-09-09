import XCTest
@testable import NoSpoilersCore

/// The floor under the launch path.
///
/// These exist because the thing they guard is unreproducible on demand: the fault that provoked
/// them was one device refusing to register a bundled font, and the only way to have confidence in
/// the reporting is to test the reporting rather than the fault.
final class LaunchDiagnosticsTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "LaunchDiagnosticsTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    /// A first launch after install has no previous stage, and must not accuse itself of having
    /// crashed on a run that never happened.
    func testFirstEverLaunchReportsNothing() {
        let diagnostics = LaunchDiagnostics()
        diagnostics.beginLaunch(in: defaults)
        XCTAssertTrue(diagnostics.problems.isEmpty)
    }

    /// The ordinary loop: launch, reach the screen, launch again. Nothing to say either time.
    func testALaunchThatReachedTheScreenReportsNothingNextTime() {
        let first = LaunchDiagnostics()
        first.beginLaunch(in: defaults)
        first.launchShown(in: defaults)

        let second = LaunchDiagnostics()
        second.beginLaunch(in: defaults)

        XCTAssertTrue(second.problems.isEmpty)
    }

    /// The case the whole mechanism is for: a launch that wrote `starting` and never wrote
    /// `shown`, which is what a crash before the first frame leaves behind.
    func testALaunchThatNeverReachedTheScreenIsReportedOnTheNextOne() {
        let died = LaunchDiagnostics()
        died.beginLaunch(in: defaults)
        // No `launchShown`: this is the launch that did not get there.

        let next = LaunchDiagnostics()
        next.beginLaunch(in: defaults)

        XCTAssertEqual(next.problems.count, 1)
        XCTAssertEqual(next.problems.first?.id, "previous-launch-incomplete")
        XCTAssertTrue(next.problems.first?.detail.contains(LaunchStage.starting.rawValue) == true)
    }

    /// Reported once and then cleared, because the launch doing the reporting has itself written
    /// `starting` — otherwise a single crash would accuse every launch after it forever.
    func testTheReportDoesNotRepeatOnceALaunchSucceeds() {
        LaunchDiagnostics().beginLaunch(in: defaults)

        let next = LaunchDiagnostics()
        next.beginLaunch(in: defaults)
        next.launchShown(in: defaults)
        XCTAssertEqual(next.problems.count, 1)

        let third = LaunchDiagnostics()
        third.beginLaunch(in: defaults)
        XCTAssertTrue(third.problems.isEmpty)
    }

    /// `BrandTypeface.wordmark` is asked for on every canvas that draws one, and each ask would
    /// otherwise stack another copy of the same sentence under the same banner.
    func testTheSameFaultIsRecordedOnce() {
        let diagnostics = LaunchDiagnostics()
        let problem = LaunchProblem(id: "brand-typeface", summary: "s", detail: "d")
        diagnostics.record(problem)
        diagnostics.record(problem)
        diagnostics.record(LaunchProblem(id: "brand-typeface", summary: "other", detail: "other"))

        XCTAssertEqual(diagnostics.problems.count, 1)
        XCTAssertEqual(diagnostics.problems.first?.summary, "s")
    }

    /// The shared text is the point of the feature, so it has to carry the build it came from and
    /// the detail rather than the summary — the summary is the part written for the user, and the
    /// detail is the part written for whoever reads the report.
    func testTheReportCarriesTheBuildAndTheDetail() {
        let diagnostics = LaunchDiagnostics()
        diagnostics.record(LaunchProblem(id: "brand-typeface", summary: "lettering", detail: "could not register Chivo.ttf"))

        let report = diagnostics.report(version: "1.1.4", build: "10024")

        XCTAssertTrue(report.contains("v1.1.4 (10024)"))
        XCTAssertTrue(report.contains("could not register Chivo.ttf"))
    }
}
