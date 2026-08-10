import XCTest
@testable import NoSpoilersCore

/// `AppVersion` itself reads `Bundle.main`, which under `swift test` is the test
/// runner rather than the app, so only the formatting is testable here. That is
/// the part with a decision in it.
final class AppVersionStringTests: XCTestCase {
    func testShowsMarketingVersionAndBuildNumber() {
        XCTAssertEqual(Strings.AppInfo.version("1.0.22", build: "13"), "v1.0.22 (13)")
    }

    /// The reason the build number is shown at all: consecutive TestFlight
    /// builds share a marketing version, so without it every build of 1.0.22
    /// renders the same string and a tester cannot say which one they have.
    func testBuildsOfTheSameVersionRenderDifferently() {
        XCTAssertNotEqual(
            Strings.AppInfo.version("1.0.22", build: "12"),
            Strings.AppInfo.version("1.0.22", build: "13")
        )
    }

    /// The two upload paths occupy separate build-number bands (task 14
    /// Decision 1), so a five-digit build is normal and must render intact.
    func testRendersAReleaseBandBuildNumber() {
        XCTAssertEqual(Strings.AppInfo.version("1.0.22", build: "10001"), "v1.0.22 (10001)")
    }
}
