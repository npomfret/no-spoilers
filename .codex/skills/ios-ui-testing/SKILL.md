---
name: ios-ui-testing
description: >-
  The required rules for every XCUITest UI test in this project: UI test
  targets, the page objects that drive XCUIApplication, launch arguments,
  stubs and test plans. Load this before writing, changing, fixing or
  reviewing any of them, before adding a UI test for a screen change or bug
  fix, and whenever a UI test is flaky or times out. Covers why tests never
  touch the screen - querying, tapping, typing, reading and asserting on
  elements happens only in page objects - finding an element the way a
  person does, by narrowing from a title, label or text into its section
  and never by accessibility identifier or the query subscript, every
  lookup matching exactly one element with no firstMatch or
  element(boundBy:), why no change is instant so every check polls with
  waitForExistence, waitForNonExistence or wait(for:toEqual:) and never
  sleeps, never deciding on an exists or label read, actions that wait for
  their own effect and return the page object for where the user lands so
  tests never launch the app or construct one, asserting state before and
  after, never tapping a coordinate or retrying a side effect, page objects
  full of sanity checks so failures name the real cause and say what was
  on screen, stubbing the network and system services at launch, and
  treating a flaky test as a failing one.
---

## iOS UI testing

This standard covers every test that drives an iOS app through XCUITest: the UI test targets, their page objects, launch configuration and test plans. Unit tests that never launch the app are outside it.

No suite in the fleet follows every rule yet. super-funmax-music's `FunMaxMusicUITests` comes closest: its failures say what was on screen, its stubs arrive as launch arguments, and its stories end in an accessibility audit. What it still does that breaks a rule is named under "Not the model".

The rules are shared with the browser testing standard, so a rule has the same number on both platforms. They come first. "On iOS" then names, rule by rule, the XCUITest APIs each one forbids and the ones to use instead.

### Why

- **No duplication in tests.** How to reach and drive a part of the screen is written once, in its page object. Twenty tests that open the same dialog call one method; they do not each repeat its lookups and waits.
- **Screens can be refactored without breaking tests.** When layout, markup or a component changes, the fix is one edit in one page object. The tests, which state what a user does and expects, do not change at all.
- **Tests behave like a person.** A person picks what to tap or click by what they can see and read: a button's label, a heading, a field's name. They never look at ids, classes or other attributes they cannot see. They find the right section of the screen first, then look inside it. Tests find elements the same way, so they pass when the screen works for a person, and fail when it does not.
- **A person waits to see what happened.** After an action, a person watches for the screen to respond before doing the next thing: the dialog opens, the row appears, the spinner goes. They do not carry on blindly, assuming the screen has already updated. A modern interface renders, fetches and animates on its own schedule, so a test that assumes an action took effect instantly fails at random. Every action in a page object therefore waits for its own visible result, and every check polls until the expected state appears.

Each rule below serves one or more of these.

### The rules

These are strict. A test or page object that breaks one is wrong, whatever the comment beside it says. Each rule is stated here for every platform; the platform section after them names the APIs it forbids and the ones to use instead, under the same number.

1. **Tests never touch the screen. Page objects do.** This rule is what keeps tests free of duplication and lets the screen be refactored without touching them.
   - Every page, screen, modal, dialog, sheet, menu and shared region has one page-object class, kept in one shared place.
   - All access to elements on the screen happens inside a page object: finding them, acting on them, reading them and asserting on them.
   - Forbidden in a test: any element lookup or handle, any action on an element, any read of an element, and any assertion on one.
   - A test may only:
     - arrange data, fixtures and stubs
     - call page-object methods
     - assert on values a page-object method returned
   - When a test needs something that no page object offers, add a method to the page object. Never reach past it.
   - A test reads as a sequence of user steps.

2. **Find elements the way a person does: narrow down from what is on screen.**
   - A person does not scan the whole screen for a button. They find the right part of the screen by something they can read: a heading, a label, a dialog's title, a row's text. Then they look only inside that part, and repeat until they reach the thing they want.
   - A lookup does the same. It starts at a container a person would recognise, then narrows inside it one perceivable step at a time.
   - Every step uses only what a person can perceive, which is also what assistive technology reads out: the kind of control and its accessible name, a field's label, visible text, an image's description.
   - Never search the whole screen for something that appears in more than one place. "The Delete button" is ambiguous to a person too. Say which section it is in.
   - An icon-only control is found by its accessible name, which is also what a screen reader announces.
   - Tests run in the source locale and write its words literally, so a missing or wrong message fails.
   - If no perceivable step reaches an element, the interface is at fault. Typically a section has a heading but is not a labelled container, or a control has no label. Fix the interface, not the test.
   - Never find an element by anything a person cannot see: ids, test identifiers, class or type names, other attributes, tree structure such as "the parent of", or component internals.
   - **A lookup matches exactly one element. Never pick the first, last or nth of several matches, with no exceptions.**
     - The test framework refuses to act on an ambiguous match, or can be made to. That error is the test telling you the lookup is ambiguous. Taking the first match silences it and picks one arbitrarily. Today that may be the right element; after the next render, sort or data change it will be another, and the test passes or fails for reasons nobody can see.
     - When a lookup matches more than one element, narrow it further by what a person can see: the section, the row's text, the label. If nothing perceivable tells the matches apart, the screen has a defect, such as two identical unlabelled controls. Fix the screen.
     - A list is checked as a whole, by its count or by its full contents in order. Never pick out items by position.
   - A test-only identifier is allowed only inside a page object, with a comment saying why no perceivable step can find that element.
   - Each lookup is a page-object member that queries the screen afresh every time it is used. Never keep a value read from the screen, such as a text, a count or a visibility result, to act on later. The screen re-renders in between.

3. **No change is instant. Poll for it.** A person waits to see the result of what they did, and so does a test.
   - After any action, the screen changes later, never immediately. This covers a tap or click, a keystroke, navigation, a stub swap, a rotation and a server push.
   - Every check of a result therefore polls until the expected state appears, or until a named timeout fails it. A check that reads once, right after the action, is wrong even when it passes.
   - This applies to absence as well. "Gone" is polled, never assumed.
   - A fixed delay of any kind is forbidden, with no exceptions.
   - A fixed delay always stands in for something you can observe: focus moved, an animation settled, a request answered, a row appeared. Wait for that thing instead.

4. **Never make a decision on a snapshot.**
   - A one-off read of an element (is it visible, how many are there, what does it say) returns whatever was on screen at that millisecond.
   - Never branch on one, and never assert one with a plain equality check.
   - One-off reads are allowed in one place only: building the message after a polling assertion has already failed.
   - Assert what the user perceives: visible text, the kind of control, states such as checked, expanded, selected and disabled, where focus is, and the requests the app sent. Never assert styling, internal state or snapshots of the element tree.

5. **Every action waits for its own effect, then hands over the page object for wherever the user ended up.** A person does not act again until the screen has responded, and then carries on from where they landed.
   - Before acting, assert the target is visible and enabled. A failure then says "Save was disabled" rather than "timed out tapping".
   - After acting, wait for the result, and return the page object for where the user now is:
     - An action that moves to another screen waits for that screen's `verifyLoaded()`, then returns its page object.
     - An action that opens a modal, sheet or dialog asserts it is open, then returns its page object.
     - An action that closes one waits for it to close, then returns the page object for the screen underneath.
     - A save waits for the visible result, such as the confirmation, the closed dialog or the updated row.
   - **Tests never construct a page object themselves.** The only way into the flow is one static entry point per starting screen, or a fixture built on it, which opens the app there, verifies the screen and returns its page object. Every page object after that is handed over by the action that led there, already verified.
   - This is why it matters:
     - The test follows the user's path, and cannot hold a page object for a screen the app is not showing.
     - Each transition is verified once, in the page object, instead of in every test.
     - When the flow changes, for example login now lands on onboarding, the method's return type changes and the compiler names every test the change affects.
   - Name methods by their outcome: `loginAndOpenDashboard()` returns the dashboard's page object; `loginExpectingError(message)` stays on the screen, asserts the error and returns nothing.
   - An action-only variant that returns nothing is allowed only where the user stays on the same screen.
   - Every page object has a `verifyLoaded()` that asserts the landmarks only its screen shows. Constructors never wait.

6. **Assert the state before the action, not just after it.**
   - Before a create, assert the item is absent. Before a delete, assert it is present. Before an update, assert the old value.
   - A test that checks only the end state passes on leftover data, and it passes when the action did nothing.

7. **Never force an action, and never retry one that has a side effect.**
   - Act as a user does, through real input events: tap, click, type, swipe, press keys. Never call handlers or app code directly to get past a control.
   - Forcing an action skips the checks that catch overlays, disabled controls and elements that are not on screen: exactly the bugs these tests exist for.
   - If a real tap, click or keystroke does not take, the app has a defect, such as a handler attached late or a field that drops input. Fix the app.
   - While a fix is pending, an idempotent pair may be retried as a unit, such as opening a menu and asserting it is open.
   - Never retry a submit, create or delete. Retrying it repeats the action.

8. **Page objects are full of sanity checks, so a failure names its real cause.**
   - A page object checks its assumptions at every step, not only at the end. Put them everywhere:
     - At the start of every method, check that the page object's own screen or modal is still showing.
     - Before acting, check that the target is visible and enabled.
     - Before filling, check that the field holds the old value. After filling, check that it holds the new one.
     - Before submitting, check that no validation error is showing.
     - After moving to another screen, call its `verifyLoaded()`.
   - Without these checks, the real cause shows up much later as a timeout on something unrelated. The modal closed, the session expired or an error appeared, and the test reports "Save button not found" three steps on. A sanity check fails at the first wrong step, and says which step it was.
   - They cost almost nothing. A polling assertion passes at once when the state is right, so add them freely. Repetition is fine here, because it lives in page objects and never in tests.
   - A sanity check is a polling assertion like any other (rule 4). It is never an `if` on a one-off read.
   - A check that fails says what the screen showed instead. For example: "Group 'Rent' did not appear within 5s; visible groups: [Food, Travel]". Or it names the screen that is showing and the error message on it.
   - Timeouts are named constants in one file, by kind: navigation, element, modal.
   - Raising a timeout never fixes a flaky test.

9. **Stub at the boundary, before the app asks.**
   - Replace what lies outside the app (the network, and on a device the system services) at its boundary. Never mock the project's own components, hooks, view models or modules.
   - Stub bodies are typed or validated by the client's own models or schemas, so they cannot drift from the contract. Test data comes from builders.
   - Register stubs before the app asks for the data: before navigation, or before launch.
   - To simulate a server change partway through a test:
     1. Replace the stub.
     2. Trigger the event the app listens for.
     3. Wait for the screen to show the change.

10. **A flaky test is a failing test.**
    - Run with automatic retries off.
    - A test that passed on a second attempt is broken, and the cause is one of the rules above.
    - After fixing a timing failure, run the test repeatedly, for example twenty times, and report the count that passed.

### Departing from these rules

There is no departure from rules 3, 4 and 7. Any other departure needs a comment at the site that says:

- which rule it breaks
- why the compliant form cannot work there
- what would remove the need for it

Anything else is a violation, and a review fixes it.

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

### Not the model

super-funmax-music's UI tests are the nearest the fleet has. These parts of them break the rules. Do not copy them:

- There are no page objects. Its 53 tests sit in two `XCTestCase` classes beside private helpers, and the tests query `app` directly.
- `firstMatch` 140 times and `element(boundBy:)` 51 times.
- About half of its lookups use accessibility identifiers, such as `"role-host"` and `"questionType-wordSearch"`, through the query subscript and `matching(identifier:)`.
- `XCTAssertTrue(….exists)` 15 times: a snapshot read asserted once (rule 4).
- `Snapshots.swift` polls the frame and the screen in a loop with `Thread.sleep` between reads.

*Generated from `npomfret/agent-standards`. Edit the standard there, not this copy.*
