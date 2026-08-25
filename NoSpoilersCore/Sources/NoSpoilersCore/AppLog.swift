import Foundation

/// What the app did, and what it did it to, in the order it happened.
///
/// Every line is a JSON object. See `LogChannel` for the mechanism, what it refuses to let you
/// write, and how to choose a level.
///
/// The channels live here rather than in each target because all three — iOS app, macOS
/// menu-bar app, WidgetKit extension — run the same shared schedule code and a trace is only
/// useful if one predicate reaches all of it. The *process* already distinguishes them in the
/// log, so the subsystem does not need to.
///
/// Read everything this app writes, live:
///
/// ```
/// log stream --level debug --predicate 'subsystem BEGINSWITH "pomocorp.NoSpoilers"'
/// xcrun simctl spawn booted log stream --level debug \
///   --predicate 'subsystem BEGINSWITH "pomocorp.NoSpoilers"'
/// ```
///
/// Afterwards, which is the case that matters, since a widget is not attached to anything when
/// it goes wrong:
///
/// ```
/// log show --style ndjson --last 30m --predicate 'subsystem BEGINSWITH "pomocorp.NoSpoilers"' \
///   | jq -c '{t: .timestamp, cat: .category} + (.eventMessage | fromjson)'
/// ```
///
/// **`.debug` lines are not in that second one.** They are not written to the store. Anything
/// that has to survive to be read later is `.notice` — see the note on `LogChannel` about the
/// morning that rule cost.
///
/// ## What a line may carry
///
/// > A line carries schedule identity and timing, and nothing else.
///
/// The domain has no results in it to leak, and this is one of the places that has to stay
/// true. Conform a type below rather than assembling fields at a call site.
///
/// **Names and kinds go out in the feed's vocabulary, not the user's language.** A weekend
/// logs `name` — the feed's short form, "Belgian" — and never `grandPrixName`, which is a
/// localized string; a session logs `kind.rawValue`, the feed's `"gp"`, and never
/// `displayName`. A trace has to match the fixture and the feed that produced it, and one
/// taken on a French device must be readable beside one taken here.
public enum AppLog {
    public static let subsystem = "pomocorp.NoSpoilers"

    /// One line per process, naming the build that wrote everything after it.
    ///
    /// Its own category because it is the only thing in a trace that is not about the
    /// schedule: it is the boundary between runs. A collected archive holds several launches
    /// of three different processes, and reading one means finding where the thing you care
    /// about last started — `--category launch` is that index, and it answers the question
    /// every bug report needs answering first, which is *which build*.
    public static let launch = LogChannel(subsystem: subsystem, category: "launch")

    /// Going to the network for the schedule, and what came back.
    public static let schedule = LogChannel(subsystem: subsystem, category: "schedule")

    /// The App Group cache: what was read, what was written, and what failed.
    ///
    /// Its own category rather than lines inside `schedule`, because the question it answers
    /// is asked in isolation — "the widget is showing last week" — and answering it means
    /// reading cache reads and writes in sequence with nothing between them. The widget reads
    /// this container and the app writes it, from two processes, which is exactly the kind of
    /// thing a single interleaved category is for.
    public static let cache = LogChannel(subsystem: subsystem, category: "cache")

    /// `ScheduleStore`: a refresh asked for, a change detected, a widget reload requested.
    public static let store = LogChannel(subsystem: subsystem, category: "store")

    /// The WidgetKit timeline: what was built, how far ahead, and when the widget asked to be
    /// woken again.
    ///
    /// **Every timeline decision is in this category**, which is a rule rather than a
    /// description of where the lines happen to be. A widget showing stale content is the
    /// hardest thing in this product to diagnose — nothing is attached, the app is not
    /// running, and the failure looks identical to "nothing happened". The entry count, the
    /// horizon, whether the cap truncated, and the reload date it settled on are the four
    /// facts that make that diagnosable, and carrying all four is what this channel is for.
    public static let widget = LogChannel(subsystem: subsystem, category: "widget")

    /// Confirmed session end times from OpenF1 — asked for, stored, or refused.
    public static let sessionEnd = LogChannel(subsystem: subsystem, category: "session-end")

    /// Local notifications: what was planned, what the OS accepted, and whether it was allowed
    /// to at all.
    ///
    /// Written only by the iOS target, and declared here with the others for the reason `update`
    /// is. It needs a channel for the same reason `widget` does: **an alert that never arrives is
    /// indistinguishable from a weekend where nothing happened.** Nobody reports a notification
    /// they did not get, so the count planned, the count pending and the authorization state are
    /// the only evidence that the feature is working at all.
    public static let alerts = LogChannel(subsystem: subsystem, category: "alerts")

    /// The Live Activity: what the planner decided, and what ActivityKit did about it.
    ///
    /// Written only by the iOS target, and needed for a sharper version of the reason `alerts` is.
    /// **An activity is started from the foreground and then lives on a Lock Screen the app cannot
    /// read back.** Nothing observes whether it appeared, stayed, or was quietly ended by the
    /// system when its 8 hours ran out, so the decision to start one and ActivityKit's answer are
    /// the only evidence there will ever be.
    public static let activity = LogChannel(subsystem: subsystem, category: "activity")

    /// Siri, Spotlight and the Shortcuts app asking what is on next.
    ///
    /// Written only by the iOS target. The reason it needs a channel is the same one the widget
    /// has: **an intent runs in a process the system starts and kills**, with nothing attached and
    /// no screen to leave a mark on. If the answer is wrong, or the schedule read comes back
    /// empty, this line is the only place it will ever be visible.
    public static let intents = LogChannel(subsystem: subsystem, category: "intents")

    /// The menu-bar app asking GitHub whether there is a newer release.
    ///
    /// Written only by the macOS target, and still declared here with the others: a second
    /// `LogChannel` built inside an app target is the drift this type exists to prevent, and one
    /// predicate has to reach everything the product writes.
    ///
    /// It needs a channel at all because the outcome is otherwise invisible. "You are up to date"
    /// and "this app has not successfully checked in three months" both render as nothing in the
    /// menu bar, and the second is how a Homebrew user stays on an old build indefinitely.
    public static let update = LogChannel(subsystem: subsystem, category: "update")

    /// One line, at the top of a process, naming the build that wrote everything after it.
    ///
    /// Called from all three entry points rather than from a shared initialiser, because there
    /// is no shared initialiser: the widget extension, the iOS app and the menu-bar app are
    /// three processes that start independently and each carry their own `Info.plist`. The
    /// `process` field is what tells their interleaved lines apart in one archive — the OS
    /// records a process name too, but it is the executable's, which for the extension is a
    /// mouthful and for the two apps is nearly the same word.
    ///
    /// `AppVersion` crashes on a bundle with no version keys, deliberately. That is a misbuilt
    /// bundle rather than a runtime condition, and this is a good place to find out.
    public static func launched(process: String) {
        launch.notice("launched", [
            "process": process,
            "version": AppVersion.marketing,
            "build": AppVersion.build,
        ])
    }
}

// MARK: - Domain conformances

extension SessionKind: LogRepresentable {
    /// The feed's own key — `"gp"`, not "Race" and not "Grand Prix". See the note on `AppLog`.
    public var logValue: LogValue { .text(rawValue) }
}

extension SessionStatus: LogRepresentable {
    public var logValue: LogValue {
        switch self {
        case .upcoming:   return .text("upcoming")
        case .inProgress: return .text("inProgress")
        case .finished:   return .text("finished")
        }
    }
}

extension Session: LogRepresentable {
    /// Which session, and when it starts. `id` is `round-kind`, which is the same join key
    /// `SessionEndConfirmer` stores its confirmed end times under, so a session in a trace can
    /// be matched to a stored confirmation without a translation step.
    public var logValue: LogValue {
        .object(["id": id, "kind": kind, "startsAt": startsAt])
    }
}

extension RaceWeekend: LogRepresentable {
    /// Round, the feed's short name, and how many sessions it has. Not the session times: a
    /// weekend appears in lines that are about something else, and five dates each would push
    /// every one of them against the byte budget. A line that is *about* the sessions logs
    /// them itself.
    public var logValue: LogValue {
        .object(["round": round, "name": name, "sessions": sessions.count])
    }
}
