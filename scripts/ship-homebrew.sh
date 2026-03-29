#!/usr/bin/env bash
set -euo pipefail

# Wrapper around release-mac.sh for Homebrew / Developer ID distribution.
# Uses the keychain profile "no-spoilers-notarytool" for notarization.
#
# Usage:
#   scripts/ship-homebrew.sh          # auto-increments version
#   scripts/ship-homebrew.sh 1.2.0    # explicit version

exec "$(dirname "$0")/release-mac.sh" \
  --channel developer-id \
  "$@"
