import Foundation

/// Something that went wrong before the app could draw its own screen, in words a user can send on.
///
/// **This type exists because a launch crash is the one bug that reports nothing.** A user who
/// taps the icon and lands back on the Home Screen has no screen to read, no log to reach, and
/// nothing to describe beyond "it doesn't work"; the `.ips` in Settings is the only record, and
/// asking a stranger to find it is most of the way to not finding out at all. A fault that puts
/// its own reason on screen is one they can screenshot.
public struct LaunchProblem: Identifiable, Equatable, Sendable {
    /// Stable per fault, so the same failure recorded twice is one entry rather than two. The
    /// wordmark asks for its font on every canvas that draws one, and each ask would otherwise
    /// stack another copy of the same sentence.
    public let id: String

    /// One line, and the only part the banner shows.
    public let summary: String

    /// Everything worth having in a bug report: what was asked for, what came back, and where.
    public let detail: String

    public init(id: String, summary: String, detail: String) {
        self.id = id
        self.summary = summary
        self.detail = detail
    }
}

/// How far a launch got, recorded so the *next* one can say where the last one stopped.
///
/// Two values rather than a finer ladder: the question this answers is "did the app reach the
/// point of showing something", and a stage between those two is a stage nobody could act on.
public enum LaunchStage: String, Sendable {
    /// The process started. Written before anything that could fail.
    case starting
    /// A frame reached the screen. Written once, from the first `onAppear`.
    case shown
}

/// What this launch could not do, and how the last one ended.
///
/// **Nothing here should ever have anything to say.** It is the floor under the launch path, not
/// a feature: an empty `problems` is the normal state and draws nothing at all.
///
/// **Why a recorder and not a `precondition`.** Trapping is the right instinct in development and
/// the wrong one in the App Store. A `preconditionFailure` in a shipped build is a silent
/// disappearance — the user learns nothing, we learn nothing, and the app they paid for does not
/// run — whereas the same fault reported on screen leaves them a working app and us a sentence to
/// act on. So the traps stay under `#if DEBUG`, where they still stop a developer dead, and
/// release builds route the identical message here. This is *louder* than the crash was, not
/// quieter: the failure it was guarding against was one nobody could see.
///
/// Not an actor, and lock-protected instead, because the things that report to it are `static let`
/// initialisers that run wherever they are first touched — a SwiftUI body on the main actor in the
/// app, a timeline provider on some other thread in the widget — and none of them can `await`.
public final class LaunchDiagnostics: ObservableObject, @unchecked Sendable {

    /// The one instance. Callers are static initialisers with nowhere to be injected from; the
    /// tests reach the type's logic through `beginLaunch(in:)`, which takes its storage.
    public static let shared = LaunchDiagnostics()

    /// Where the last launch's stage is kept. Each app's own `UserDefaults.standard`, as with
    /// `InstalledBuild.recordedBuildKey`: the question is about *this* process's last run and is
    /// not a thing to share through the App Group.
    public static let stageKey = "launch.stage"

    private let lock = NSLock()
    private var stored: [LaunchProblem] = []

    public init() {}

    /// What this launch could not do. Empty on every ordinary run.
    public var problems: [LaunchProblem] {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }

    /// Records a fault, once per `id`.
    ///
    /// Logged as well as stored, because the two readers are different people: the banner is for
    /// the user in front of the phone, and `AppLog.launch` is for whoever reads the archive
    /// afterwards. `.error` rather than `.notice` — this is a failure and only ever a failure.
    public func record(_ problem: LaunchProblem) {
        lock.lock()
        let isNew = !stored.contains { $0.id == problem.id }
        if isNew { stored.append(problem) }
        lock.unlock()

        guard isNew else { return }
        AppLog.launch.error("launch problem", [
            "id": problem.id,
            "detail": problem.detail,
        ])
        notifyObservers()
    }

    /// Reads how the previous launch ended, then marks this one as started.
    ///
    /// **The order matters and is the whole mechanism.** Every launch writes `starting` here and
    /// only a launch that reaches the screen overwrites it with `shown`, so finding `starting` on
    /// the way in means the run before this one died before drawing anything. Called from the app's
    /// entry point, before the work that could be what died.
    ///
    /// It cannot help a fault that kills *every* launch — the report would need a launch that
    /// survives to show it — which is exactly why the known traps on this path were removed rather
    /// than merely instrumented. This is the net under the next unknown one.
    ///
    /// A user who force-quits inside the first frame leaves the same trace as a crash. That is why
    /// the wording says what was observed, "did not reach the schedule screen", and does not claim
    /// a crash.
    public func beginLaunch(in defaults: UserDefaults = .standard) {
        let previous = defaults.string(forKey: Self.stageKey)
        defaults.set(LaunchStage.starting.rawValue, forKey: Self.stageKey)

        guard let previous, previous != LaunchStage.shown.rawValue else { return }
        record(LaunchProblem(
            id: "previous-launch-incomplete",
            summary: Strings.Diagnostics.previousLaunchSummary,
            detail: Strings.Diagnostics.previousLaunchDetail(stage: previous)
        ))
    }

    /// Marks this launch as having reached the screen. Idempotent; the first frame is the one that
    /// counts and the rest cost a `UserDefaults` write that changes nothing.
    public func launchShown(in defaults: UserDefaults = .standard) {
        defaults.set(LaunchStage.shown.rawValue, forKey: Self.stageKey)
    }

    /// Everything recorded so far as one block of text, for the share sheet.
    public func report(version: String, build: String) -> String {
        let header = "No Spoilers \(Strings.AppInfo.version(version, build: build))"
        return ([header] + problems.map { "\n\($0.summary)\n\($0.detail)" }).joined(separator: "\n")
    }

    /// `objectWillChange` has to reach the main actor, and asynchronously.
    ///
    /// The recorders are `static let` initialisers, and the first thing to touch one is usually a
    /// SwiftUI body — so a synchronous send would be publishing a change from inside the view
    /// update that provoked it. Hopping to the next turn of the main run loop is what keeps the
    /// banner an ordinary state change rather than a re-entrant one.
    private func notifyObservers() {
        Task { @MainActor [weak self] in
            self?.objectWillChange.send()
        }
    }
}
