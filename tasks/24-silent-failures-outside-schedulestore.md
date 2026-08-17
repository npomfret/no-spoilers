# Task 24: three silent failures the logging pass did not reach

**Status: OPEN. Found on 2026-08-17 while wiring `LogChannel` through the app, by grepping `try?`
across product code once every log line had somewhere to go.**

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
