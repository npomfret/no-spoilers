#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   Interactive:  scripts/release-mac.sh              (prompts for version, suggests next patch)
#   Explicit:     scripts/release-mac.sh 1.0.0
#   CI:           scripts/release-mac.sh 1.0.0 --notarytool-key /path/to.p8 --notarytool-key-id KEY_ID --notarytool-issuer ISSUER_ID
#
# After a successful build the script will automatically:
#   - git tag and push
#   - create a GitHub release with the zip
#   - update and push homebrew-tap/Casks/no-spoilers.rb

if [[ $# -eq 0 ]]; then
  LATEST=$(git tag --sort=-v:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -1)
  if [[ -n "$LATEST" ]]; then
    IFS='.' read -r MAJOR MINOR PATCH <<< "${LATEST#v}"
    SUGGESTED="${MAJOR}.${MINOR}.$((PATCH + 1))"
  else
    SUGGESTED="1.0.0"
  fi
  read -rp "Version [${SUGGESTED}]: " INPUT
  VERSION="${INPUT:-$SUGGESTED}"
else
  VERSION="${1:?Usage: $0 <version> [--notarytool-key <path> --notarytool-key-id <id> --notarytool-issuer <id>]}"
  shift
fi

NOTARYTOOL_KEY=""
NOTARYTOOL_KEY_ID=""
NOTARYTOOL_ISSUER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --notarytool-key)     NOTARYTOOL_KEY="$2";     shift 2 ;;
    --notarytool-key-id)  NOTARYTOOL_KEY_ID="$2";  shift 2 ;;
    --notarytool-issuer)  NOTARYTOOL_ISSUER="$2";  shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

SCHEME="NoSpoilersMac"
PROJECT="NoSpoilers/NoSpoilers.xcodeproj"
EXPORT_OPTIONS="NoSpoilers/ExportOptions-DeveloperID.plist"
ARCHIVE_PATH="/tmp/NoSpoilersMac-${VERSION}.xcarchive"
EXPORT_PATH="/tmp/NoSpoilersMac-export-${VERSION}"
STAPLE_DIR="/tmp/NoSpoilersMac-staple-${VERSION}"
ZIP_NAME="NoSpoilers-${VERSION}.zip"
ZIP_PATH="/tmp/${ZIP_NAME}"

echo "==> Archiving ${SCHEME} v${VERSION}..."
xcodebuild archive \
  -project "${PROJECT}" \
  -scheme "${SCHEME}" \
  -destination "generic/platform=macOS" \
  -archivePath "${ARCHIVE_PATH}" \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM=6FZN56WC8G \
  MARKETING_VERSION="${VERSION}"

echo "==> Exporting with Developer ID..."
xcodebuild -exportArchive \
  -archivePath "${ARCHIVE_PATH}" \
  -exportOptionsPlist "${EXPORT_OPTIONS}" \
  -exportPath "${EXPORT_PATH}"

echo "==> Zipping..."
ditto -c -k --sequesterRsrc --keepParent \
  "${EXPORT_PATH}/NoSpoilersMac.app" \
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

echo "==> Tagging and pushing v${VERSION}..."
git tag "v${VERSION}"
git push origin "v${VERSION}"

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
echo "Done! v${VERSION} is live."
