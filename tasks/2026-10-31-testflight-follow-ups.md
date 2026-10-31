# TestFlight delivery follow-ups

Status: open. What outlived task 38 when it closed on 31 October 2026.

- [ ] **Owner:** confirm `~/Desktop/certs.p12`, which held two signing private keys, is gone from the
  Mac Studio. It is not on the laptop; the Mac Studio was not read.
- [ ] The portal held 292 Xcode-managed profiles for this bundle id on 2026-09-10. Not re-read since.
  Understand the churn, and prune if needed, before it becomes a limit.
- [ ] Add the lessons to `agent-standards` and Funmax: Funmax's `Ship` timeout was under its own step
  limits on 2026-09-10; Xcode writes `.xcdistributionlogs` to `getconf DARWIN_USER_TEMP_DIR` and
  ignores `TMPDIR`; an artifact rule for a directory needs `/**`; a new keychain key needs its
  partition list set before a background agent can use it.
