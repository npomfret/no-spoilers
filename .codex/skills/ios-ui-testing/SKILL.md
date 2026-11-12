---
name: ios-ui-testing
description: Project conventions for XCUITest UI tests, page objects, stubs and test plans. Read before changing tests that launch an iOS app or investigating their failures and flakiness.
---

## iOS UI testing

Use these conventions for XCUITest UI tests, page objects, launch stubs and test plans. Unit tests that do not launch the app are outside this skill. Shared rules and platform notes use the same numbers.

### Shared UI testing rules

Tests describe user behavior through page objects. Keep navigation and element knowledge in those objects so UI changes have one place to update.

1. **Page objects own the screen.** Tests arrange data/stubs, call page-object methods and assert returned values. Element lookup, actions, reads and UI assertions stay inside shared page-object classes, including modals and common regions.
2. **Locate by what a person perceives.** Start at a recognisable section, dialog or row, then narrow by role, accessible name, label or visible source-locale text. Write source text literally. Fix missing interface labels rather than navigating DOM/tree internals. A lookup must identify exactly one element: no first/last/nth selection. Check lists as a whole. Test-only identifiers need a page-object-local comment explaining why perceivable lookup cannot work. Build fresh queries, not cached values from the screen.
3. **Poll for change.** Every result check, including absence, retries until its expected state or named timeout. Fixed delays are not allowed.
4. **Avoid snapshot decisions.** Do not branch on a one-off element read or assert it with plain equality. One-off reads are only for diagnostics after a polling assertion fails. Assert user-visible behavior, focus, semantic states and requests, not styling, application internals or element-tree snapshots.
5. **Actions verify their effect.** Check visibility/enabled state, perform the action, wait for its result and return the already-verified page object for the destination. A modal closing waits for closure; a save waits for visible confirmation/change. Each starting screen has a static entry point or fixture that opens and verifies it; tests do not construct page objects. Constructors do not wait. Each object has `verifyLoaded()` for its own landmarks. Name methods by their outcome; an action staying on the same screen may return nothing.
6. **Prove the transition.** Assert the relevant old state before an action as well as the new state after it, so leftover data or a no-op cannot pass.
7. **Use real input.** Do not force actions, call handlers to bypass UI, or retry submits/creates/deletes. Fix missed input in the app. While a fix is pending, only an idempotent action/assertion pair may be retried.
8. **Fail at the first wrong state.** Page objects check their screen before steps, old/new field values around edits, validation state before submission, and destination landmarks after navigation. Poll these checks; failures say what was actually visible and where. Keep named timeout constants together; increasing a limit is not a timing fix.
9. **Stub external boundaries.** Use typed/validated builders and install network/system-service stubs before navigation or launch. Do not mock project components, hooks or view models. A mid-test server change replaces the stub, triggers the real update event and waits for the UI result.
10. **Treat flakiness as failure.** Disable automatic retries. After a timing fix, repeat the affected test (normally 20 times) and report the pass count.

### Departures

Rules 3, 4 and 7 have no exceptions. Other departures need a comment naming the rule, the concrete constraint and what would remove it. The single-match requirement in rule 2 also has no exception.

### On iOS

1. **Tests never touch the screen.**
   - Every screen, sheet, alert, popover and shared region (tab bar, navigation bar) has one page-object class, in one folder of the UI test target.
   - Forbidden in a test method:
     - `XCUIApplication()` and `launch()` (rule 5 says who launches)
     - any `XCUIElementQuery` or `XCUIElement`: `app.buttons`, `app.staticTexts`, `descendants(matching:)` and the rest
     - acting on an element: `tap`, `doubleTap`, `press(forDuration:)`, `typeText`, `swipeUp` and the other swipes, `adjust(toPickerWheelValue:)`
     - reading an element: `exists`, `label`, `value`, `isHittable`, `isEnabled`, `isSelected`, `count`, `frame`, `snapshot()`, `debugDescription`
     - any `XCTAssert…` on an element or on something read from one
   - Device actions, such as rotating with `XCUIDevice.shared.orientation` or pressing the home button, go through a page object too. The screen has to settle afterwards, and the page object waits for that.

2. **Find elements by narrowing.**
   - The page-object base class finds by what a person reads, through two small helpers:

     ```swift
     extension XCUIElementQuery {
       /// The one element whose label a person reads as `label`.
       func labelled(_ label: String) -> XCUIElement {
         matching(NSPredicate(format: "label == %@", label)).element
       }
       /// The elements with something inside them that reads `text`.
       func containing(text: String) -> XCUIElementQuery {
         containing(NSPredicate(format: "label == %@", text))
       }
     }

     // the "Rent" row, inside the "Expenses" section, then its Delete button
     app.otherElements.labelled("Expenses")
       .cells.containing(text: "Rent").element
       .buttons.labelled("Delete")

     // an alert by its title, then one of its buttons
     app.alerts.labelled("Delete group?").buttons.labelled("Delete")
     ```
   - Each step uses the kind of element (`buttons`, `cells`, `staticTexts`, `textFields`, `switches`, `alerts`, `sheets`, `navigationBars`) and what a person reads on it: its accessibility label, a field's `placeholderValue`, visible text, an image's accessibility label.
   - Never use the query subscript (`app.buttons["Save"]`) or `matching(identifier:)`. Apple documents the subscript as matching "an identifier only", and a person cannot see an identifier.
   - An icon-only button, such as an SF Symbol, gets an explicit `.accessibilityLabel`, which is what VoiceOver reads. The test finds it by that label.
   - A section with a title but no label is fixed in the app. In SwiftUI, give the container `.accessibilityElement(children: .contain)` and an `.accessibilityLabel`; in UIKit, set `accessibilityLabel` and `accessibilityContainerType` on the container view. Mark its title with `.accessibilityAddTraits(.isHeader)`.
   - The entry point launches with the source locale, `-AppleLanguages (en) -AppleLocale en_US`, so labels are the literal source text.
   - Never find an element by `accessibilityIdentifier`, by position in the tree, by coordinates or by frame.
   - A game scene whose nodes are not accessibility elements can only be driven by coordinates. That is a departure from rule 2, and carries the comment that "Departing from these rules" requires. The fix is to expose the nodes a player touches as accessibility elements.
   - **Never use `firstMatch` or `element(boundBy:)`.** `.element` stands for the query's single match, and an action on it fails with "Multiple matching elements found" when the lookup is ambiguous. `firstMatch` stops at the first match, which hides that failure.
   - A list is checked whole: poll its count, or its labels in order, with the polling helper (rule 3).
   - An `accessibilityIdentifier` is allowed only inside a page object, with the comment rule 2 asks for.
   - Each lookup is a computed property on the page object (`var saveButton: XCUIElement { … }`). An `XCUIElement` resolves again on every use, but a `label`, `value`, `count` or `exists` read from it is a snapshot. Never keep one.

3. **Poll with the waiting APIs.**
   - `sleep`, `usleep`, `Thread.sleep`, `RunLoop.current.run(until:)` and waiting on an expectation that nothing fulfils are forbidden, with no exceptions. That includes a hand-rolled loop with a sleep between reads.
   - Wait with:
     - `waitForExistence(timeout:)`, always inside an assertion: `XCTAssertTrue(save.waitForExistence(timeout: Timeouts.element), "…")`. On its own, its `false` is silently ignored.
     - `waitForNonExistence(timeout:)` for "gone"
     - `wait(for: \.isEnabled, toEqual: true, timeout:)` for a value on one element, such as `\.label`, `\.value`, `\.isSelected` or `\.isHittable`
     - for anything else (a query's count, a list's labels, a value that is not on one element), an `XCTNSPredicateExpectation` waited on with `XCTWaiter`, wrapped in one helper in the page-object base class
   - Animations may be turned off with a launch argument the app reads, to make tests faster. That never replaces polling.

4. **Snapshot reads.**
   - `exists`, `isHittable`, `isEnabled`, `isSelected`, `label`, `value`, `count`, `frame` and `snapshot()` are one-off reads. Never branch on one, and never assert one with `XCTAssertTrue(element.exists)` or `XCTAssertEqual(element.label, …)`. Use the waiting APIs from rule 3.
   - Never assert `debugDescription` or the element tree.

5. **Hand over the next page object.**
   - The entry point is a static `launch(…)` on the first screen's page object. It builds the `XCUIApplication`, sets the locale and stubs (rule 9) as launch arguments and environment, launches, calls `verifyLoaded()` and returns the page object:

     ```swift
     let login = LoginScreen.launch(stubs: .signedOut)
     let dashboard = login.loginAndOpenDashboard(email: email, password: password)
     let group = dashboard.openGroup("Flat 3")
     let expense = group.tapAddExpenseAndOpenForm()
     ```
   - Page objects hold the `XCUIApplication` and pass it to the page object they return. A test never holds one.
   - `verifyLoaded()` asserts the navigation bar's title, or the landmarks only that screen shows.
   - A system permission prompt is something a person sees, so when the prompt is what the test is about, it has a page object too. That page object finds the prompt in `XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts`. Never use `addUIInterruptionMonitor`: it handles whatever alert turns up at the next interaction, an action no test waited for.

7. **Never force.**
   - Act through real events: `tap()`, `typeText`, the swipes, `adjust(toPickerWheelValue:)`, the hardware keyboard.
   - Never tap a coordinate to reach an element that XCUITest reports as not hittable.
   - Never use a launch argument to skip past a screen the test is about.
   - While a fix is pending, a page-object helper may retry an idempotent pair, such as opening a menu and asserting it is open. Never retry a submit, create or delete.

8. **Sanity checks.**
   - Every test sets `continueAfterFailure = false`, so the first failed check stops the test, rather than letting later steps fail for an unrelated reason.
   - A check that fails says what was on screen. super-funmax-music's `onScreen(app)` is the pattern: it lists the texts and buttons showing.
   - Every page-object method takes `file: StaticString = #filePath, line: UInt = #line` and passes them to its assertions. Xcode then marks the failing step in the test, not a line inside the page object.

9. **Stub at the boundary.**
   - The test runs in a separate process from the app, so it cannot intercept the app's requests itself. It passes stubs to the app at launch, in `launchArguments` or `launchEnvironment`. Under test, the app answers its own requests from them, with a `URLProtocol` registered on its session, or it is pointed at a local stub server that the test controls.
   - Stub data is encoded with the app's own `Codable` models, shared with the test target, so it cannot drift.
   - System services are a boundary too: permissions, the clock, location, StoreKit (a `.storekit` configuration in the test plan). Set their state at launch rather than driving system prompts, unless the prompt is what the test is about.
   - Launch arguments are fixed for the whole launch. A test that changes server state partway through needs a stub server the test controls.

10. **Flaky is failing.**
    - "Retry on Failure" stays off in the test plan, and nothing passes `-retry-tests-on-failure` to `xcodebuild`.
    - After a timing fix, run the test with `xcodebuild test -only-testing:<target>/<class>/<test> -test-iterations 20` and report the count that passed.

*Generated from `npomfret/agent-standards`. Edit the standard there, not this copy.*
