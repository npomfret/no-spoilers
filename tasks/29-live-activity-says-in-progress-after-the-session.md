# Task 29: the Live Activity keeps saying "In Progress" after the session is over

**Status: FILED, 2026-09-05.**

## The issue

A user's Lock Screen on Saturday 5 September at 14:01 BST showed the Live Activity for the
Italian Grand Prix reading *Free Practice 3 — In Progress* in red. FP3 ran 11:30–12:30 BST, its
30-minute grace window closed at 13:00 BST, and the Home Screen widget, the app and the
safe-to-watch alert all called it finished at that instant. The activity did not, and would not
have until the app was next opened or iOS ended it eight hours after it started.

Why, precisely:

- `SessionActivityController.refresh` starts or updates the activity **from the foreground only**.
  There is no push (no server), no `UIBackgroundModes`, and no background task. Nothing in this
  product can touch a running activity while the app is in the background.
- The content state carries a `staleDate` — the grace-window end for the live phase, the start
  for the upcoming phase — and `SessionActivityAttributes.ContentState.staleDate` says the point
  of it is that "the system dimming it as stale is what stops that reading as a live claim".
- **Nothing reads `isStale`.** `SessionActivityWidget` draws `context.state.phase` and nothing
  else, so when the stale date passes the card keeps drawing *In Progress* in `stateLive` red.
  The system does not dim or relabel a stale activity on its own; it hands the view
  `context.isStale` and leaves the drawing to us. That was the half of the feature never built.
- The same hole exists in the upcoming phase: an activity started an hour before a session says
  *starts in 0:00* — or worse, a relative "in 5m" that has counted past zero — after the session
  has begun, until the app is opened.

The store build (10011) carries the Live Activity, so this is live for everyone who has let an
activity start.

## Brainstorming

- **Draw the stale state from `context.isStale` (recommended).** A stale live activity is a
  finished session; a stale upcoming activity is a session in progress. Both facts are already
  implied by the content state plus the clock, so the view can advance one phase when the stale
  date has passed, without the app pushing anything. Cost: a small branch in the clock and glyph
  views, and a pure helper in Core that turns `(phase, isStale)` into what to draw, so it can be
  tested. Risk: whether iOS re-renders the view at the stale date has to be proven on a device;
  the documentation says it does, and nothing in this project has looked.
- **End the activity from a background refresh task.** Would need `BGAppRefreshTask`, a
  background mode, and a scheduler that iOS runs when it feels like it — which is exactly the
  "not before" guarantee that makes the widget's reload date a reasoned guess. Adds a new
  subsystem to fix a label. Not chosen.
- **Push updates via APNs.** Needs the server this product does not have. Not chosen.
- **Count down to the grace end with `Text(timerInterval:)`.** Rejected when the feature was
  built: a clock ticking down to a guess reads as "nearly over", a claim about the session the
  product does not make. The stale-date estimate is the same guess, but "finished" at the grace
  end is what every other surface already says, so drawing it is consistent rather than new.
- **Drop the live phase and end the activity when the session starts.** Loses the one thing the
  Dynamic Island glyph is for. Not chosen.

## The plan

1. **Decide what a stale activity shows, in Core.** A pure function from `(phase, isStale)` to
   a drawn state — upcoming, live, finished — beside `ContentState`, with tests in
   `NoSpoilersCoreTests` that pin all four combinations. Done when the tests pass and the
   `staleDate` doc comment says what the extension now does with it.
2. **Draw it.** `SessionActivityClock` and `SessionActivityGlyph` take the drawn state rather
   than the phase. Finished draws the same neutral label the Home Screen widget uses for a
   finished session, in `textSecondary`, never red. Upcoming-gone-stale draws *In Progress*, the
   same as live. Done when `scripts/verify-widget-build.sh` and `scripts/verify-ios-build.sh`
   pass.
3. **Prove the re-render on a device.** Start an activity for a session whose grace end is
   minutes away (a fixture, or the real feed on a race day), lock the phone, do not open the
   app, and watch the card change at the stale date. This cannot be done in the simulator — the
   Live Activity is a documented manual case in `scripts/screenshots.py`. Record the observation
   here, with the time, the way task 28 records what was and was not looked at.
4. **Say so in the docs.** `docs/guides/testing.md` gains the stale-date method from phase 3;
   the controller's doc comment stops implying the system handles stale on its own.

## Tracking

Decisions taken at filing:

- The Live Activity is this task's whole scope. Two lesser gaps were found in the same
  investigation and are **not** in it, so they are written down here rather than lost:
  - The Home Screen widget's timeline entries stop at the 48-hour horizon and its reload is asked
    for at that same instant, so a late reload leaves the last entry on screen. Planning entries
    past the reload date would close it. Separate task if it is ever seen in the wild.
  - `SessionEndConfirmer.onChange` only fires `objectWillChange`; it never asks WidgetKit to
    reload, so a confirmed end reaches the app and not the widget. Bounded by the grace period.
    Separate task.
- The finished state stays neutral. A finished Live Activity is still content on a locked
  screen the reader cannot decline; it says the session is over and nothing more.

Verification:

- [ ] Core tests for the drawn-state function, all four combinations
- [ ] `scripts/verify-core-tests.sh`, `scripts/verify-ios-build.sh`, `scripts/verify-widget-build.sh`
- [ ] Seen on a device: an activity left alone changes at its stale date without the app opening
- [ ] `docs/guides/testing.md` carries the method
