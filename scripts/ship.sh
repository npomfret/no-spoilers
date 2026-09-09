#!/usr/bin/env bash
set -euo pipefail

# Ship everything in one run with a single synchronized version:
#   1. macOS App Store     → signed pkg     → App Store Connect upload
#   2. macOS Developer ID  → notarized zip  → GitHub release → Homebrew tap
#   3. iOS App Store       → signed ipa     → App Store Connect upload
#
# Every platform is shipped on every run, even when it has no source changes,
# so all distribution channels stay version-locked — build number included. The
# number is chosen here, once, from App Store Connect via `next_build_number`,
# and passed to both invocations. Left to itself each invocation asks for the
# next number again, which is how 1.1.1 came to be build 10001 on macOS and
# 10002 on iOS: one version, two builds, and the claim above quietly untrue.
# The macOS run writes `build/N` on the commit and the iOS run finds it there.
#
# Anything after the version is passed to both `release.sh` invocations
# unchanged, which is how `ci-publish.sh` hands this the credentials a build
# agent needs and a laptop does not. Same passthrough as `ship-ios.sh` and
# `ship-appstore.sh`, for the same reason: the flags belong to `release.sh` and
# repeating them here is how they come to differ from it.
#
# Usage:
#   scripts/ship.sh                    # auto-increments version, prompts
#   scripts/ship.sh 1.2.0              # explicit version, no prompt
#   scripts/ship.sh 1.2.0 --signing-key ...   # and these reach release.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_version.sh"

if [[ $# -gt 0 ]]; then
  VERSION="$1"
  shift
else
  # `suggest_next_version` used to be the default here, and it is the answer to
  # a different question — see `version_to_ship`. It offered 1.1.5 on the day
  # 1.1.4 was open, untagged and taking builds, which is a version skipped by
  # pressing Enter.
  #
  # Tags first, because the answer skips versions already tagged.
  git fetch --quiet --tags origin
  echo "==> Asking App Store Connect which version is still taking builds..."
  # `all`, not one call per platform: **one version on all three channels is
  # the whole point of this script**, and the function refuses to answer when
  # the two platforms disagree.
  SUGGESTED="$(version_to_ship all)" \
    || { echo "So pass the one you mean: $0 X.Y.Z" >&2; exit 1; }
  read -rp "Version [${SUGGESTED}]: " INPUT
  VERSION="${INPUT:-$SUGGESTED}"
fi

echo "==> Asking App Store Connect for the next build number..."
BUILD="$(next_build_number)"

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
  --api-issuer "${API_ISSUER}" \
  "$@"

echo ""
echo "==> Shipping iOS (app-store) v${VERSION} build ${BUILD}..."
"${SCRIPT_DIR}/release.sh" "${VERSION}" \
  --platform ios \
  --channel app-store \
  --build "${BUILD}" \
  --api-key "${API_KEY}" \
  --api-key-id "${API_KEY_ID}" \
  --api-issuer "${API_ISSUER}" \
  "$@"

echo ""
echo "Done. v${VERSION} shipped to Homebrew, Mac App Store, iOS App Store."
