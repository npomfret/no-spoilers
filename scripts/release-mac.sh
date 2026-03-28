#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?Usage: $0 <version>  e.g. $0 1.0.0}"
SCHEME="NoSpoilersMac"
PROJECT="NoSpoilers/NoSpoilers.xcodeproj"
EXPORT_OPTIONS="NoSpoilers/ExportOptions-DeveloperID.plist"
ARCHIVE_PATH="/tmp/NoSpoilersMac-${VERSION}.xcarchive"
EXPORT_PATH="/tmp/NoSpoilersMac-export-${VERSION}"
STAPLE_DIR="/tmp/NoSpoilersMac-staple-${VERSION}"
ZIP_NAME="NoSpoilers-${VERSION}.zip"
ZIP_PATH="/tmp/${ZIP_NAME}"
NOTARYTOOL_PROFILE="no-spoilers-notarytool"

echo "==> Archiving ${SCHEME} v${VERSION}..."
xcodebuild archive \
  -project "${PROJECT}" \
  -scheme "${SCHEME}" \
  -destination "generic/platform=macOS" \
  -archivePath "${ARCHIVE_PATH}" \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM=6FZN56WC8G

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
xcrun notarytool submit "${ZIP_PATH}" \
  --keychain-profile "${NOTARYTOOL_PROFILE}" \
  --wait

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
echo "✓ Done!"
echo "  Zip:    ${ZIP_PATH}"
echo "  SHA256: ${SHA256}"
echo ""
echo "Next steps:"
echo "  1. git tag v${VERSION} && git push origin v${VERSION}"
echo "  2. gh release create v${VERSION} --title 'v${VERSION}' --notes '' ${ZIP_PATH}"
echo "  3. Update homebrew-tap/Casks/no-spoilers.rb:"
echo "     version \"${VERSION}\""
echo "     sha256 \"${SHA256}\""
