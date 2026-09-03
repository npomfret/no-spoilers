import XCTest
@testable import NoSpoilersCore

final class InstalledBuildTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "InstalledBuildTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    /// The first launch after install has no record, and reads as changed rather than as a
    /// third state.
    func testFirstLaunchIsAChange() {
        XCTAssertTrue(InstalledBuild.changed(to: "10013", in: defaults))
    }

    /// The reason this exists: a launch on a build the app has not run before must say so,
    /// exactly once.
    func testNewBuildIsAChangeOnceThenSettles() {
        XCTAssertTrue(InstalledBuild.changed(to: "10012", in: defaults))
        XCTAssertTrue(InstalledBuild.changed(to: "10013", in: defaults))
        XCTAssertFalse(InstalledBuild.changed(to: "10013", in: defaults))
        XCTAssertFalse(InstalledBuild.changed(to: "10013", in: defaults))
    }

    /// The other direction: relaunching the same build must not read as a change, or every
    /// launch would spend a reload on nothing.
    func testSameBuildIsNotAChange() {
        _ = InstalledBuild.changed(to: "10013", in: defaults)
        XCTAssertFalse(InstalledBuild.changed(to: "10013", in: defaults))
        XCTAssertEqual(defaults.string(forKey: InstalledBuild.recordedBuildKey), "10013")
    }
}
