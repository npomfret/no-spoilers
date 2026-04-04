#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   Interactive:  scripts/release-mac.sh
#   Explicit:     scripts/release-mac.sh 1.0.0
#
# Channels (--channel, default: developer-id):
#
#   developer-id  Notarized zip → GitHub release → homebrew tap
#     --notarytool-key /path/to.p8 --notarytool-key-id KEY_ID --notarytool-issuer ISSUER_ID
#     (omit flags to use keychain profile "no-spoilers-notarytool")
#
#   app-store     Signed pkg → App Store Connect upload
#     --api-key /path/to.p8 --api-key-id KEY_ID --api-issuer ISSUER_IDfor the old "grey"
#     (omit flags to print manual upload instructions)
#
#   both          Runs developer-id then app-store from the same archive

# ── Version ─────────────────────────────────────────────────────────────────

if [[ $# -eq 0 ]] || [[ "${1:-}" == --* ]]; then
  LATEST=$(git tag --sort=-v:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -1)
  if [[ -n "$LATEST" ]]; then
    IFS='.' read -r MAJOR MINOR PATCH <<< "${LATEST#v}"
    PATCH=$((PATCH + 1))
    SUGGESTED="${MAJOR}.${MINOR}.${PATCH}"
    while git tag | grep -qx "v${SUGGESTED}"; do
      PATCH=$((PATCH + 1))
      SUGGESTED="${MAJOR}.${MINOR}.${PATCH}"
    done
  else
    SUGGESTED="1.0.0"
  fi
  read -rp "Version [${SUGGESTED}]: " INPUT
  VERSION="${INPUT:-$SUGGESTED}"
else
  VERSION="$1"
  shift
fi

# ── Options ──────────────────────────────────────────────────────────────────

CHANNEL="developer-id"
NOTARYTOOL_KEY=""
NOTARYTOOL_KEY_ID=""
NOTARYTOOL_ISSUER=""
API_KEY=""
API_KEY_ID=""
API_ISSUER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --channel)            CHANNEL="$2";           shift 2 ;;
    --notarytool-key)     NOTARYTOOL_KEY="$2";    shift 2 ;;
    --notarytool-key-id)  NOTARYTOOL_KEY_ID="$2"; shift 2 ;;
    --notarytool-issuer)  NOTARYTOOL_ISSUER="$2"; shift 2 ;;
    --api-key)            API_KEY="$2";            shift 2 ;;
    --api-key-id)         API_KEY_ID="$2";         shift 2 ;;
    --api-issuer)         API_ISSUER="$2";         shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [[ "$CHANNEL" != "developer-id" && "$CHANNEL" != "app-store" && "$CHANNEL" != "both" ]]; then
  echo "Unknown channel: ${CHANNEL} (expected developer-id, app-store, or both)" >&2
  exit 1
fi

# ── Paths ────────────────────────────────────────────────────────────────────

PBXPROJ="NoSpoilers/NoSpoilers.xcodeproj/project.pbxproj"
SCHEME="NoSpoilersMac"
PROJECT="NoSpoilers/NoSpoilers.xcodeproj"
ARCHIVE_PATH="/tmp/NoSpoilersMac-${VERSION}.xcarchive"
EXPORT_PATH_DEVID="/tmp/NoSpoilersMac-devid-export-${VERSION}"
EXPORT_PATH_APPSTORE="/tmp/NoSpoilersMac-appstore-export-${VERSION}"

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

# ── Shared: version bump → commit → push ────────────────────────────────────

echo "==> Bumping MARKETING_VERSION to ${VERSION} in project..."
sed -i '' "s/MARKETING_VERSION = .*;/MARKETING_VERSION = ${VERSION};/g" "${PBXPROJ}"

echo "==> Committing and pushing version bump..."
git add "${PBXPROJ}"
if ! git diff --cached --quiet; then
  git commit -m "bump to v${VERSION}"
  git push
else
  echo "  (version already at ${VERSION}, skipping commit)"
fi

# ── Shared: clean → archive ──────────────────────────────────────────────────

echo "==> Cleaning ${SCHEME}..."
xcodebuild clean \
  -project "${PROJECT}" \
  -scheme "${SCHEME}"

echo "==> Archiving ${SCHEME} v${VERSION}..."
xcodebuild archive \
  -project "${PROJECT}" \
  -scheme "${SCHEME}" \
  -destination "generic/platform=macOS" \
  -archivePath "${ARCHIVE_PATH}" \
  -allowProvisioningUpdates \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM=6FZN56WC8G \
  MARKETING_VERSION="${VERSION}"

# ── Channel: developer-id ────────────────────────────────────────────────────

if [[ "$CHANNEL" == "developer-id" || "$CHANNEL" == "both" ]]; then
  STAPLE_DIR="/tmp/NoSpoilersMac-staple-${VERSION}"
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
    "${EXPORT_PATH_DEVID}/NoSpoilersMac.app" \
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
  xcrun stapler staple "${STAPLE_DIR}/NoSpoilersMac.app"
  rm -f "${ZIP_PATH}"
  ditto -c -k --sequesterRsrc --keepParent \
    "${STAPLE_DIR}/NoSpoilersMac.app" \
    "${ZIP_PATH}"

  echo "==> Verifying staple..."
  xcrun stapler validate "${STAPLE_DIR}/NoSpoilersMac.app"

  echo "==> Computing SHA256..."
  SHA256=$(shasum -a 256 "${ZIP_PATH}" | awk '{print $1}')

  echo ""
  echo "  Zip:    ${ZIP_PATH}"
  echo "  SHA256: ${SHA256}"

  tag_version

  echo "==> Creating GitHub release..."
  gh release create "v${VERSION}" \
    --title "v${VERSION}" \
    --notes "" \
    "${ZIP_PATH}"

  echo "==> Updating homebrew-tap..."
  HOMEBREW_TAP_DIR="$(dirname "$(realpath "$0")")/../../homebrew-tap"
  CASK_FILE="${HOMEBREW_TAP_DIR}/Casks/no-spoilers.rb"
  sed -i '' "s/version \".*\"/version \"${VERSION}\"/" "${CASK_FILE}"
  sed -i '' "s/sha256 \".*\"/sha256 \"${SHA256}\"/" "${CASK_FILE}"
  (cd "${HOMEBREW_TAP_DIR}" && git add Casks/no-spoilers.rb && git commit -m "no-spoilers ${VERSION}" && git push)

  echo ""
  echo "Done (developer-id)! v${VERSION} is live on Homebrew."
fi

# ── Channel: app-store ───────────────────────────────────────────────────────

if [[ "$CHANNEL" == "app-store" || "$CHANNEL" == "both" ]]; then
  PKG_PATH="${EXPORT_PATH_APPSTORE}/NoSpoilersMac.pkg"

  echo "==> Exporting for App Store..."
  xcodebuild -exportArchive \
    -archivePath "${ARCHIVE_PATH}" \
    -exportOptionsPlist "NoSpoilers/ExportOptions-AppStore.plist" \
    -exportPath "${EXPORT_PATH_APPSTORE}" \
    -allowProvisioningUpdates

  echo ""
  echo "  Package: ${PKG_PATH}"

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
      -f "${PKG_PATH}" \
      --type macos \
      --apiKey "${API_KEY_ID}" \
      --apiIssuer "${API_ISSUER}"

    echo "==> Uploading to App Store Connect..."
    xcrun altool --upload-app \
      -f "${PKG_PATH}" \
      --type macos \
      --apiKey "${API_KEY_ID}" \
      --apiIssuer "${API_ISSUER}"

    tag_version

    echo ""
    echo "Done (app-store)! v${VERSION} uploaded. Submit for review in App Store Connect."
  else
    tag_version

    echo ""
    echo "No API key provided. Upload the package manually:"
    echo "  xcrun altool --upload-app -f '${PKG_PATH}' --type macos \\"
    echo "    --apiKey KEY_ID --apiIssuer ISSUER_ID"
    echo "  Or drag '${PKG_PATH}' into Transporter.app"
    echo ""
    echo "Then submit for review in App Store Connect."
  fi
fi
