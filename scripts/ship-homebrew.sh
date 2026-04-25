#!/usr/bin/env bash
set -euo pipefail

# Partial: ship only the macOS Developer ID / Homebrew channel (skip App Store + iOS).
# Uses the keychain profile "no-spoilers-notarytool" for notarization.
# For full sync use scripts/ship.sh.
#
# Usage:
#   scripts/ship-homebrew.sh          # auto-increments version
#   scripts/ship-homebrew.sh 1.2.0    # explicit version

exec "$(dirname "$0")/release.sh" \
  "$@" \
  --platform macos \
  --channel developer-id
