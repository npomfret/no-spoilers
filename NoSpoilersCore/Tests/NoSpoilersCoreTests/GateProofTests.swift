import XCTest
@testable import NoSpoilersCore

/// TEMPORARY — delete me.
///
/// This test fails on purpose. It exists to prove one thing that nothing else
/// can: that Xcode Cloud honours a non-zero exit from `ci_pre_xcodebuild.sh`
/// and stops the archive before a build reaches TestFlight.
///
/// Xcode Cloud does not gate delivery on its TEST action — a run with red tests
/// still uploads — so the gate lives in the pre-build hook instead. That is
/// only a claim until a red commit has actually been pushed and observed to
/// deliver nothing. See tasks/14-xcode-cloud-testflight.md, Decision 2.
///
/// If you are reading this on `main`, the revert did not land. Delete the file.
final class GateProofTests: XCTestCase {
    func testDeliberateFailureToProveTheTestFlightGate() {
        XCTFail("deliberate failure: proving the ci_pre_xcodebuild.sh gate stops delivery")
    }
}
