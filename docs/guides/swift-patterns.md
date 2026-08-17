# Swift Patterns Guide

Canonical pattern-governance guide for Swift and Apple-platform code in this repo.

## Core rules

- One concern should have one approved implementation pattern.
- Before editing, inspect the nearest existing implementation that solves the same concern.
- Reuse or refactor that pattern instead of creating a second style.
- If no approved pattern exists yet, stop and propose the standard before implementing it broadly.

## Refactoring bias

- Prefer converging existing code onto one shared boundary over adding another layer beside it.
- If two implementations are trying to solve the same problem, the default move is to consolidate them.
- Extract shared behavior when duplication is real; do not cargo-cult abstractions before a shared contract exists.

## Encapsulation

- Keep domain logic out of UI composition when a shared model, service, or state boundary is the established pattern.
- Keep I/O boundaries explicit.
- Prefer small, named types with one responsibility over large mixed-purpose files.
- Do not create one-off `Manager`, `Helper`, `Util`, or `Service` types when an approved boundary already exists for that concern.

## Apple-platform consistency

- Keep macOS and iOS behavior aligned when they share the same product contract.
- Call out intentional platform differences explicitly.
- Do not silently mix architectural styles within the same feature area.

## Strings and localisation

- Every user-visible string must live in the target's `Strings.swift`, not inline in view or model code.
- Static strings use `LocalizedStringKey` (for `Text`/`Button` in SwiftUI) or `LocalizedStringResource` (for AppIntents protocol requirements).
- Dynamic strings (countdowns, "Round N", plurals) are format functions on the relevant `Strings` enum. Never interpolate a user-visible string directly in view or model code.
- Shared strings that cross target boundaries belong in `NoSpoilersCore/Sources/NoSpoilersCore/Strings.swift` under the appropriate `public enum` namespace.
- Target-private strings belong in the target's own `Strings.swift` (`NoSpoilers/`, `NoSpoilersMac/`, `NoSpoilersWidget/`).
- Hardcoding a user-visible string outside `Strings.swift` is a correctness violation, not a style issue.
- Infrastructure strings (API query parameters, storage keys, window IDs, log subsystems, plist keys, enum raw values) are not user-visible and do not belong in `Strings.swift`.

## Networking

- **Every request goes through `HTTPSession.shared`, and `URLSession.shared` is not used.** It is
  ephemeral (`ScheduleFetcher` runs in the widget extension, where Apple advises against `.shared`)
  and bounded at 8s idle / 20s total. Two of the three fetch sites used to inherit Apple's 60s / 7d
  by saying nothing at all, which reads as a decision nobody made. A site that needs different
  numbers builds its own session and writes down why; inheriting defaults by omission is not an
  option. `HTTPSessionTests` is what makes this executable rather than advisory.
- **Call `try response.requireSuccess()` between every request and its decode.** Without it a 503's
  error page reaches a `JSONDecoder` and is reported as a schema change, which sends the next reader
  of the trace to entirely the wrong place. All three fetch sites do this; a fourth that does not is
  a correctness bug, not an omission.
- **A failure throws; `nil` means the query worked and the answer was empty.** Never collapse the
  two. `OpenF1Client` returned the same `nil` for "OpenF1 is down" and "the record is not published
  yet", and its poller answered both by retrying every 120 seconds forever, silently.
- `throws` is the error style for this package — `ScheduleFetcher`, `ScheduleCache`, `OpenF1Client`.
  Do not introduce `Result` or a per-client error protocol beside it.
- **Build query URLs already percent-encoded, and reject any string `URL(string:)` rewrites.**
  Foundation runs an encoding fixup over a string that is not already a valid URL, which
  double-encodes anything you encoded yourself. See `OpenF1Client.url(_:)` and the comment above it
  for the year of silently-failed lookups this cost.
- Check what an API actually returns for "nothing" before treating a status as a failure. OpenF1
  answers an empty result set with **404**, so a blanket status check would log its most routine
  answer as an error.

## Logging

- **Every log line is one JSON object, written through `LogChannel`.** No string concatenation,
  no interpolated prose, no `print`. We log data, not sentences.
- Use the channels on `AppLog` (`launch`, `schedule`, `cache`, `store`, `widget`, `session-end`).
  Do not construct a `Logger` directly — `LogChannel` holds the only one, which is what makes the
  rule enforceable rather than advisory.
- `msg` is a `StaticString` on purpose, so `notice("weekends → \(count)")` does not compile. Put the
  value in a field.
- **Levels decide whether a line still exists tomorrow.** `.notice` is written to the log store and
  is the default for a state change; `.debug` is discarded unless something is streaming; `.error`
  is a failure and only a failure. **`.info` is not offered** — it does not persist, and two
  experiments were once scored wrongly because the line they depended on had evaporated. See
  `tasks/19-widget-timeline-too-large.md`.
- Log a domain type by conforming it to `LogRepresentable`, not by picking its fields apart at the
  call site. `LogValue` is a closed enum with no `case any(Any)` so that everything reaching a trace
  went through a conformance somebody wrote deliberately.
- **Names and kinds go out in the feed's vocabulary, not the user's language** — `name`, not
  `grandPrixName`; `kind.rawValue`, not `displayName`. A trace has to match the fixture that
  produced it and be readable beside one captured on a device in another language.
- The spoiler rule applies to logs exactly as it applies to storage: a line carries schedule
  identity and timing, and nothing else.

## Naming

- Name types and modules after their real scope today, not a speculative future abstraction.
- Generic names are only acceptable after a real shared contract is established.
