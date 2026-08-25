import AppIntents
import NoSpoilersCore

/// "When is the next session?" — from Siri, Spotlight, the Shortcuts app and the Action button.
///
/// **The point of this is that a web page cannot be asked.** The app answers without being opened,
/// in a process the system starts, from a schedule it already holds — which is also why it works
/// with no network.
///
/// It decides nothing of its own. `FeaturedSessionPlanner` is the same function the Live Activity
/// uses, so the sentence spoken here and the countdown on the Lock Screen cannot disagree, and
/// `ScheduleSnapshotLoader` is the same read the widget does when it wakes up cold — which is
/// exactly this intent's situation.
struct NextSessionIntent: AppIntent {
    // MARK: Metadata
    //
    // **Literals, and they have to be.** `appintentsmetadataprocessor` extracts these at build
    // time and fails the build on a reference to a property — "'LocalizedStringResource' must be
    // initialised with a call to its initializer or a string literal". So the four strings the
    // system reads at *install* time live here rather than in `Strings.swift`, which is where the
    // rest of this app's copy lives and where a note points back at this block. The strings the
    // intent speaks at *run* time are not extracted and are in `Strings.Intents` with everything
    // else.

    static var title: LocalizedStringResource = "Next session"
    static var description = IntentDescription(
        "Says which session is on next and when it starts. Never a result."
    )

    /// Answered in place. Opening the app to show a countdown would make this slower than looking,
    /// which is the opposite of what asking is for.
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let snapshot = await ScheduleSnapshotLoader.load()

        // No look-ahead. The Live Activity has 8 hours of budget and cannot show a session further
        // out than that; someone asking the question in February still wants the date.
        let featured = FeaturedSessionPlanner.plan(
            at: Date(),
            weekends: snapshot.weekends,
            confirmedEndDates: snapshot.confirmedEndDates,
            lookAhead: .infinity
        )

        guard let featured else {
            // Covers both the off-season and a phone that has never had a schedule. The two are
            // not distinguished on purpose: from here they are the same answer, and guessing which
            // one it is would mean claiming the season is over when the truth is a failed fetch.
            AppLog.intents.notice("answered with nothing scheduled",
                                  ["weekends": snapshot.weekends.count])
            return .result(dialog: IntentDialog(stringLiteral: Strings.Intents.nothingScheduled))
        }

        AppLog.intents.notice("answered", [
            "session": featured.session.id,
            "phase": String(describing: featured.phase),
        ])

        switch featured.phase {
        case .live:
            return .result(dialog: IntentDialog(stringLiteral: Strings.Intents.inProgress(
                session: featured.session.kind.displayName,
                grandPrix: featured.session.grandPrixName
            )))
        case .upcoming:
            return .result(dialog: IntentDialog(stringLiteral: Strings.Intents.startsAt(
                session: featured.session.kind.displayName,
                grandPrix: featured.session.grandPrixName,
                when: NoSpoilersCore.Strings.Schedule.sessionDateTime(featured.startsAt)
            )))
        }
    }
}

/// Puts the intent in Spotlight and Siri without the user opening Shortcuts first.
///
/// **`AppShortcutsProvider` is what makes an App Intent discoverable.** Without one the intent
/// exists only for someone who goes looking for it in the Shortcuts app, which is nobody — and for
/// a reviewer checking what this app does that a browser cannot, an intent nothing surfaces is an
/// intent that may as well not be there.
struct NoSpoilersShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: NextSessionIntent(),
            // Literals, and they have to be: `phrases:` is checked for a compile-time constant
            // and will not take a reference to `Strings`. Every phrase must carry
            // `\(.applicationName)`, which App Intents substitutes with the name the user
            // installed — which is why the app's own name is not written out here.
            phrases: [
                "When is the next session in \(.applicationName)",
                "What is on next in \(.applicationName)",
                "Next session in \(.applicationName)",
            ],
            shortTitle: "Next session",
            // `Theme.Icon.sessionCountdown`, written out for the same reason the phrases are:
            // this parameter is a compile-time constant too. The token is the source of truth and
            // the Live Activity's Dynamic Island reads it; if it changes, this changes with it.
            systemImageName: "timer"
        )
    }
}
