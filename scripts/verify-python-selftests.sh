#!/usr/bin/env bash
set -euo pipefail

# Every offline selftest the Python here carries, in one command.
#
# There are six and there was no way to run them together, so "did I break the
# other one" was answered by remembering which scripts have a `--selftest` —
# which stopped being a reasonable thing to remember when `asc_write.py` was
# split out of `testflight_distribute.py` and the two started sharing a key,
# and again when `appstore_listing.py` became the third writer of the same app
# record.
#
# Offline and stdlib-only, like the scripts themselves. Nothing here talks to
# App Store Connect, so it is safe at any time and needs no key.
#
# `scripts/teamcity.py` is deliberately not in the list. It has no selftest of
# its own: it finds the shared TeamCity plugin on the machine and runs that
# plugin's selftest, which checks code kept in npomfret/agent-standards, not
# here. Listing it turned `Checks` red on every agent without the plugin
# installed (2026-09-06, builds 74 to 76), which is a dependency on
# machine state the CI chain is built to be free of.

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

status=0
for script in appstore_status testflight_distribute tag_approved appstore_listing appstore_screenshots ci_health; do
  if ! python3 "scripts/${script}.py" --selftest; then
    status=1
  fi
done

exit "$status"
