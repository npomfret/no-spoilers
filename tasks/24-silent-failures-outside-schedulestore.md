# Task 24: three silent failures the logging pass did not reach

**Status: DONE 2026-08-17. All three.**

**3 was decided rather than patched: there is no freshness contract, so `isFresh`, `cacheTTL` and
`testIsFresh` are gone.** The architecture had already answered it — `refresh()` saves
unconditionally, the widget draws whatever it finds at any age, and it has to, because a widget that
will not render without the network shows grey bars (task 19). Keeping a TTL nothing enforced was
implying a rule the app does not follow, and the sentinel inside it was converting the one failure
that breaks the widget completely into "the cache is stale". `cachedAt` stays in the envelope, and
`testTheEnvelopeStampsWhenItWasWritten` replaces the old test — the field now has no reader in
product code, and without an assertion it is one tidy-up away from being deleted as dead weight.
`docs/guides/important-code.md` no longer describes the screenshot rule in terms of `isFresh`.

**What looking for the silent failures actually found.** Item 1 was filed as a diagnosability
problem: the client could not say *why* a lookup came back empty. Making it say so exposed that for
four of the seven session kinds the lookup had never once succeeded. `URL(string:)` re-encodes an
already-encoded string when the rest of the string is not a valid URL, and the bare `>` in OpenF1's
filter syntax made it not valid — so `session_name=Practice%201` went out as `Practice%25201`, which
OpenF1 answers with "no results", which this client reported as "not published yet". Practice 1,
Practice 2, Practice 3 and Sprint Qualifying could never be confirmed. Race, Sprint and Qualifying
worked, and only because their names contain no space.

Confirmed against the live API rather than reasoned about:

```
session_name=Practice%201    → session_key 9686, and its SESSION FINISHED record
session_name=Practice%25201  → HTTP 404 {"detail":"No results found."}
```

The second one is what the app has been sending. The bug was invisible for precisely the reason this
task exists: **OpenF1 answers a malformed query exactly as it answers an empty one**, and the poller
answers both by trying again in two minutes.

A second thing the live check settled, which would have made the fix worse than the bug: OpenF1
returns **404** for an empty result set, not `200 []`. A blanket status check would have logged the
most routine answer in the feature — "not published yet", which is every poll for the first thirty
minutes — at `.error`. `OpenF1Client.get` treats 404 as emptiness deliberately and says so.

**What was done**

- `URLResponse.requireSuccess()` in `HTTPStatus.swift`, called at all four decode sites (both
  OpenF1 queries, both `ScheduleFetcher` fetches). Nothing in the app checked an HTTP status before
  this. Pure, so it is unit-tested without a stubbed `URLProtocol`.
- `OpenF1Client` throws for a failed lookup and returns `nil` only for a genuinely empty answer.
  URLs are built already percent-encoded and `url(_:)` **refuses anything Foundation would rewrite**,
  which is what stops the double-encoding class of bug returning. `?? ""` on the session name is
  gone with it.
- `SessionEndConfirmer.fetchAndStore` catches and logs at `.error`. It still retries either way — a
  transient outage should not abandon a session about to be confirmed — but the two reasons for
  retrying are now different lines.
- `UpdateChecker` logs both outcomes on a new `AppLog.update` channel. No UI for "could not check";
  that remains a product decision and is not assumed here.
- `docs/guides/swift-patterns.md` gained a Networking section, so the next fetch site inherits this
  rather than rediscovering it.

**Evidence.** `scripts/verify-core-tests.sh` 58 tests / 0 failures, up from 47. All three build
wrappers `BUILD SUCCEEDED`. The new tests were mutation-checked: restoring the bare `>` kills 3,
widening the success range to `200..<600` kills 3, dropping the pass-through guard kills 1. The
first version of that last one killed nothing, which is how the guard came to have a test of its own.

**Not done, deliberately.** `OpenF1Client` still uses `URLSession.shared` with default timeouts,
while `ScheduleFetcher` uses an ephemeral session with an 8-second request timeout and a written
reason. That is real drift between two clients in one package, but it is a different question from
this one and nothing here depends on it.

---

**What follows is the case as it was filed, before any of the above.**

**Found on 2026-08-17 while wiring `LogChannel` through the app, by grepping `try?` across product
code once every log line had somewhere to go.**

The auditing pass fixed the two silent failures in `ScheduleStore` — the cache save in `refresh()`
and the cache load in `init()`, both of which discarded an error with `try?`. Three more survive
outside it. They were left alone deliberately: each is a behaviour question, not a logging one, and
answering them inside a commit about log formatting would have buried the decision.

## 1. `OpenF1Client` swallows four failures in a row

`OpenF1Client.swift:46-47` and `:63-64`. Both methods are a single `guard` with `try?` on the
request and `try?` on the decode, so a network error, an HTTP error status, a schema change and an
empty result all produce the same `nil`.

This is the whole session-end confirmation feature. `SessionEndConfirmer` polls every 120 seconds
for a session in its overrun window, and on `nil` it comes back in two minutes and tries again —
**forever, without ever saying why**. The two `.debug` lines added on 2026-08-17 record that the
lookup came back empty; they cannot record whether OpenF1 is down, has changed its schema, or simply
does not have the record yet, because the client no longer knows by the time it returns.

The response status is not checked at all: `let (data, _) = try? await URLSession.shared.data(...)`
discards the `URLResponse`. A 503 body that fails to decode is indistinguishable from a 200 with no
sessions in it.

**Note the asymmetry before choosing a fix.** A missing `SESSION FINISHED` record is genuinely
ordinary — the free tier publishes it roughly 30 minutes late, which is the entire reason the poller
exists — so this is not a case for the fail-fast rule. It is a case for the client returning
something that distinguishes *not yet* from *broken*, and for the broken branch reaching a log at
`.error`. A `Result`, or a small enum with a `notYetPublished` case, would do it.

## 2. `UpdateChecker` fails silently, and the failure is invisible by design

`NoSpoilers/NoSpoilersMac/UpdateChecker.swift:25-26`. Same shape: `try?` on the GitHub fetch, `try?`
on the decode, `return` on either.

The consequence is specific to what this drives. A successful check with no new release and a check
that never completed both leave `isUpdateAvailable == false`, which shows **nothing** in the menu
bar. There is no visible difference between "you are up to date" and "this app has not successfully
checked in three months", and the second one is how a Mac user stays on an old build indefinitely.
Sparkle-less update checking only works if the check itself is observable.

At minimum this wants the two failures logged at `.error` on a channel. Whether the UI should ever
say "could not check" is a product decision and is not assumed here.

## 3. `ScheduleCache.isFresh` is dead code containing a sentinel

`ScheduleCache.swift:27-33`:

```swift
guard let data = try? Data(contentsOf: (try? cacheFileURL(for: appGroupID)) ?? URL(fileURLWithPath: "")) else { return false }
```

Two problems, and the second is why this is filed rather than fixed in passing.

- **`?? URL(fileURLWithPath: "")` is a sentinel**, which the root contract forbids outright: "Fail
  loudly for impossible missing data. Never hide it with defaults, sentinels, or optionality." It
  converts "the App Group container is unavailable" — a misconfigured entitlement, the one failure
  that breaks the widget completely — into a read of the empty path, which fails, which returns
  `false`, which reads as "the cache is stale". The caller then refetches and everything looks
  normal. `load` and `save` on the same type both `throw` `ScheduleCacheError.containerUnavailable`
  properly; only this method opts out.
- **Nothing calls it.** `grep -rn isFresh` finds the declaration and one assertion in
  `ScheduleCacheTests.swift:27`. It is `public`, so it is package API with a test and no consumer,
  and the test is what has been keeping it alive.

**The decision to make is whether `cacheTTL` is meant to be enforced anywhere.** `ScheduleCache`
writes `cachedAt` into every envelope and defines a 24-hour `cacheTTL`, and neither is read by
product code — the widget uses the cache whenever it is non-empty, at any age, which is correct for
a widget that must draw something without the network. If the TTL is genuinely unused policy, delete
`isFresh`, `cacheTTL`, and the test with them, and stop implying a freshness contract the app does
not have. If it is meant to be enforced, this method needs a caller and needs to throw like its
neighbours. Do not just patch the sentinel and leave it uncalled.

## Verification

`scripts/verify-core-tests.sh` covers `ScheduleCache` and would cover a changed `OpenF1Client`
contract. Deleting `isFresh` means deleting `testIsFreshWithinTTL` — check first whether it is the
only thing asserting that `cachedAt` is written at all, and keep that assertion somewhere if so.

## Related

- `tasks/19-widget-timeline-too-large.md` — why the widget's failures have to be readable after the
  fact rather than live
- `docs/guides/swift-patterns.md`, "Logging" — the levels, and why `.error` means a failure only
