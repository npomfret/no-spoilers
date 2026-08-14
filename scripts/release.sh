#!/usr/bin/env bash
set -euo pipefail

# Apple-bundled tools must win PATH lookup over any Homebrew overrides.
# Xcode's IPA distribution pipeline shells out to a "server-side" rsync via
# PATH; if Homebrew has installed rsync 3.x, it's picked up and doesn't
# recognise Apple's -E (extended-attributes) flag, breaking
# IDEDistributionCreateIPAStep with "Copy failed".
export PATH="/usr/bin:/bin:${PATH}"

# Single-platform/single-channel release engine.
#
# Usage:
#   Interactive:  scripts/release.sh
#   Explicit:     scripts/release.sh 1.0.0
#
# Platforms (--platform, required):
#
#   macos  Builds the NoSpoilers scheme for macOS. Supports developer-id, app-store, both.
#   ios    Builds the NoSpoilersApp scheme for iOS. Supports app-store only.
#
# Channels (--channel, required):
#
#   developer-id  Notarized zip → GitHub release → homebrew tap (macos only)
#     --notarytool-key /path/to.p8 --notarytool-key-id KEY_ID --notarytool-issuer ISSUER_ID
#     (omit flags to use keychain profile "no-spoilers-notarytool")
#
#   app-store     Signed pkg/ipa → App Store Connect upload
#     --api-key /path/to.p8 --api-key-id KEY_ID --api-issuer ISSUER_ID
#     (omit flags to print manual upload instructions)
#
#   both          Runs app-store then developer-id from the same archive (macos only)
#
# Build number (--build, optional):
#
#   Use the given CURRENT_PROJECT_VERSION instead of bumping the project's own.
#   ship.sh passes it so one ship run is one build number on every platform.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_version.sh"

# ── Version ─────────────────────────────────────────────────────────────────

if [[ $# -eq 0 ]] || [[ "${1:-}" == --* ]]; then
  SUGGESTED=$(suggest_next_version)
  read -rp "Version [${SUGGESTED}]: " INPUT
  VERSION="${INPUT:-$SUGGESTED}"
else
  VERSION="$1"
  shift
fi

# ── Options ──────────────────────────────────────────────────────────────────

# No defaults. Both are required, because the only safe default was the wrong
# one: bare `release.sh` used to ship macOS Developer ID, so asking for nothing
# shipped the add-on channel. Every caller in scripts/ passes both explicitly,
# so requiring them costs nothing and removes a way to ship the wrong thing.
PLATFORM=""
CHANNEL=""
FORCED_BUILD=""
NOTARYTOOL_KEY=""
NOTARYTOOL_KEY_ID=""
NOTARYTOOL_ISSUER=""
API_KEY=""
API_KEY_ID=""
API_ISSUER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --platform)           PLATFORM="$2";          shift 2 ;;
    --channel)            CHANNEL="$2";           shift 2 ;;
    --build)              FORCED_BUILD="$2";      shift 2 ;;
    --notarytool-key)     NOTARYTOOL_KEY="$2";    shift 2 ;;
    --notarytool-key-id)  NOTARYTOOL_KEY_ID="$2"; shift 2 ;;
    --notarytool-issuer)  NOTARYTOOL_ISSUER="$2"; shift 2 ;;
    --api-key)            API_KEY="$2";            shift 2 ;;
    --api-key-id)         API_KEY_ID="$2";         shift 2 ;;
    --api-issuer)         API_ISSUER="$2";         shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

case "$PLATFORM" in
  macos|ios) ;;
  "") echo "--platform is required (macos or ios)" >&2; exit 1 ;;
  *) echo "Unknown platform: ${PLATFORM} (expected macos or ios)" >&2; exit 1 ;;
esac

case "$CHANNEL" in
  developer-id|app-store|both) ;;
  "") echo "--channel is required (developer-id, app-store, or both)" >&2; exit 1 ;;
  *) echo "Unknown channel: ${CHANNEL} (expected developer-id, app-store, or both)" >&2; exit 1 ;;
esac

if [[ "$PLATFORM" == "ios" && "$CHANNEL" != "app-store" ]]; then
  echo "iOS only supports --channel app-store (got: ${CHANNEL})" >&2
  exit 1
fi

if [[ -n "$FORCED_BUILD" && ! "$FORCED_BUILD" =~ ^[0-9]+$ ]]; then
  echo "--build must be a whole number (got: ${FORCED_BUILD})" >&2
  exit 1
fi

# ── Platform-derived values ─────────────────────────────────────────────────

if [[ "$PLATFORM" == "macos" ]]; then
  SCHEME="NoSpoilers"
  DESTINATION="generic/platform=macOS"
  PRODUCT_BASENAME="NoSpoilersMac"
  EXPORTED_APP_NAME="NoSpoilersMac.app"
  APPSTORE_PACKAGE_NAME="NoSpoilersMac.pkg"
  ALTOOL_TYPE="macos"
else
  SCHEME="NoSpoilersApp"
  DESTINATION="generic/platform=iOS"
  PRODUCT_BASENAME="NoSpoilersApp"
  EXPORTED_APP_NAME="NoSpoilersApp.app"
  APPSTORE_PACKAGE_NAME="NoSpoilersApp.ipa"
  ALTOOL_TYPE="ios"
fi

# ── Paths ────────────────────────────────────────────────────────────────────

PBXPROJ="NoSpoilers/NoSpoilers.xcodeproj/project.pbxproj"
PROJECT="NoSpoilers/NoSpoilers.xcodeproj"
ARCHIVE_PATH="/tmp/${PRODUCT_BASENAME}-${VERSION}.xcarchive"
EXPORT_PATH_DEVID="/tmp/${PRODUCT_BASENAME}-devid-export-${VERSION}"
EXPORT_PATH_APPSTORE="/tmp/${PRODUCT_BASENAME}-appstore-export-${VERSION}"

# ── Preflight ────────────────────────────────────────────────────────────────
#
# Everything this run needs from outside the repository, checked before anything
# is built, uploaded or published. The Homebrew tap is a sibling checkout that
# nothing here creates or clones; discovering it is missing at the end of the
# run means discovering it after notarization has completed and the GitHub
# release is already public, with no way to finish. Fail loudly, first.

if [[ "$CHANNEL" == "developer-id" || "$CHANNEL" == "both" ]]; then
  HOMEBREW_TAP_DIR="$(dirname "$(realpath "$0")")/../../homebrew-tap"
  CASK_FILE="${HOMEBREW_TAP_DIR}/Casks/no-spoilers.rb"

  if [[ ! -f "${CASK_FILE}" ]]; then
    echo "No Homebrew cask at ${CASK_FILE}" >&2
    echo "The developer-id channel publishes to a sibling homebrew-tap checkout; clone it beside this repo." >&2
    exit 1
  fi
  if ! git -C "${HOMEBREW_TAP_DIR}" rev-parse --git-dir >/dev/null 2>&1; then
    echo "${HOMEBREW_TAP_DIR} is not a git checkout, so the cask update cannot be pushed" >&2
    exit 1
  fi
fi

# ── Helper: idempotent tag ────────────────────────────────────────────────────

tag_version() {
  if ! git tag | grep -qx "v${VERSION}"; then
    echo "==> Tagging v${VERSION}..."
    git tag "v${VERSION}"
    git push origin "v${VERSION}"
  else
    echo "==> v${VERSION} already tagged, skipping."
  fi
}

# ── Shared: version bump ────────────────────────────────────────────────────
#
# Apple requires CFBundleVersion (CURRENT_PROJECT_VERSION) to monotonically
# increase across every upload to App Store Connect, so we always bump it,
# regardless of whether MARKETING_VERSION changed. `--build` pins the number
# instead: ship.sh passes one number to every platform so a single ship run
# produces one build, not one per invocation.

CURRENT_BUILD=$(current_build_number)
if [[ -n "$FORCED_BUILD" ]]; then
  NEW_BUILD="$FORCED_BUILD"
else
  NEW_BUILD=$((CURRENT_BUILD + 1))
fi

echo "==> Setting CURRENT_PROJECT_VERSION ${CURRENT_BUILD} → ${NEW_BUILD}..."
sed -i '' "s/CURRENT_PROJECT_VERSION = ${CURRENT_BUILD};/CURRENT_PROJECT_VERSION = ${NEW_BUILD};/g" "${PBXPROJ}"

echo "==> Bumping MARKETING_VERSION to ${VERSION} in project..."
sed -i '' "s/MARKETING_VERSION = .*;/MARKETING_VERSION = ${VERSION};/g" "${PBXPROJ}"

# ── Shared: clean → archive ──────────────────────────────────────────────────
#
# The bump is edited into the working tree above but is NOT committed or pushed
# until the archive exists. A build failure used to leave a pushed
# "bump to vX (build N)" commit describing an artifact that was never produced,
# and ship.sh calls this engine twice, so one failure could leave two of them.
# The working tree is left dirty on failure on purpose — nothing here reverts a
# file the user may also have been editing.

trap 'echo "" >&2; echo "Release failed before the version bump was committed. ${PBXPROJ} is modified and unpushed; nothing was published." >&2' ERR

echo "==> Cleaning ${SCHEME}..."
xcodebuild clean \
  -project "${PROJECT}" \
  -scheme "${SCHEME}"

echo "==> Archiving ${SCHEME} v${VERSION} (${PLATFORM})..."
xcodebuild archive \
  -project "${PROJECT}" \
  -scheme "${SCHEME}" \
  -destination "${DESTINATION}" \
  -archivePath "${ARCHIVE_PATH}" \
  -allowProvisioningUpdates \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM=6FZN56WC8G \
  MARKETING_VERSION="${VERSION}" \
  CURRENT_PROJECT_VERSION="${NEW_BUILD}"

trap - ERR

# ── Shared: commit → push ────────────────────────────────────────────────────
#
# The archive exists, so the build number is now real and the commit describes
# something. The tag is pushed later by whichever channel runs, and it has to
# point at this commit, so this cannot move any further down.

echo "==> Committing and pushing version bump..."
git add "${PBXPROJ}"
if ! git diff --cached --quiet; then
  git commit -m "bump to v${VERSION} (build ${NEW_BUILD})"
  git push
else
  echo "  (no changes to commit)"
fi

# ── Channel: app-store ───────────────────────────────────────────────────────
#
# The App Store is the core product, so it goes first and Homebrew follows.
# Do not swap these back. Both channels export from the same archive, which is
# already built and valid by this point, but notarization is a multi-minute wait
# on an Apple service — and under `set -e` a notary failure used to kill the run
# before the store upload was ever attempted. In that order the add-on channel
# takes the core product down with it after the expensive work has succeeded.
# This way round, a Homebrew failure still fails the run loudly; it just cannot
# cost you the upload. See tasks/17-release-process-asymmetry.md.

if [[ "$CHANNEL" == "app-store" || "$CHANNEL" == "both" ]]; then
  PACKAGE_PATH="${EXPORT_PATH_APPSTORE}/${APPSTORE_PACKAGE_NAME}"

  echo "==> Exporting for App Store..."
  xcodebuild -exportArchive \
    -archivePath "${ARCHIVE_PATH}" \
    -exportOptionsPlist "NoSpoilers/ExportOptions-AppStore.plist" \
    -exportPath "${EXPORT_PATH_APPSTORE}" \
    -allowProvisioningUpdates

  echo ""
  echo "  Package: ${PACKAGE_PATH}"

  if [[ -n "$API_KEY" ]]; then
    # altool resolves the key by filename from fixed locations; ensure it's there.
    ALTOOL_KEYS_DIR="${HOME}/.appstoreconnect/private_keys"
    ALTOOL_KEY_DEST="${ALTOOL_KEYS_DIR}/AuthKey_${API_KEY_ID}.p8"
    if [[ ! -f "${ALTOOL_KEY_DEST}" ]]; then
      mkdir -p "${ALTOOL_KEYS_DIR}"
      cp "${API_KEY}" "${ALTOOL_KEY_DEST}"
    fi

    echo "==> Validating package..."
    xcrun altool --validate-app \
      -f "${PACKAGE_PATH}" \
      --type "${ALTOOL_TYPE}" \
      --apiKey "${API_KEY_ID}" \
      --apiIssuer "${API_ISSUER}"

    echo "==> Uploading to App Store Connect..."
    xcrun altool --upload-app \
      -f "${PACKAGE_PATH}" \
      --type "${ALTOOL_TYPE}" \
      --apiKey "${API_KEY_ID}" \
      --apiIssuer "${API_ISSUER}"

    tag_version

    echo ""
    echo "Done (app-store / ${PLATFORM})! v${VERSION} uploaded. Submit for review in App Store Connect."
  else
    tag_version

    echo ""
    echo "No API key provided. Upload the package manually:"
    echo "  xcrun altool --upload-app -f '${PACKAGE_PATH}' --type ${ALTOOL_TYPE} \\"
    echo "    --apiKey KEY_ID --apiIssuer ISSUER_ID"
    echo "  Or drag '${PACKAGE_PATH}' into Transporter.app"
    echo ""
    echo "Then submit for review in App Store Connect."
  fi
fi

# ── Channel: developer-id (macos only) ──────────────────────────────────────

if [[ "$CHANNEL" == "developer-id" || "$CHANNEL" == "both" ]]; then
  STAPLE_DIR="/tmp/${PRODUCT_BASENAME}-staple-${VERSION}"
  ZIP_NAME="NoSpoilers-${VERSION}.zip"
  ZIP_PATH="/tmp/${ZIP_NAME}"

  echo "==> Exporting with Developer ID..."
  xcodebuild -exportArchive \
    -archivePath "${ARCHIVE_PATH}" \
    -exportOptionsPlist "NoSpoilers/ExportOptions-DeveloperID.plist" \
    -exportPath "${EXPORT_PATH_DEVID}" \
    -allowProvisioningUpdates

  echo "==> Zipping..."
  ditto -c -k --sequesterRsrc --keepParent \
    "${EXPORT_PATH_DEVID}/${EXPORTED_APP_NAME}" \
    "${ZIP_PATH}"

  echo "==> Notarizing (this takes a few minutes)..."
  if [[ -n "$NOTARYTOOL_KEY" ]]; then
    xcrun notarytool submit "${ZIP_PATH}" \
      --key "${NOTARYTOOL_KEY}" \
      --key-id "${NOTARYTOOL_KEY_ID}" \
      --issuer "${NOTARYTOOL_ISSUER}" \
      --wait
  else
    xcrun notarytool submit "${ZIP_PATH}" \
      --keychain-profile "no-spoilers-notarytool" \
      --wait
  fi

  echo "==> Stapling notarization ticket..."
  rm -rf "${STAPLE_DIR}"
  mkdir -p "${STAPLE_DIR}"
  ditto -x -k "${ZIP_PATH}" "${STAPLE_DIR}"
  xcrun stapler staple "${STAPLE_DIR}/${EXPORTED_APP_NAME}"
  rm -f "${ZIP_PATH}"
  ditto -c -k --sequesterRsrc --keepParent \
    "${STAPLE_DIR}/${EXPORTED_APP_NAME}" \
    "${ZIP_PATH}"

  echo "==> Verifying staple..."
  xcrun stapler validate "${STAPLE_DIR}/${EXPORTED_APP_NAME}"

  echo "==> Computing SHA256..."
  SHA256=$(shasum -a 256 "${ZIP_PATH}" | awk '{print $1}')

  echo ""
  echo "  Zip:    ${ZIP_PATH}"
  echo "  SHA256: ${SHA256}"

  tag_version

  # Guarded so a re-run after a partial failure finishes instead of dying here.
  # `gh release create` refuses an existing release, and by this point the zip
  # has been built, notarized and stapled again — the expensive half of the run.
  if gh release view "v${VERSION}" >/dev/null 2>&1; then
    echo "==> GitHub release v${VERSION} already exists; replacing its asset..."
    gh release upload "v${VERSION}" "${ZIP_PATH}" --clobber
  else
    echo "==> Creating GitHub release..."
    gh release create "v${VERSION}" \
      --title "v${VERSION}" \
      --notes "" \
      "${ZIP_PATH}"
  fi

  # HOMEBREW_TAP_DIR and CASK_FILE were resolved and checked in preflight.
  echo "==> Updating homebrew-tap..."
  sed -i '' "s/version \".*\"/version \"${VERSION}\"/" "${CASK_FILE}"
  sed -i '' "s/sha256 \".*\"/sha256 \"${SHA256}\"/" "${CASK_FILE}"
  (cd "${HOMEBREW_TAP_DIR}" && git add Casks/no-spoilers.rb && git commit -m "no-spoilers ${VERSION}" && git push)

  echo ""
  echo "Done (developer-id)! v${VERSION} is live on Homebrew."
fi
