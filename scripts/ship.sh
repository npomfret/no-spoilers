#!/usr/bin/env bash
set -euo pipefail

# Ship everything in one run with a single synchronized version:
#   1. macOS App Store     → signed pkg     → App Store Connect upload
#   2. macOS Developer ID  → notarized zip  → GitHub release → Homebrew tap
#   3. iOS App Store       → signed ipa     → App Store Connect upload
#
# Every platform is shipped on every run, even when it has no source changes,
# so all distribution channels stay version-locked — build number included. The
# number is chosen here, once, and passed to both invocations. Left to itself
# each invocation bumps the project again, which is how 1.1.1 came to be build
# 10001 on macOS and 10002 on iOS: one version, two builds, and the claim above
# quietly untrue.
#
# Usage:
#   scripts/ship.sh          # auto-increments version
#   scripts/ship.sh 1.2.0    # explicit version

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_version.sh"

if [[ $# -gt 0 ]]; then
  VERSION="$1"
else
  SUGGESTED=$(suggest_next_version)
  read -rp "Version [${SUGGESTED}]: " INPUT
  VERSION="${INPUT:-$SUGGESTED}"
fi

BUILD=$(( $(current_build_number) + 1 ))

API_KEY="${HOME}/.appstoreconnect/private_keys/AuthKey_S394C74APG.p8"
API_KEY_ID="S394C74APG"
API_ISSUER="69a6de6e-6d3e-47e3-e053-5b8c7c11a4d1"

echo "==> Shipping macOS (app-store + developer-id) v${VERSION} build ${BUILD}..."
"${SCRIPT_DIR}/release.sh" "${VERSION}" \
  --platform macos \
  --channel both \
  --build "${BUILD}" \
  --api-key "${API_KEY}" \
  --api-key-id "${API_KEY_ID}" \
  --api-issuer "${API_ISSUER}"

echo ""
echo "==> Shipping iOS (app-store) v${VERSION} build ${BUILD}..."
"${SCRIPT_DIR}/release.sh" "${VERSION}" \
  --platform ios \
  --channel app-store \
  --build "${BUILD}" \
  --api-key "${API_KEY}" \
  --api-key-id "${API_KEY_ID}" \
  --api-issuer "${API_ISSUER}"

echo ""
echo "Done. v${VERSION} shipped to Homebrew, Mac App Store, iOS App Store."
