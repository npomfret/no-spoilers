#!/usr/bin/env bash
set -euo pipefail

# Wrapper around release-mac.sh for App Store distribution.
# The .p8 key is read from its standard location (copied there on first run).
#
# Usage:
#   scripts/ship-appstore.sh          # auto-increments version
#   scripts/ship-appstore.sh 1.2.0    # explicit version

exec "$(dirname "$0")/release-mac.sh" \
  --channel app-store \
  --api-key "${HOME}/.appstoreconnect/private_keys/AuthKey_S394C74APG.p8" \
  --api-key-id S394C74APG \
  --api-issuer 69a6de6e-6d3e-47e3-e053-5b8c7c11a4d1 \
  "$@"
