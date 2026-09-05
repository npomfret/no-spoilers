import WidgetKit
import SwiftUI
import NoSpoilersCore

// MARK: - Entry

struct NoSpoilersEntry: TimelineEntry {
    let date: Date
    let weekend: RaceWeekend?
    let sessions: [SessionViewModel]
    /// True only when the loaded schedule is exhausted — no upcoming sessions at all.
    let isOffSeason: Bool
}

// MARK: - View Models

struct SessionViewModel: Identifiable {
    let id: String
    let name: String
    let shortName: String
    let state: SessionState
}

enum SessionState {
    case finished(at: Date)
    case live
    case upcoming(startsAt: Date)

    /// The same three states the rest of the product calls `SessionStatus`,
    /// minus the dates the widget carries for its relative-time labels. The
    /// bridge exists so colour is decided in one place rather than four.
    var status: SessionStatus {
        switch self {
        case .finished: return .finished
        case .live:     return .inProgress
        case .upcoming: return .upcoming
        }
    }
}

// MARK: - Helpers

/// Thin wrapper over the shared resolver, purely to keep the `[String: Date]` lookup off every
/// call site here. The logic itself now lives in `SessionResolver` — this was the only correct
/// implementation of it, and both apps were using `session.endsAt` instead.
private func effectiveSessionEndDate(
    for session: Session,
    nextSession: Session?,
    confirmedEndDates: [String: Date]
) -> Date {
    SessionResolver.effectiveEndDate(
        for: session,
        nextSession: nextSession,
        confirmedEndAt: confirmedEndDates[session.id]
    )
}

private func sessionState(for session: Session, nextSession: Session?, at now: Date, confirmedEndDates: [String: Date]) -> SessionState {
    switch SessionResolver.status(for: session, at: now, nextSession: nextSession, confirmedEndAt: confirmedEndDates[session.id]) {
    case .finished:
        return .finished(at: effectiveSessionEndDate(for: session, nextSession: nextSession, confirmedEndDates: confirmedEndDates))
    case .inProgress:
        return .live
    case .upcoming:
        return .upcoming(startsAt: session.startsAt)
    }
}

private func placeholderEntry(at now: Date = Date()) -> NoSpoilersEntry {
    let placeholderWeekend = RaceWeekend(
        round: 16,
        name: "Japanese",
        location: "Suzuka",
        sessions: [
            .freePractice1: now.addingTimeInterval(-4 * 3600),
            .freePractice2: now.addingTimeInterval(2 * 3600),
            .freePractice3: now.addingTimeInterval(20 * 3600),
            .qualifying: now.addingTimeInterval(29 * 3600),
            .race: now.addingTimeInterval(52 * 3600)
        ]
    )

    return NoSpoilersEntry(
        date: now,
        weekend: placeholderWeekend,
        sessions: [
            SessionViewModel(id: "placeholder-fp1", name: SessionKind.freePractice1.displayName, shortName: SessionKind.freePractice1.shortName, state: .finished(at: now.addingTimeInterval(-42 * 60))),
            SessionViewModel(id: "placeholder-fp2", name: SessionKind.freePractice2.displayName, shortName: SessionKind.freePractice2.shortName, state: .upcoming(startsAt: now.addingTimeInterval(2 * 3600 + 15 * 60))),
            SessionViewModel(id: "placeholder-fp3", name: SessionKind.freePractice3.displayName, shortName: SessionKind.freePractice3.shortName, state: .upcoming(startsAt: now.addingTimeInterval(20 * 3600))),
            SessionViewModel(id: "placeholder-quali", name: SessionKind.qualifying.displayName, shortName: SessionKind.qualifying.shortName, state: .upcoming(startsAt: now.addingTimeInterval(29 * 3600))),
            SessionViewModel(id: "placeholder-race", name: SessionKind.race.displayName, shortName: SessionKind.race.shortName, state: .upcoming(startsAt: now.addingTimeInterval(52 * 3600)))
        ],
        isOffSeason: false
    )
}

private func makeEntry(at now: Date, data: ScheduleSnapshot) -> NoSpoilersEntry {
    let weekends = data.weekends
    let confirmedEndDates = data.confirmedEndDates

    let sortedWeekends = weekends.sorted { $0.round < $1.round }

    // Within 24h of the most recently finished weekend, keep showing it.
    if let previous = sortedWeekends.last(where: {
        !$0.allSessions.isEmpty &&
        RaceWeekendResolver.firstNonFinishedSession(in: $0, at: now, confirmedEndDates: confirmedEndDates) == nil
    }) {
        let endTime = RaceWeekendResolver.effectiveEndDate(of: previous, confirmedEndDates: confirmedEndDates)
        if now.timeIntervalSince(endTime) < 24 * 3600 {
            let prevSessions = previous.allSessions
            let sessionVMs = prevSessions.indices.map { i -> SessionViewModel in
                let s = prevSessions[i]
                let next = i + 1 < prevSessions.count ? prevSessions[i + 1] : nil
                return SessionViewModel(id: s.id, name: s.kind.displayName, shortName: s.kind.shortName,
                                        state: sessionState(for: s, nextSession: next, at: now, confirmedEndDates: confirmedEndDates))
            }
            return NoSpoilersEntry(date: now, weekend: previous, sessions: sessionVMs, isOffSeason: false)
        }
    }

    // Show the next upcoming weekend — no distance threshold.
    guard let upcoming = RaceWeekendResolver.firstActiveWeekend(in: weekends, at: now, confirmedEndDates: confirmedEndDates) else {
        // Schedule exhausted: genuine off-season if we have data, no-data view otherwise.
        return NoSpoilersEntry(date: now, weekend: nil, sessions: [], isOffSeason: !weekends.isEmpty)
    }

    let sorted = upcoming.allSessions
    let sessionVMs = sorted.indices.map { i -> SessionViewModel in
        let s = sorted[i]
        let next = i + 1 < sorted.count ? sorted[i + 1] : nil
        return SessionViewModel(id: s.id, name: s.kind.displayName, shortName: s.kind.shortName,
                                state: sessionState(for: s, nextSession: next, at: now, confirmedEndDates: confirmedEndDates))
    }
    return NoSpoilersEntry(date: now, weekend: upcoming, sessions: sessionVMs, isOffSeason: false)
}

/// How far ahead a timeline is built.
///
/// The widget only ever displays the current or next weekend, so an entry for a boundary in
/// October is an archived SwiftUI view nobody will ever look at. Building the whole season cost
/// ~130 entries and 3-6 seconds, which is longer than SpringBoard waits before giving up and
/// leaving the redacted placeholder — grey bars — on screen.
///
/// A duration rather than an entry count, deliberately: the horizon is also the reload interval,
/// so bounding it in time bounds staleness directly and predictably. A count would leave the
/// reload date dependent on how densely the feed happens to be packed at that moment — dense
/// during a race weekend, empty for the five days between — and in the off-season it would leave
/// no reload date at all.
///
/// **Forty-eight hours has been reasoned, not soaked.** The reload mechanism itself was watched
/// firing on 2026-08-17 by forcing the truncation branch down to a nine-minute reload date (the
/// method is in `docs/guides/testing.md`), and nothing about `.after(_:)` distinguishes nine
/// minutes from two days. What has never been observed is a device left alone for the full
/// interval, so if a widget is ever found showing content two days stale, start here.
private let timelineHorizon: TimeInterval = 48 * 3600

/// Backstop on the entry count, not the working limit. Inside 48 hours the real feed produces at
/// most ~13 boundaries (a sprint weekend's six sessions, each with a start and an end, plus the
/// recently-finished expiry). Anything approaching this cap means the feed is not what we think
/// it is, and truncating is better than handing WidgetKit an unbounded archive.
private let maxTimelineEntries = 24

// MARK: - Provider

struct NoSpoilersTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> NoSpoilersEntry {
        placeholderEntry()
    }

    func getSnapshot(in context: Context, completion: @escaping (NoSpoilersEntry) -> Void) {
        let now = Date()
        guard !context.isPreview else {
            completion(placeholderEntry(at: now))
            return
        }
        Task {
            completion(makeEntry(at: now, data: await ScheduleSnapshotLoader.load()))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NoSpoilersEntry>) -> Void) {
        Task {
            completion(await buildTimeline())
        }
    }

    /// What is left of this once the plan is `TimelinePlanner`'s: fetch the data, turn each planned
    /// moment into a rendered entry, and hand WidgetKit the result. Every date decision above is
    /// unit-tested in `TimelinePlannerTests`; nothing here re-derives one.
    private func buildTimeline() async -> Timeline<NoSpoilersEntry> {
        let now = Date()
        let data = await ScheduleSnapshotLoader.load()

        let plan = TimelinePlanner.plan(
            at: now,
            weekends: data.weekends,
            confirmedEndDates: data.confirmedEndDates,
            horizon: timelineHorizon,
            maxEntries: maxTimelineEntries
        )
        let entries = plan.entryDates.map { makeEntry(at: $0, data: data) }

        // The facts that make a stale widget diagnosable, on one line, at `.notice` so they are
        // still there tomorrow. Nothing is attached when a widget goes wrong: the app is not
        // running, and "showing last week" looks identical to "nothing happened". This line is the
        // difference. `truncated` is here because the cap changes which of two reload dates was
        // chosen, and the real feed has never once reached it.
        AppLog.widget.notice("timeline built", [
            "now": now,
            "weekends": data.weekends.count,
            "boundaries": plan.boundaryCount,
            "entries": entries.count,
            "truncated": plan.truncated,
            "horizon": plan.horizon,
            "reloadAt": plan.reloadAt,
            // What the user is actually looking at, so a trace answers "showing last week"
            // without anyone having to re-derive it from the entry dates.
            "showing": entries.first?.weekend,
        ])

        return Timeline(entries: entries, policy: .after(plan.reloadAt))
    }
}

// MARK: - Entry View

struct NoSpoilersWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: NoSpoilersEntry

    /// Which `Theme.Canvas` this family draws on.
    ///
    /// **`systemExtraLarge` shares `widgetLarge`'s scale** — that is what the
    /// canvas axis says and what `extraLargeView` already did by passing
    /// `.widgetLarge` to every component it draws.
    ///
    /// The `default` branch mirrors `systemFamilyView`'s: `systemMedium` is the
    /// fallback family, so anything WidgetKit adds later renders at medium until
    /// someone designs for it. **The accessory families never reach this** —
    /// `body` routes them away before a canvas is asked for, because they have
    /// no scale on this axis and no palette to resolve against.
    private var canvas: Theme.Canvas {
        switch family {
        case .systemSmall:                     return .widgetSmall
        case .systemLarge, .systemExtraLarge:  return .widgetLarge
        default:                               return .widgetMedium
        }
    }

    /// **Two groups of families, not one list.** The system families draw the
    /// app's own surface — its background, its palette, its `Theme.Canvas`
    /// scale. The accessory families draw on the Lock Screen and in StandBy,
    /// where the system owns the material and renders everything in a single
    /// vibrancy pass: a palette colour there is not a colour, it is a shade of
    /// the wallpaper. Splitting at the top means nothing below has to keep
    /// asking which world it is in.
    var body: some View {
        switch family {
        case .accessoryRectangular: accessoryRectangularView
        case .accessoryInline:      accessoryInlineView
        default:                    systemFamilyView
        }
    }

    /// `systemSmall` through `systemExtraLarge` — the Home Screen and Today view.
    @ViewBuilder
    private var systemFamilyView: some View {
        if let weekend = entry.weekend {
            switch family {
            case .systemSmall:
                smallView(weekend)
            case .systemLarge:
                largeView(weekend)
            case .systemExtraLarge:
                extraLargeView(weekend)
            default:
                mediumView(weekend)
            }
        } else if entry.isOffSeason {
            offSeasonView
        } else {
            noDataView
        }
    }

    // MARK: - Family views

    /// systemSmall — one glanceable answer: GP name as the hero, one session anchored at the bottom.
    @ViewBuilder
    private func smallView(_ weekend: RaceWeekend) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top row: flag + round pill
            HStack(alignment: .center, spacing: Theme.Header.contentSpacing(.widgetSmall)) {
                FlagImage(countryCode: weekend.countryCode, height: Theme.Header.flagHeight(.widgetSmall))
                Spacer(minLength: 0)
                NoSpoilersRoundPill(NoSpoilersCore.Strings.Schedule.roundLabel(weekend.round))
            }

            Spacer(minLength: Theme.Space.md)

            // Hero: GP name fills available vertical space
            Text(weekend.grandPrixName)
                .font(Theme.Typography.weekendTitle(.widgetSmall))
                .foregroundStyle(Theme.Palette.textPrimary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: Theme.Space.md)

            // Bottom: flat session row, no nested card
            if let primary = primarySession() {
                smallSessionRow(primary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// Flat two-line session row for systemSmall — name above, time below, no nested card.
    private func smallSessionRow(_ session: SessionViewModel) -> some View {
        NoSpoilersSessionRow(
            canvas: .widgetSmall,
            status: session.state.status,
            name: Text(session.shortName),
            detail: smallSessionTime(session.state)
        )
    }

    /// The small family's second line, which carries the session's state
    /// instead of the badge the larger families have room for.
    ///
    /// **The live case colours itself.** `NoSpoilersSessionRow` draws a detail
    /// line in `Theme.Palette.textSecondary`; styling the `Text` here overrides
    /// that, because a style applied to a `Text` wins over one applied to its
    /// container. A live session is the one state this row says in red rather
    /// than in words.
    private func smallSessionTime(_ state: SessionState) -> Text {
        switch state {
        case .finished(let endedAt):
            return Text(endedAt, style: .relative)
        case .live:
            return Text(NoSpoilersCore.Strings.Schedule.inProgress)
                .foregroundStyle(Theme.Palette.stateLive)
        case .upcoming(let startsAt):
            return Text(startsAt, style: .relative)
        }
    }

    /// systemMedium — header + up to 3 sessions.
    ///
    /// **Three, not two, since 2026-09-02.** The third row sits where the
    /// next-weekend footer used to; with the footer gone, two rows left the
    /// bottom third of the family empty.
    @ViewBuilder
    private func mediumView(_ weekend: RaceWeekend) -> some View {
        let sessions = prioritizedSessions(limit: 3)
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            widgetHeader(weekend, canvas: .widgetMedium)
            VStack(spacing: Theme.Space.xs) {
                ForEach(sessions) { session in
                    widgetSessionRow(session, canvas: .widgetMedium)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// systemLarge — expanded header, full session list.
    @ViewBuilder
    private func largeView(_ weekend: RaceWeekend) -> some View {
        let visibleSessions = Array(entry.sessions.prefix(5))
        let hiddenCount = max(0, entry.sessions.count - visibleSessions.count)
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            widgetHeader(weekend, canvas: .widgetLarge)
            Divider()
            VStack(spacing: Theme.Space.xs) {
                ForEach(visibleSessions) { session in
                    widgetSessionRow(session, canvas: .widgetLarge)
                }
                if hiddenCount > 0 {
                    Text(Strings.Widget.moreSessions(hiddenCount))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .padding(.horizontal, Theme.Space.md)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// systemExtraLarge — the large header and every session, with nothing
    /// capped.
    ///
    /// **This was a two-zone layout** — the weekend on the left, a 140pt
    /// "Next up" sidebar naming the weekend after it on the right — until
    /// 2026-09-02, when the next-weekend block was removed from every widget
    /// family. What remains is the left column at full width. It is not
    /// `largeView` because that one caps the list at five and says "+N more"
    /// for the rest; this family has the height for a sprint weekend's six.
    @ViewBuilder
    private func extraLargeView(_ weekend: RaceWeekend) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            widgetHeader(weekend, canvas: .widgetLarge)
            Divider()
            VStack(spacing: Theme.Space.xs) {
                ForEach(entry.sessions) { session in
                    widgetSessionRow(session, canvas: .widgetLarge)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Accessory families

    /// `accessoryRectangular` — the Lock Screen tile, and the one accessory
    /// family with room to say what is happening rather than only when.
    ///
    /// Three lines is the whole budget, and they are the three fields every
    /// other family already leads with: the Grand Prix, the session, the clock.
    /// **Nothing is shown here that the Home Screen widget does not already
    /// show.** This is content pushed onto a locked screen that the reader
    /// cannot decline to look at — the same class of surface as the alert copy
    /// — so it is deliberately a smaller view of the same three fields rather
    /// than a new place to put something.
    ///
    /// **No `Theme.Palette` and no `Theme.Canvas`.** Accessory families render
    /// in `.accessory` vibrancy mode, which flattens every colour into one
    /// material: `stateLive` red arrives as exactly the same shade as the body
    /// text, so a live session has to say so in words where `smallSessionTime`
    /// can say it in colour. The type is the system's to scale here too, which
    /// is why these are semantic fonts and not a sixth case on the canvas axis.
    @ViewBuilder
    private var accessoryRectangularView: some View {
        if let weekend = entry.weekend, let session = primarySession() {
            VStack(alignment: .leading, spacing: 0) {
                Text(weekend.grandPrixName)
                    .font(.headline)
                    .lineLimit(1)
                Text(session.name)
                    .font(.caption)
                    .lineLimit(1)
                accessoryStateText(session.state)
                    .font(.caption2)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            Text(accessoryEmptyTitle)
                .font(.headline)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    /// `accessoryInline` — the single line beside the Lock Screen clock, which
    /// the system draws in its own font and its own colour whatever this asks
    /// for. One `Text`, no styling, no second line, and no view that is not one.
    ///
    /// **The session wins the width, not the Grand Prix.** Both do not fit, and
    /// someone who has put this on their Lock Screen during a race weekend
    /// knows which weekend it is; what a glance is for is how long.
    private var accessoryInlineView: some View {
        guard let session = primarySession() else {
            return Text(accessoryEmptyTitle)
        }
        return Text(session.shortName) + Text(verbatim: " \u{00B7} ") + accessoryStateText(session.state)
    }

    /// A session's state as one line of plain text.
    ///
    /// The finished case is `stateLabel`'s large-family wording — "Finished"
    /// and how long ago — because the accessory families have the same one line
    /// to spend and no badge to spend it in.
    private func accessoryStateText(_ state: SessionState) -> Text {
        switch state {
        case .finished(let endedAt):
            return Text(Strings.Sessions.finished) + Text(verbatim: " \u{00B7} ") + Text(endedAt, style: .relative)
        case .live:
            return Text(NoSpoilersCore.Strings.Schedule.inProgress)
        case .upcoming(let startsAt):
            return Text(startsAt, style: .relative)
        }
    }

    /// The one line an accessory family has for "nothing to show".
    ///
    /// `offSeasonView` and `noDataView` are message cards — an icon, a title and
    /// a paragraph telling you what to do about it. None of that fits on a Lock
    /// Screen tile, and both reduce to their title without losing the answer.
    private var accessoryEmptyTitle: LocalizedStringKey {
        entry.isOffSeason
            ? Strings.OffSeason.badge
            : NoSpoilersCore.Strings.Schedule.unavailableTitle
    }

    /// **The round pill goes with this, and that is the point rather than a
    /// casualty.** The widget was the only surface whose off-season state was a
    /// pill and a symbol where every other one is a symbol over a title over a
    /// line of body. `Strings.OffSeason.badge` reads as that title unchanged.
    @ViewBuilder
    private var offSeasonView: some View {
        NoSpoilersMessageCard(
            iconName: Theme.Icon.offSeason,
            title: Text(Strings.OffSeason.badge),
            bodyText: Text(Strings.OffSeason.body),
            canvas: canvas
        )
    }

    @ViewBuilder
    private var noDataView: some View {
        NoSpoilersMessageCard(
            iconName: Theme.Icon.scheduleUnavailable,
            title: Text(NoSpoilersCore.Strings.Schedule.unavailableTitle),
            bodyText: Text(Strings.Error.unavailableBody),
            canvas: canvas
        )
    }

    // MARK: - Shared view helpers

    /// The header the medium and large families draw.
    ///
    /// **Two arrangements, not one at two sizes** — which is why the weekend
    /// header did not converge into `SharedChrome` and only its metadata line
    /// did. Medium is flag + name + round pill on one line; large stacks the
    /// name over `NoSpoilersWeekendMeta`. The small family draws neither and
    /// does not call this.
    @ViewBuilder
    private func widgetHeader(_ weekend: RaceWeekend, canvas: Theme.Canvas) -> some View {
        if canvas == .widgetMedium {
            HStack(alignment: .center, spacing: Theme.Header.contentSpacing(canvas)) {
                FlagImage(countryCode: weekend.countryCode, height: Theme.Header.flagHeight(canvas))
                Text(weekend.grandPrixName)
                    .font(Theme.Typography.weekendTitle(canvas))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                NoSpoilersRoundPill(NoSpoilersCore.Strings.Schedule.roundLabel(weekend.round))
            }
        } else {
            HStack(alignment: .center, spacing: Theme.Header.contentSpacing(canvas)) {
                FlagImage(countryCode: weekend.countryCode, height: Theme.Header.flagHeight(canvas))
                VStack(alignment: .leading, spacing: Theme.Space.xxs) {
                    Text(weekend.grandPrixName)
                        .font(Theme.Typography.weekendTitle(canvas))
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .lineLimit(1)
                    NoSpoilersWeekendMeta(
                        canvas: .widgetLarge,
                        round: weekend.round,
                        location: weekend.location,
                        dateRange: sessionDateRange(for: weekend)
                    )
                }
            }
        }
    }

    /// The medium and large families' session row.
    ///
    /// **The two families differ in more than size**, which is why this takes a
    /// canvas rather than the `compact: Bool` it used to: medium shows the short
    /// session name with the full one underneath when they differ, and large
    /// shows the full name with no second line at all.
    private func widgetSessionRow(_ session: SessionViewModel, canvas: Theme.Canvas) -> some View {
        let isMedium = canvas == .widgetMedium
        return NoSpoilersSessionRow(
            canvas: canvas,
            status: session.state.status,
            name: Text(isMedium ? session.shortName : session.name),
            detail: isMedium && shouldShowSecondaryName(for: session) ? Text(session.name) : nil
        ) {
            stateLabel(session.state, canvas: canvas)
        }
    }

    /// The span a weekend covers, or nil when it has no sessions to span.
    ///
    /// **It used to return the location instead of nil**, which drew the place
    /// name twice on the same line — once as the location and once where the
    /// dates belong. `NoSpoilersWeekendMeta` takes the absence directly, so the
    /// line simply ends after the location, which is what iOS and the popover
    /// already did.
    private func sessionDateRange(for weekend: RaceWeekend) -> String? {
        guard let first = weekend.allSessions.first, let last = weekend.allSessions.last else {
            return nil
        }
        return NoSpoilersCore.Strings.Schedule.dateRange(from: first.startsAt, to: last.startsAt)
    }

    private func primarySession() -> SessionViewModel? {
        entry.sessions.first {
            if case .finished = $0.state { return false }
            return true
        } ?? entry.sessions.last  // all finished: show most recent (Race), not oldest (FP1)
    }

    private func prioritizedSessions(limit: Int) -> [SessionViewModel] {
        let active = entry.sessions.filter {
            if case .finished = $0.state { return false }
            return true
        }
        if active.count >= limit {
            return Array(active.prefix(limit))
        }
        // Pad with most recently finished first (reverse chronological), not oldest first
        let recentFinished = entry.sessions.filter {
            if case .finished = $0.state { return true }
            return false
        }.reversed()
        return Array((active + recentFinished).prefix(limit))
    }

    private func shouldShowSecondaryName(for session: SessionViewModel) -> Bool {
        let shortName = normalizedSessionLabel(session.shortName)
        let fullName = normalizedSessionLabel(session.name)
        guard !shortName.isEmpty, !fullName.isEmpty else { return false }
        return !fullName.contains(shortName) && !shortName.contains(fullName)
    }

    private func normalizedSessionLabel(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "", options: .regularExpression)
    }

    /// **The medium family says "Finished" and stops.** The large one has the
    /// width to say how long ago as well, which is the one place the badge's
    /// *text* varies by family rather than just its size.
    @ViewBuilder
    private func stateLabel(_ state: SessionState, canvas: Theme.Canvas) -> some View {
        switch state {
        case .finished(let endedAt):
            if canvas == .widgetMedium {
                NoSpoilersStatusBadge(textKey: Strings.Sessions.finished, style: .finished, canvas: canvas)
            } else {
                NoSpoilersStatusBadge(
                    text: Text(Strings.Sessions.finished) + Text(verbatim: " · ") + Text(endedAt, style: .relative),
                    style: .finished,
                    canvas: canvas
                )
            }
        case .live:
            NoSpoilersStatusBadge(
                textKey: NoSpoilersCore.Strings.Schedule.inProgress,
                style: .live,
                canvas: canvas
            )
        case .upcoming(let startsAt):
            NoSpoilersStatusBadge(text: Text(startsAt, style: .relative), style: .upcoming, canvas: canvas)
        }
    }
}

// MARK: - Widget

/// The container background, and which families get one.
///
/// **Only the system families do.** `NoSpoilersBackground` is the app's own
/// opaque surface; on the Lock Screen the system supplies the material and draws
/// the widget over the wallpaper, so a filled background there is at best
/// ignored and at worst a plate over someone's photo — and which of those you
/// get differs between the Lock Screen, StandBy and the tinted Home Screen.
/// Naming the families the background is for costs one branch and does not
/// depend on any of those three stripping it for us.
private struct NoSpoilersWidgetBackdrop: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryRectangular, .accessoryInline, .accessoryCircular:
            Color.clear
        default:
            NoSpoilersBackground()
        }
    }
}

struct NoSpoilersWidget: Widget {
    let kind: String = NoSpoilersConfig.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NoSpoilersTimelineProvider()) { entry in
            NoSpoilersWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    NoSpoilersWidgetBackdrop()
                }
        }
        .configurationDisplayName(NoSpoilersCore.Strings.AppInfo.name)
        .description(Strings.Widget.widgetDescription)
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge, .systemExtraLarge,
            .accessoryRectangular, .accessoryInline,
        ])
    }
}

// MARK: - Previews

struct NoSpoilersWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            preview(.systemSmall, "Small")
            preview(.systemMedium, "Medium")
            preview(.systemLarge, "Large")
            preview(.systemExtraLarge, "Extra Large")
            preview(.accessoryRectangular, "Lock Screen \u{2014} Rectangular")
            preview(.accessoryInline, "Lock Screen \u{2014} Inline")
        }
    }

    /// One preview per family, each carrying the same backdrop split the widget
    /// itself uses.
    ///
    /// **The background moved off the `Group` to get here.** Applying it once
    /// to all six would draw the accessory families over the app's own opaque
    /// surface, which is the one thing they are never drawn on — and a Lock
    /// Screen tile that looks right in a preview and wrong on a phone is worse
    /// than no preview.
    private static func preview(_ family: WidgetFamily, _ name: String) -> some View {
        NoSpoilersWidgetEntryView(entry: placeholderEntry())
            .containerBackground(for: .widget) {
                NoSpoilersWidgetBackdrop()
            }
            .previewContext(WidgetPreviewContext(family: family))
            .previewDisplayName(name)
    }
}
