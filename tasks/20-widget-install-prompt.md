# Task 20: tell the user to add the widget, and stop telling them once they have

**Status: PROPOSED, 2026-08-13. Needs sign-off before implementation — it adds a UI surface to a
single-view app, which is a pattern decision, not a tweak.**

Asked 2026-08-13: *can we add an in-app button for creating the widget?*

**No — and no workaround exists.** There is no public API to place a widget on the Home Screen.
Apple has never shipped one; adding a widget is a user gesture by design, and nothing in WidgetKit,
`UIApplication`, or any URL scheme opens the widget gallery. Any "add widget" button would be a lie.

What *is* available is the other half of the problem, and it is the more useful half.

---

## What the API actually gives us

`WidgetCenter.shared.getCurrentConfigurations` reports which of our widgets are installed, in which
families. No entitlement, no user permission, iOS 14+.

```swift
WidgetCenter.shared.getCurrentConfigurations { result in
    // Result<[WidgetInfo], Error>  —  WidgetInfo has .kind, .family, .configuration
}
```

Our kind is `"NoSpoilersWidget"` (`NoSpoilers/NoSpoilersWidget/NoSpoilersWidget.swift:706`).

So the app can know whether the widget is on a Home Screen, and behave accordingly.

---

## The proposal

A card in `ContentView` that explains how to add the widget, shown **only while no widget is
installed**, and gone the moment one is. Long-press → `+` → search "No Spoilers" → pick a size, with
an illustration. Static content; no button that claims to do the adding.

Three reasons this is worth building rather than filing away:

1. **The product does not work until the widget is placed.** Task 17 records the decision that on
   iOS the core product *is* the live updating widget. Right now the app ships with no acknowledgement
   of that anywhere in its UI — the one step that makes it useful is the one step it never mentions.

2. **It is a direct answer to 4.2.2.** Task 16's live rejection is minimum functionality. An app
   that detects its own widget and guides installation is doing something on its own behalf, not
   acting as a launcher for an extension. This is a stronger answer than more screenshots.

3. **We proved this morning that people get it wrong.** Two experienced attempts at adding this
   widget landed it on the Today View instead of the Home Screen, and neither noticed until a
   screenshot came back without it. If we get it wrong, users do.

---

## Constraints on the implementation

**Where it goes.** `NoSpoilers/NoSpoilers/ContentView.swift` is the whole iOS UI (458 lines, one
view). A new card is a new surface in a file that currently has none, so **the decision to be
signed off is whether `ContentView` grows a second concern or the app gains a view file.** Do not
pick silently; there is no established local pattern for either, which per `CLAUDE.md` means
proposing before spreading.

**Strings.** `NoSpoilers/NoSpoilers/Strings.swift` is the established home for every user-facing
string in the app target, with `LocalizedStringKey` for static text and format functions for
dynamic. New strings go there under a new `enum Widget`, matching the existing shape exactly.

**The error case is not "not installed", and this is the fail-fast trap.**
`getCurrentConfigurations` hands back a `Result`. A `.failure` means *we do not know*, and mapping
it to "no widget" shows a permanent nag to a user who already added one, while mapping it to
"installed" hides the guidance from someone who needs it. Per the repo's fail-fast rule, neither
silent default is acceptable — decide explicitly what a failure means and write the reasoning into
the code. Note that `?? false` here is exactly the papering-over the rule forbids.

**Refresh timing.** The result is a snapshot. A user who reads the card, adds the widget, and comes
back must not still see it — re-query on `scenePhase` becoming `.active`.

**Do not reuse the Live Activity or Control widget stubs.** `NoSpoilersWidgetLiveActivity.swift`
and `NoSpoilersWidgetControl.swift` are unmodified Xcode template scaffolding, not registered in
`NoSpoilersWidgetBundle`, and rendering `Text("Hello \(context.state.emoji)")`. They are not a head
start on anything.

---

## Out of scope

- **An App Preview video showing how to add the widget.** Deferred deliberately: separate toolchain
  (`simctl io recordVideo`, 15–30s, strict format and resolution rules), does not answer the
  rejection, and the demo belongs *in* the app rather than in the listing. Revisit after approval.
- Any attempt to script or automate widget placement on a user's device. **`scripts/screenshots.py`
  does exactly that with `--widget-size`, and it is not a precedent**: it works by rewriting
  SpringBoard's `IconState.plist` on a shut-down simulator whose container it owns. Nothing
  equivalent is reachable from inside a sandboxed app on a real device, which is why the card above
  instructs rather than acts.

---

## Verification

- [ ] Card appears on a device with no widget installed
- [ ] Card disappears after adding the widget, without relaunching the app
- [ ] A `getCurrentConfigurations` failure behaves as documented, and the documented behaviour is
      the one that was chosen on purpose
- [ ] All new text lives in `Strings.swift`
- [ ] `scripts/verify-ios-build.sh` passes
- [ ] No change to widget behaviour — this is app-target only

---

## Related

- **Task 16** — 4.2.2 minimum functionality; this is a candidate answer.
- **Task 17** — the decision that the widget is the core product on iOS.
- **Task 19** — the widget renders grey bars for its first few seconds. If that is not fixed first,
  a user who follows this card's instructions sees a blank widget and concludes it is broken. **Fix
  19 before shipping 20.**
