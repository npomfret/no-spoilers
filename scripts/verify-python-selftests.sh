#!/usr/bin/env bash
set -euo pipefail

# Every offline selftest the Python here carries, in one command.
#
# There are four and there was no way to run them together, so "did I break the
# other one" was answered by remembering which scripts have a `--selftest` —
# which stopped being a reasonable thing to remember when `asc_write.py` was
# split out of `testflight_distribute.py` and the two started sharing a key,
# and again when `appstore_listing.py` became the third writer of the same app
# record.
#
# Offline and stdlib-only, like the scripts themselves. Nothing here talks to
# App Store Connect, so it is safe at any time and needs no key.

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

status=0
for script in appstore_status testflight_distribute appstore_listing ci_health; do
  if ! python3 "scripts/${script}.py" --selftest; then
    status=1
  fi
done

exit "$status"
