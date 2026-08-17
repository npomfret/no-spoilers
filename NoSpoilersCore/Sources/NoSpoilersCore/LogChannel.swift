import Foundation
import os

/// Every line this app writes is a single JSON object.
///
/// ```swift
/// AppLog.widget.notice("timeline built", ["entries": 4, "reloadAt": reloadAt])
/// // {"msg":"timeline built","entries":4,"reloadAt":"2026-08-19T08:36:03Z"}
/// ```
///
/// We read these two ways: down a terminal while something is happening, and through `jq`
/// afterwards once it has already gone wrong. One line of JSON serves both. Prose with the
/// numbers baked into it serves only the first, and it is the second that finds bugs.
///
/// ```
/// xcrun simctl spawn booted log stream --level debug \
///   --predicate 'subsystem BEGINSWITH "pomocorp.NoSpoilers"'
/// log show --style ndjson --predicate 'subsystem BEGINSWITH "pomocorp.NoSpoilers"' \
///   | jq -c '{t: .timestamp, cat: .category} + (.eventMessage | fromjson)'
/// ```
///
/// Adapted from the same mechanism in `super-funmax-music`. Kept deliberately close to it so
/// that one of us reading a trace from either app is reading the same shape.
///
/// ## Why this type exists rather than `Logger` directly
///
/// It is the enforcement, not a convenience. `Logger` is `private` in here and nothing hands
/// one out, so `AppLog.schedule.notice("weekends → \(count)")` has no overload to resolve
/// against and **does not compile**. Two things follow, and are the reason not to "simplify"
/// this away:
///
/// - **`msg` is a `StaticString`.** It is `ExpressibleByStringLiteral` and deliberately *not*
///   `ExpressibleByStringInterpolation`, so a message with a value spliced into it is a
///   compile error at the call site rather than something discovered later in a log nobody
///   can parse. Widening it to `String` silently reopens every hole.
/// - **`privacy: .public` is applied here, once.** The unified log redacts interpolated
///   strings by default, so every hand-written annotation is a chance to forget one and turn
///   a trace into a column of `<private>`. Here it cannot be forgotten because it cannot be
///   written.
///
/// ## Levels — read this before choosing one
///
/// - **`.debug`** — the routine trace. High volume, derivable from the lines around it, and
///   **not written to the log store**, so it exists only while something is streaming.
/// - **`.notice`** — what a person would ask about afterwards, and the default for a state
///   change. **This is the level that survives to be read later.**
/// - **`.error`** — a failure, and only a failure.
///
/// **`.info` is not offered on purpose.** It is not written to the log store either, and the
/// widget's `cache hit` line used to be `log.info`. On 2026-08-17 two experiments were scored
/// as "the widget never reloaded" because that line had already evaporated by the time
/// `log show` asked for it — with or without `--info` — while the widget was visibly doing
/// the right thing on screen. If a state change is worth writing down, it is worth `.notice`.
///
/// ## The spoiler rule
///
/// > A line carries schedule identity and timing, and nothing else.
///
/// This is the same architectural guarantee `.claude/rules/spoiler-safety.md` makes of the
/// data model, extended to the one other way data leaves the process. The model holds no
/// results to leak, and that is exactly what must stay true: a log line is not a place to
/// start deriving finishing order, standings or outcome from timings. `LogValue` is a closed
/// enum with no `case any(Any)` so that everything reaching a trace has been through a
/// conformance somebody wrote on purpose, which is where the rule is actually applied.
public struct LogChannel: Sendable {
    private let logger: Logger

    public init(subsystem: String, category: String) {
        logger = Logger(subsystem: subsystem, category: category)
    }

    /// The routine trace. Discarded unless something is streaming, so the JSON is only built
    /// when a reader is attached — which matters at this level and not the other two, because
    /// this is the one called per entry and per boundary.
    public func debug(_ msg: StaticString, _ fields: LogFields = [:]) {
        guard logger.isEnabled(type: .debug) else { return }
        logger.debug("\(LogLine.json(msg, fields), privacy: .public)")
    }

    /// What a person would ask about afterwards. The default for a state change.
    public func notice(_ msg: StaticString, _ fields: LogFields = [:]) {
        logger.notice("\(LogLine.json(msg, fields), privacy: .public)")
    }

    /// A failure, and only a failure.
    public func error(_ msg: StaticString, _ fields: LogFields = [:]) {
        logger.error("\(LogLine.json(msg, fields), privacy: .public)")
    }
}

public typealias LogFields = KeyValuePairs<String, any LogRepresentable>

// MARK: - What a field may hold

/// A JSON value.
///
/// Deliberately closed. There is no `case any(Any)` and there should not be: the point of the
/// enum is that everything reaching a log has been through a conformance written on purpose.
public enum LogValue: Sendable {
    case text(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case list([LogValue])
    case object([LogField])
    case null
}

/// One key and its value, for the nested case.
public struct LogField: Sendable {
    let key: String
    let value: LogValue

    public init(_ key: String, _ value: LogValue) {
        self.key = key
        self.value = value
    }
}

public extension LogValue {
    /// Nested objects with the same literal syntax as a call site, so a conformance reads like
    /// the line it will produce.
    static func object(_ fields: LogFields) -> LogValue {
        .object(fields.map { LogField($0.key, $0.value.logValue) })
    }

    static func list(_ items: [any LogRepresentable]) -> LogValue {
        .list(items.map(\.logValue))
    }

    /// A caught error, spelled one way everywhere.
    ///
    /// `Error` cannot be made to conform — it is a protocol, and a retroactive conformance of
    /// one protocol to another is not a thing — so without this each call site invents its own
    /// `"\(error)"`, and the field ends up named five different things. Always under the key
    /// `"error"`, so `jq 'select(.error)'` is the whole-app failure filter.
    static func error(_ error: any Error) -> LogValue {
        .text(String(describing: error))
    }
}

/// A type that knows how to appear in a trace.
///
/// Conform a domain type here rather than picking its fields apart at a call site. That is
/// what keeps one concept spelled one way everywhere, and it is where a type gets to decide
/// what it is allowed to say about itself.
public protocol LogRepresentable {
    var logValue: LogValue { get }
}

public extension LogValue {
    var logValue: LogValue { self }
}

extension LogValue: LogRepresentable {}

extension String: LogRepresentable {
    public var logValue: LogValue { .text(self) }
}

extension Int: LogRepresentable {
    public var logValue: LogValue { .int(self) }
}

extension Double: LogRepresentable {
    public var logValue: LogValue { .double(self) }
}

extension Bool: LogRepresentable {
    public var logValue: LogValue { .bool(self) }
}

extension Date: LogRepresentable {
    /// ISO 8601 with a `Z`, which is what `ScheduleCache` writes and what the feed sends, so a
    /// date in a trace can be matched to the fixture that produced it without converting it by
    /// eye. Whole seconds: this app schedules nothing finer.
    public var logValue: LogValue { .text(formatted(.iso8601)) }
}

extension Optional: LogRepresentable where Wrapped: LogRepresentable {
    /// `null`, rather than a `?? "none"` placeholder. A reader can tell a missing value from a
    /// value that happens to read "none"; `jq` certainly can.
    public var logValue: LogValue { self?.logValue ?? .null }
}

extension Array: LogRepresentable where Element: LogRepresentable {
    public var logValue: LogValue { .list(map(\.logValue)) }
}

/// A value as short prose, for a sentence a person reads.
///
/// **Not for logging.** A log line is JSON and `LogChannel` is the only way to write one. This
/// is for the other place a value has to appear in text: an `XCTAssert` message, where
/// "expected 4 entries, got 133" is what makes a failure diagnosable and a JSON object is only
/// noise in a test report.
public extension LogRepresentable {
    var logDescription: String { LogLine.compact(logValue) }
}

// MARK: - Serialisation

/// Turns a message and its fields into one line of JSON.
///
/// Hand-rolled rather than `JSONSerialization`, which wants a `[String: Any]` and would give
/// back reordered keys, no way to keep duplicates, and no control over what happens when the
/// result is too long. All three matter here.
public enum LogLine {
    /// The cap, in UTF-8 bytes, on one serialised line.
    ///
    /// `os_log` truncates a long message, and a truncated JSON object is not JSON — one
    /// oversized dump would break `fromjson` for the whole pass. So the budget is enforced
    /// here instead, where the result can still be closed properly. 1024 sits under the
    /// platform's own limit; if a line ever needs to be longer, split it into two lines rather
    /// than raising this.
    public static let byteBudget = 1024

    /// Room to close the object and admit what was left out.
    private static let reserve = 24

    public static func json(_ msg: StaticString, _ fields: LogFields = [:]) -> String {
        var out = "{\"msg\":"
        appendText(msg.description, to: &out)

        var dropped = 0
        for (key, value) in fields {
            // `msg` is ours. A second one would be legal JSON and `jq` would take the last,
            // quietly replacing the only field a line is guaranteed to have.
            guard key != "msg" else {
                dropped += 1
                continue
            }
            var piece = ","
            appendText(key, to: &piece)
            piece += ":"
            append(value.logValue, to: &piece)

            // A field that does not fit is dropped whole. Truncating its value would be worse
            // than losing it: half a value still looks like a value.
            guard out.utf8.count + piece.utf8.count + reserve <= byteBudget else {
                dropped += 1
                continue
            }
            out += piece
        }

        if dropped > 0 {
            out += ",\"_dropped\":\(String(dropped))"
        }
        out += "}"
        return out
    }

    /// A value as short prose. Backs `logDescription`; never written to a log.
    public static func compact(_ value: LogValue) -> String {
        switch value {
        case .text(let text): return text
        case .int(let number): return String(number)
        case .double(let number): return String(number)
        case .bool(let flag): return flag ? "true" : "false"
        case .null: return "-"
        case .list(let items): return items.map(compact).joined(separator: "/")
        case .object(let fields):
            // The discriminator reads better bare, so the sentence opens with the case's name
            // rather than with "kind=".
            let lead = fields.first { $0.key == "kind" }.map { compact($0.value) }
            let rest = fields.filter { $0.key != "kind" }
                .map { "\($0.key)=\(compact($0.value))" }
            return ([lead].compactMap { $0 } + rest).joined(separator: " ")
        }
    }

    private static func append(_ value: LogValue, to out: inout String) {
        switch value {
        case .text(let text):
            appendText(text, to: &out)
        case .int(let number):
            out += String(number)
        case .double(let number):
            // JSON has no NaN and no infinity. Emitting one would produce a line no parser
            // accepts, so they go out as strings and stay visible.
            if number.isFinite {
                out += String(number)
            } else {
                appendText(number.isNaN ? "nan" : (number < 0 ? "-inf" : "inf"), to: &out)
            }
        case .bool(let flag):
            out += flag ? "true" : "false"
        case .null:
            out += "null"
        case .list(let items):
            out += "["
            for (index, item) in items.enumerated() {
                if index > 0 { out += "," }
                append(item, to: &out)
            }
            out += "]"
        case .object(let fields):
            out += "{"
            for (index, field) in fields.enumerated() {
                if index > 0 { out += "," }
                appendText(field.key, to: &out)
                out += ":"
                append(field.value, to: &out)
            }
            out += "}"
        }
    }

    private static func appendText(_ text: String, to out: inout String) {
        out += "\""
        for scalar in text.unicodeScalars {
            switch scalar {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            default:
                if scalar.value < 0x20 {
                    let hex = String(scalar.value, radix: 16)
                    out += "\\u" + String(repeating: "0", count: 4 - hex.count) + hex
                } else {
                    out.unicodeScalars.append(scalar)
                }
            }
        }
        out += "\""
    }
}
