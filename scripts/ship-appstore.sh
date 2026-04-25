#!/usr/bin/env bash
set -euo pipefail

# Partial: ship only the macOS App Store channel (skip Homebrew + iOS).
# For full sync use scripts/ship.sh.
#
# Usage:
#   scripts/ship-appstore.sh          # auto-increments version
#   scripts/ship-appstore.sh 1.2.0    # explicit version

exec "$(dirname "$0")/release.sh" \
  "$@" \
  --platform macos \
  --channel app-store \
  --api-key "${HOME}/.appstoreconnect/private_keys/AuthKey_S394C74APG.p8" \
  --api-key-id S394C74APG \
  --api-issuer 69a6de6e-6d3e-47e3-e053-5b8c7c11a4d1
