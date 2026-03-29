#!/usr/bin/env bash
set -euo pipefail

# Release to both Homebrew and the Mac App Store in one run.
# Bumps the version once, archives once, exports and distributes to both channels.
#
# Usage:
#   scripts/ship.sh          # auto-increments version
#   scripts/ship.sh 1.2.0    # explicit version

exec "$(dirname "$0")/release-mac.sh" \
  --channel both \
  --api-key "${HOME}/.appstoreconnect/private_keys/AuthKey_S394C74APG.p8" \
  --api-key-id S394C74APG \
  --api-issuer 69a6de6e-6d3e-47e3-e053-5b8c7c11a4d1 \
  "$@"
