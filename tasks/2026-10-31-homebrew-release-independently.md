# Prove Homebrew releases independently of TestFlight

Status: open. Moved out of task 38 by the owner on 31 October 2026.

Homebrew is a separate flow from Apple delivery, with its own trigger, credentials and cadence, and
its version and build numbers need not match Apple's. Nothing has proven that yet: it has not
released since the two were separated, and both the GitHub release and the cask are still at v1.1.4
from 2026-09-09.

Facts carried over:

- The entry point is `scripts/ship-homebrew.sh`.
- A Homebrew release still needs App Store Connect to choose its build number.
- There is no TeamCity configuration for it, and `ci-publish.sh --platform homebrew` has not run on
  an agent. It clones its tap into the run's `TMPDIR`; that clone has been inspected, not run.
- The agents were last seen without a Developer ID Application identity on 2026-09-10, not re-read
  since. The laptop's certificate expires on 2027-02-01.

- [ ] Release once through `scripts/ship-homebrew.sh` from the laptop, on its own version and
  cadence, with no Apple delivery involved. A release needs the owner's explicit go-ahead.
- [ ] Confirm the notarized zip, the GitHub release and the cask all reached users.
