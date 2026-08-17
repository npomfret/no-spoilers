import XCTest
@testable import NoSpoilersCore

/// The status check that separates "the service is down" from "the service changed".
///
/// Pure by construction — an `HTTPURLResponse` can be made by hand — which is the reason the
/// check lives on the response rather than inside each fetch, where asserting it would need a
/// stubbed `URLProtocol` this repo does not have.
final class HTTPStatusTests: XCTestCase {

    private let url = URL(string: "https://api.openf1.org/v1/sessions")!

    private func response(_ status: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
    }

    func testASuccessStatusPasses() throws {
        XCTAssertNoThrow(try response(200).requireSuccess())
        XCTAssertNoThrow(try response(204).requireSuccess(), "2xx, not just 200")
        XCTAssertNoThrow(try response(299).requireSuccess())
    }

    func testAServerErrorThrowsWithTheStatusIntact() {
        // The status is the diagnosis: 503 is "OpenF1 is down", and it must reach the log line
        // rather than being flattened into a decode failure further along.
        XCTAssertThrowsError(try response(503).requireSuccess()) { error in
            XCTAssertEqual(error as? HTTPStatusError, .unsuccessful(503))
        }
    }

    func testAClientErrorThrows() {
        // GitHub answers an unauthenticated rate limit with 403 and a JSON body that decodes to
        // nothing we recognise — which is exactly the case that used to read as "no new release".
        XCTAssertThrowsError(try response(403).requireSuccess()) { error in
            XCTAssertEqual(error as? HTTPStatusError, .unsuccessful(403))
        }
    }

    func testTheBoundariesOfTheSuccessRange() {
        XCTAssertThrowsError(try response(199).requireSuccess())
        XCTAssertThrowsError(try response(300).requireSuccess(), "a redirect is not a body we asked for")
    }

    func testANonHTTPResponseIsNotASuccess() {
        let plain = URLResponse(url: url, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
        XCTAssertThrowsError(try plain.requireSuccess()) { error in
            XCTAssertEqual(error as? HTTPStatusError, .notHTTP)
        }
    }
}
