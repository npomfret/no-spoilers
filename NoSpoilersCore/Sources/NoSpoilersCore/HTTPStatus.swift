import Foundation

/// A JSON request that came back as something other than a success.
///
/// Deliberately not an "unknown" case. Every value here is a fact the server or the platform
/// stated, and a caught error goes out under `LogValue.error(_:)` where the status is the whole
/// diagnosis: `unsuccessful(503)` is "they are down", `unsuccessful(403)` on GitHub is "rate
/// limited", and a `DecodingError` beside them is "the schema changed".
public enum HTTPStatusError: Error, Equatable {
    /// Not an HTTP response at all. Every URL in this app is `https`, so a real server cannot
    /// produce this — but a stub or a redirected scheme can, and passing it off as a success
    /// would put an arbitrary body through a JSON decoder.
    case notHTTP

    /// A status outside 2xx. The body is the server's error page, not the JSON we asked for.
    case unsuccessful(Int)
}

public extension URLResponse {
    /// Throws unless this is an HTTP response carrying a 2xx status.
    ///
    /// Every JSON fetch in this app used to go straight from `URLSession.data(from:)` to a
    /// `JSONDecoder`, discarding the response entirely — so **a 503 and a schema change were the
    /// same failure**, and in `OpenF1Client` both were the same `nil` as "no record published
    /// yet". Checking the status first is what separates "the service is down" from "the service
    /// changed" from "the service has nothing for us yet", and those three want three different
    /// reactions from whoever reads the trace.
    ///
    /// Call it immediately after the request and before the decode, at every site that decodes a
    /// response body.
    func requireSuccess() throws {
        guard let http = self as? HTTPURLResponse else { throw HTTPStatusError.notHTTP }
        guard (200..<300).contains(http.statusCode) else {
            throw HTTPStatusError.unsuccessful(http.statusCode)
        }
    }
}
