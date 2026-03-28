# Task 08: Homebrew Distribution

**Status:** TODO
**Depends on:** Task 06 complete (app works correctly on real devices)
**Effort:** ~2 hours first time; ~15 minutes per release thereafter

## Goal

Publish No Spoilers to Homebrew so anyone can install the macOS menu bar app with:

```bash
brew install --cask npomfret/tap/no-spoilers
```

## Overview

The distribution chain is:

```
Xcode Archive → Export (Developer ID) → Notarize → GitHub Release
                                                          ↓
                              homebrew-tap/Casks/no-spoilers.rb points at zip URL
```

The iOS app is NOT distributed via Homebrew. Only the macOS menu bar app (`NoSpoilersMac`).

---

## Phase 1: Developer ID Certificate

You need a "Developer ID Application" certificate. This is different from the "Apple Development"
certificate Xcode uses for device testing.

1. Open **Xcode → Settings → Accounts**
2. Select your Apple ID, click **Manage Certificates…**
3. Click **+** → **Developer ID Application**
4. Xcode creates the certificate and installs it in your keychain automatically

Verify it installed:
```bash
security find-identity -v -p codesigning | grep "Developer ID Application"
```

Expected output (your name, not this exact string):
```
1) ABC123... "Developer ID Application: Nick Pomfret (6FZN56WC8G)"
```

If this step fails, check you have the "Developer ID" capability enabled at
developer.apple.com/account → Certificates, Identifiers & Profiles.

---

## Phase 2: Notarization Credentials

Apple requires notarization for all Developer ID apps. You need an App Store Connect API key.

1. Go to [appstoreconnect.apple.com/access/api](https://appstoreconnect.apple.com/access/api)
2. Click **+** to generate a new key
3. Name it "notarytool", role: **Developer**
4. Download the `.p8` file — **you can only download it once**
5. Note the **Key ID** and **Issuer ID** shown on the same page

Store credentials in your keychain (run once):
```bash
xcrun notarytool store-credentials "no-spoilers-notarytool" \
  --key /path/to/AuthKey_XXXXXXXXXX.p8 \
  --key-id XXXXXXXXXX \
  --issuer XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
```

Replace the paths/IDs with your actual values. The profile name `no-spoilers-notarytool`
is used in Phase 4.

---

## Phase 3: Configure Xcode for Developer ID Export

The project currently signs for local development. For distribution you need an export options file.

Create `NoSpoilers/ExportOptions-DeveloperID.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>6FZN56WC8G</string>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
```

---

## Phase 4: Build, Sign, and Notarize Script

Create `scripts/release-mac.sh` (make it executable: `chmod +x scripts/release-mac.sh`):

```bash
#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?Usage: $0 <version>  e.g. $0 1.0.0}"
SCHEME="NoSpoilersMac"
PROJECT="NoSpoilers/NoSpoilers.xcodeproj"
EXPORT_OPTIONS="NoSpoilers/ExportOptions-DeveloperID.plist"
ARCHIVE_PATH="/tmp/NoSpoilersMac-${VERSION}.xcarchive"
EXPORT_PATH="/tmp/NoSpoilersMac-export-${VERSION}"
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

echo "==> Notarizing..."
xcrun notarytool submit "${ZIP_PATH}" \
  --keychain-profile "${NOTARYTOOL_PROFILE}" \
  --wait

echo "==> Stapling..."
# Unzip, staple, re-zip
STAPLE_DIR="/tmp/NoSpoilersMac-staple-${VERSION}"
mkdir -p "${STAPLE_DIR}"
ditto -x -k "${ZIP_PATH}" "${STAPLE_DIR}"
xcrun stapler staple "${STAPLE_DIR}/NoSpoilersMac.app"
rm -f "${ZIP_PATH}"
ditto -c -k --sequesterRsrc --keepParent \
  "${STAPLE_DIR}/NoSpoilersMac.app" \
  "${ZIP_PATH}"

echo "==> Computing SHA256..."
SHA256=$(shasum -a 256 "${ZIP_PATH}" | awk '{print $1}')

echo ""
echo "Done!"
echo "  Zip:    ${ZIP_PATH}"
echo "  SHA256: ${SHA256}"
echo ""
echo "Next steps:"
echo "  1. Create GitHub release v${VERSION}, attach ${ZIP_NAME}"
echo "  2. Update homebrew-tap with url and sha256 above"
```

---

## Phase 5: Set Up the Homebrew Tap Repo

The repo `git@github.com:npomfret/homebrew-tap.git` already exists at `/Users/nickpomfret/projects/homebrew-tap`.

Create the directory structure and cask file:

```bash
mkdir -p /Users/nickpomfret/projects/homebrew-tap/Casks
```

Create `/Users/nickpomfret/projects/homebrew-tap/Casks/no-spoilers.rb`:
```ruby
cask "no-spoilers" do
  version "1.0.0"
  sha256 "REPLACE_WITH_ACTUAL_SHA256"

  url "https://github.com/npomfret/no-spoilers/releases/download/v#{version}/NoSpoilers-#{version}.zip"
  name "No Spoilers"
  desc "F1 race weekend sessions — no results shown"
  homepage "https://github.com/npomfret/no-spoilers"

  depends_on macos: ">= :sequoia"

  app "NoSpoilersMac.app"

  zap trash: [
    "~/Library/Containers/pomocorp.NoSpoilers.NoSpoilersMac",
    "~/Library/Group Containers/group.pomocorp.no-spoilers",
  ]
end
```

Push:
```bash
cd /Users/nickpomfret/projects/homebrew-tap
git add Casks/no-spoilers.rb
git commit -m "Add No Spoilers cask"
git push
```

---

## Phase 6: First Release

### 6a. Set a version number

Pick `1.0.0`. Update `MARKETING_VERSION` in the Xcode project if it isn't already set:
- Xcode → project target → General → Version: `1.0.0`, Build: `1`

Or edit directly in `project.pbxproj`: search for `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`.

### 6b. Run the release script

```bash
cd /Users/nickpomfret/projects/no-spoilers
bash scripts/release-mac.sh 1.0.0
```

This takes 3–8 minutes (notarization waits on Apple's servers).

### 6c. Create GitHub Release

```bash
# Tag the commit
git tag v1.0.0
git push origin v1.0.0

# Create the release and upload the zip (requires gh CLI)
gh release create v1.0.0 \
  --title "v1.0.0" \
  --notes "Initial release" \
  /tmp/NoSpoilers-1.0.0.zip
```

### 6d. Update the Cask

Replace `REPLACE_WITH_ACTUAL_SHA256` and `1.0.0` in `no-spoilers.rb` with the real values
printed by the release script, then push to homebrew-tap.

---

## Phase 7: Test the Install

```bash
brew tap npomfret/tap
brew install --cask npomfret/tap/no-spoilers

# Verify it launches
open /Applications/NoSpoilersMac.app
```

The app should launch from `/Applications`, not require Xcode, and not trigger Gatekeeper warnings.

To uninstall:
```bash
brew uninstall --cask npomfret/tap/no-spoilers
```

---

## Per-Release Checklist (after first release)

For every subsequent release:
- [ ] Bump version in Xcode (`MARKETING_VERSION`)
- [ ] Run `bash scripts/release-mac.sh <version>`
- [ ] `git tag v<version> && git push origin v<version>`
- [ ] `gh release create v<version> ... /tmp/NoSpoilers-<version>.zip`
- [ ] Update `version` and `sha256` in `homebrew-tap/Casks/no-spoilers.rb` and push

---

## Troubleshooting

**Notarization fails with "The software asset has already been uploaded"**
Use a different zip path or increment the build number.

**Gatekeeper blocks the app after brew install**
The stapling step may have failed. Check `xcrun stapler validate NoSpoilersMac.app`.

**`brew install` gives "SHA256 mismatch"**
The sha256 in the cask doesn't match the zip. Re-run `shasum -a 256 /tmp/NoSpoilers-<version>.zip`
and update the cask.

**Export fails with "no accounts with iTunes Connect access"**
The notarytool credentials aren't stored under the right profile name. Re-run
`xcrun notarytool store-credentials` and check the profile name matches the script.

**App name in zip**: `xcodebuild -exportArchive` names the app after the scheme (`NoSpoilersMac.app`).
If the app bundle name changes, update `app "NoSpoilersMac.app"` in the cask and the `ditto` path
in the release script.
