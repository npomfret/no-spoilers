#!/usr/bin/env bash
set -euo pipefail

# Apple-bundled tools must win PATH lookup over any Homebrew overrides.
# Xcode's distribution pipeline shells out to a "server-side" rsync via PATH;
# if Homebrew has installed rsync 3.x, it's picked up and doesn't recognise
# Apple's -E (extended-attributes) flag, breaking the export with "Copy failed".
export PATH="/usr/bin:/bin:${PATH}"

# The Developer ID release engine: a notarized zip, a GitHub release, the cask.
#
# **Homebrew only, since 2026-09-10.** This was the single release engine for
# three channels, and task 38 took the App Store channels out of it: TestFlight
# delivery is `scripts/submit_build.py`. The two share no run, no preflight and
# no failure, so a Homebrew problem cannot stop a TestFlight build and neither
# waits for the other.
#
# **It releases the version the commit holds, and changes nothing on `main`.**
# It used to set MARKETING_VERSION to whatever it was given, commit that, and
# push it with a rebase. With Homebrew on its own cadence, that would walk the
# project back under the Apple train. A version is opened by
# `scripts/open-version.sh`; this releases it.
#
# Usage:
#   scripts/release.sh            # the project's MARKETING_VERSION
#   scripts/release.sh 1.1.4      # the same, stated: refused unless it matches
#
# Options:
#   --notarytool-key /path/to.p8 --notarytool-key-id KEY_ID --notarytool-issuer ISSUER_ID
#                    (omit to use the keychain profile "no-spoilers-notarytool")
#   --homebrew-tap DIR
#                    the tap checkout the cask is committed to; omit to use the
#                    sibling ../homebrew-tap. A build agent passes a fresh clone
#                    — see ci-publish.sh.
#   --signing-key /path/to.p8 --signing-key-id KEY_ID --signing-issuer ISSUER
#                    authenticate automatic signing without an Xcode account.
#                    Given these, xcodebuild talks to App Store Connect directly
#                    rather than falling back to a generic team profile.
#   --allow-dirty    archive uncommitted work anyway
#
# What a run leaves in git:
#
#   build/N   an annotated tag on the commit about to be archived, pushed
#             *before* the archive. The push reserves the number:
#             `submit_build.py` reserves the same way, so the two cannot stamp
#             one number on two builds.
#   vX.Y.Z    an annotated tag, the Developer ID release: the Homebrew cask
#             downloads `releases/download/v#{version}/…`, so the name cannot change.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_version.sh"

# Every path below this line is relative to the repository.
cd "${SCRIPT_DIR}/.."

# ── Version ─────────────────────────────────────────────────────────────────

PROJECT_VERSION="$(current_marketing_version)"
if [[ $# -gt 0 && "${1:-}" != --* ]]; then
  VERSION="$1"
  shift
else
  VERSION="$PROJECT_VERSION"
fi

if [[ "$VERSION" != "$PROJECT_VERSION" ]]; then
  echo "This commit builds ${PROJECT_VERSION}, and release.sh releases what the commit holds." >&2
  echo "Open ${VERSION} first with scripts/open-version.sh ${VERSION}, then release that commit." >&2
  exit 1
fi

# ── Options ──────────────────────────────────────────────────────────────────

ALLOW_DIRTY=""
NOTARYTOOL_KEY=""
NOTARYTOOL_KEY_ID=""
NOTARYTOOL_ISSUER=""
HOMEBREW_TAP=""
SIGNING_KEY=""
SIGNING_KEY_ID=""
SIGNING_ISSUER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --allow-dirty)        ALLOW_DIRTY="yes";      shift ;;
    --notarytool-key)     NOTARYTOOL_KEY="$2";    shift 2 ;;
    --notarytool-key-id)  NOTARYTOOL_KEY_ID="$2"; shift 2 ;;
    --notarytool-issuer)  NOTARYTOOL_ISSUER="$2"; shift 2 ;;
    --homebrew-tap)       HOMEBREW_TAP="$2";      shift 2 ;;
    --signing-key)        SIGNING_KEY="$2";       shift 2 ;;
    --signing-key-id)     SIGNING_KEY_ID="$2";    shift 2 ;;
    --signing-issuer)     SIGNING_ISSUER="$2";    shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

# ── Paths ────────────────────────────────────────────────────────────────────

SCHEME="NoSpoilers"
DESTINATION="generic/platform=macOS"
PRODUCT_BASENAME="NoSpoilersMac"
EXPORTED_APP_NAME="NoSpoilersMac.app"
PROJECT="NoSpoilers/NoSpoilers.xcodeproj"
ARCHIVE_PATH="/tmp/${PRODUCT_BASENAME}-${VERSION}.xcarchive"
EXPORT_PATH_DEVID="/tmp/${PRODUCT_BASENAME}-devid-export-${VERSION}"

# ── Preflight: the Homebrew tap ─────────────────────────────────────────────
#
# Everything this run needs from outside the repository, checked before anything
# is built or published. Discovering the tap missing at the end of the run means
# discovering it after notarization has completed and the GitHub release is
# already public, with no way to finish. Fail loudly, first.

# **The tap is shared, so every checkout of it goes stale.** It holds more than
# this cask, and a laptop and a build agent both publish to it, so a checkout
# falls behind the moment another one pushes. The cask commit at the end of
# the run is a bare `git push`, which a checkout behind its upstream cannot
# make — and by then the GitHub release is public. Found 2026-09-10 while
# cloning the tap onto a TeamCity agent: nothing here pulled it, and
# `ci-publish.sh`'s `push --dry-run` passes on a checkout that is merely behind.
# So it is brought current twice: in preflight, where failing costs nothing,
# and again immediately before the cask is edited, for whatever was pushed
# during the notarization wait.
#
# Uncommitted changes to tracked files stop the run rather than being stashed
# or carried: an edited cask is a previous run that died before committing, or
# somebody's work, and this cannot tell which. Untracked files are left alone —
# a `.DS_Store` in a laptop's tap is ordinary, and nothing here commits anything
# but the cask. `--rebase`: a cask commit a previous run made and failed to push
# is carried onto the new tip, and a real conflict is aborted with the tap left
# as it was.
bring_tap_current() {
  if ! git -C "${HOMEBREW_TAP_DIR}" diff --quiet HEAD --; then
    echo "${HOMEBREW_TAP_DIR} has uncommitted changes to tracked files:" >&2
    git -C "${HOMEBREW_TAP_DIR}" status --short --untracked-files=no >&2
    echo "Commit, push or discard them; this run will not guess which." >&2
    return 1
  fi
  if ! git -C "${HOMEBREW_TAP_DIR}" pull --rebase --quiet; then
    git -C "${HOMEBREW_TAP_DIR}" rebase --abort >/dev/null 2>&1 || true
    echo "${HOMEBREW_TAP_DIR} could not be brought up to date with its upstream." >&2
    return 1
  fi
}

# A laptop's tap is the sibling checkout. A build agent's is a fresh clone
# `ci-publish.sh` makes for this run and passes in, because a checkout left on
# an agent by hand lives in one agent's work directory and goes stale.
HOMEBREW_TAP_DIR="${HOMEBREW_TAP:-$(dirname "$(realpath "$0")")/../../homebrew-tap}"
CASK_FILE="${HOMEBREW_TAP_DIR}/Casks/no-spoilers.rb"

if [[ ! -f "${CASK_FILE}" ]]; then
  echo "No Homebrew cask at ${CASK_FILE}" >&2
  echo "This publishes to a homebrew-tap checkout: clone it beside this repo, or pass --homebrew-tap DIR." >&2
  exit 1
fi
if ! git -C "${HOMEBREW_TAP_DIR}" rev-parse --git-dir >/dev/null 2>&1; then
  echo "${HOMEBREW_TAP_DIR} is not a git checkout, so the cask update cannot be pushed" >&2
  exit 1
fi
echo "==> Bringing homebrew-tap up to date..."
bring_tap_current || exit 1

# ── Preflight: the working tree ─────────────────────────────────────────────
#
# `xcodebuild archive` builds the tree, not the commit. An uncommitted edit is in
# the build and in front of users while the tags describe something else.
# Nothing here ever reverts your files; it stops instead.

if [[ -z "$ALLOW_DIRTY" ]]; then
  if [[ -n "$(git status --porcelain)" ]]; then
    echo "The working tree is not clean, so the build would not match the commit:" >&2
    git status --short >&2
    echo "" >&2
    echo "Commit it, stash it, or pass --allow-dirty if you meant it." >&2
    exit 1
  fi
fi

# ── Preflight: a commit on main ─────────────────────────────────────────────
#
# **The commit being released must already be on `origin/main`**, because both
# tags this writes mark it and a tag on a commit only this machine holds is a
# record nobody else can read. This never pushes a branch, so an unpushed
# commit is refused rather than carried up. Being *behind* is fine: TeamCity
# pins a revision when a build is queued, and releasing that revision faithfully
# is correct. `--tags` because the build number below reads them, and a
# TeamCity checkout carries none of its own.

git fetch --quiet --tags origin +refs/heads/main:refs/remotes/origin/main
if ! git merge-base --is-ancestor HEAD refs/remotes/origin/main; then
  echo "$(git log -1 --format='%h %s') is not on origin/main, so nothing this run tags could be" >&2
  echo "read anywhere else. Push it first; this never pushes a branch. Nothing was built." >&2
  exit 1
fi

# ── Preflight: the gate ─────────────────────────────────────────────────────
#
# There is deliberately no way to skip it. A release is the last place to start
# trusting a flag that says the tests do not matter this time.

echo "==> Running the release gate: scripts/verify-core-tests.sh..."
"${SCRIPT_DIR}/verify-core-tests.sh"

# ── The build number, reserved ──────────────────────────────────────────────
#
# **From App Store Connect and the `build/` tags, not from the project file**:
# `next_build_number` in `_version.sh`. A Developer ID build never reaches App
# Store Connect, so the tag is its only record, and it is pushed *before* the
# archive: `submit_build.py` can choose the same number at the same moment, and
# only one of the two pushes can succeed. A reserved number that is never
# released is harmless; two builds under one number are not.
#
# **Only one push succeeding depends on the two tags differing.** A tag object
# is its content, so two runs tagging one commit with one message, as one
# person, in one second, write the same object, and a push that sets a ref to
# the object it already holds succeeds. The `Reservation:` line makes every
# object unique, and the remote is read back rather than the push's exit status
# believed, as `submit_build.py: claim` does.

echo "==> Reserving the next build number..."
NEW_BUILD="$(next_build_number)"
BUILD_TAG="build/${NEW_BUILD}"
git tag -a "${BUILD_TAG}" -m "build ${NEW_BUILD}: macos developer-id v${VERSION}" \
  -m "Reserved by release.sh before archiving this commit for the Developer ID channel." \
  -m "Reservation: $(uuidgen) on $(hostname -s)"
RESERVED_OBJECT="$(git rev-parse "refs/tags/${BUILD_TAG}")"
git push --quiet origin "refs/tags/${BUILD_TAG}" || true
REMOTE_OBJECT="$(git ls-remote origin "refs/tags/${BUILD_TAG}" \
  | awk -v ref="refs/tags/${BUILD_TAG}" '$2 == ref { print $1 }')" || REMOTE_OBJECT=""
if [[ "${REMOTE_OBJECT}" != "${RESERVED_OBJECT}" ]]; then
  git tag -d "${BUILD_TAG}" >/dev/null
  echo "" >&2
  echo "Could not reserve ${BUILD_TAG}: origin does not hold this run's tag. If another run" >&2
  echo "reserved it first, run this again to take the next number. Nothing was built." >&2
  exit 1
fi
echo "  ${BUILD_TAG} reserved on $(git log -1 --format='%h %s')"

# vX.Y.Z — the Developer ID release. Idempotent, so a re-run after a partial
# failure finishes instead of dying here, and pushed the moment it exists.
tag_version() {
  if git rev-parse -q --verify "refs/tags/v${VERSION}" >/dev/null; then
    echo "==> v${VERSION} already tagged, skipping."
  else
    echo "==> Tagging v${VERSION}..."
    git tag -a "v${VERSION}" -m "v${VERSION}: macOS Developer ID release, build ${NEW_BUILD}"
  fi
  git push origin "v${VERSION}"
}

# ── Signing authentication ──────────────────────────────────────────────────
#
# Empty unless --signing-key was given, which keeps a machine with an Xcode
# account building exactly as it did before.

SIGNING_AUTH=()
if [[ -n "$SIGNING_KEY" ]]; then
  [[ -f "$SIGNING_KEY" ]] || { echo "no signing key at ${SIGNING_KEY}" >&2; exit 1; }
  [[ -n "$SIGNING_KEY_ID" && -n "$SIGNING_ISSUER" ]] \
    || { echo "--signing-key needs --signing-key-id and --signing-issuer too" >&2; exit 1; }
  SIGNING_AUTH=(
    -authenticationKeyPath "$SIGNING_KEY"
    -authenticationKeyID "$SIGNING_KEY_ID"
    -authenticationKeyIssuerID "$SIGNING_ISSUER"
  )
  echo "==> Signing will authenticate to App Store Connect as ${SIGNING_KEY_ID}."
fi

# ── Clean → archive ─────────────────────────────────────────────────────────

trap 'echo "" >&2; echo "Release failed after ${BUILD_TAG} was reserved. The number is spent and nothing was published." >&2' ERR

echo "==> Cleaning ${SCHEME}..."
xcodebuild clean \
  -project "${PROJECT}" \
  -scheme "${SCHEME}"

echo "==> Archiving ${SCHEME} v${VERSION} (macOS) as build ${NEW_BUILD}..."
xcodebuild archive \
  -project "${PROJECT}" \
  -scheme "${SCHEME}" \
  -destination "${DESTINATION}" \
  -archivePath "${ARCHIVE_PATH}" \
  -allowProvisioningUpdates \
  "${SIGNING_AUTH[@]+"${SIGNING_AUTH[@]}"}" \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM=6FZN56WC8G \
  CURRENT_PROJECT_VERSION="${NEW_BUILD}"

# ── The archive carries the number it was asked to ──────────────────────────
#
# The number reaches the build from the command line and nothing else, so the
# archive is the thing to ask. The export re-signs what is here and rewrites
# nothing.

echo "==> Checking every bundle in the archive reads build ${NEW_BUILD}..."
BUNDLES=0
while IFS= read -r BUNDLE; do
  if [[ -f "${BUNDLE}/Contents/Info.plist" ]]; then
    PLIST="${BUNDLE}/Contents/Info.plist"
  else
    PLIST="${BUNDLE}/Info.plist"
  fi
  STAMPED="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "${PLIST}")"
  if [[ "$STAMPED" != "$NEW_BUILD" ]]; then
    echo "" >&2
    echo "${BUNDLE#"${ARCHIVE_PATH}/Products/Applications/"} reads CFBundleVersion ${STAMPED}, not ${NEW_BUILD}." >&2
    echo "The archive does not carry the number it was asked to; nothing was published." >&2
    exit 1
  fi
  echo "  ${BUNDLE#"${ARCHIVE_PATH}/Products/Applications/"}: ${STAMPED}"
  BUNDLES=$((BUNDLES + 1))
done < <(find "${ARCHIVE_PATH}/Products/Applications" -type d \( -name '*.app' -o -name '*.appex' \))
if [[ "$BUNDLES" -eq 0 ]]; then
  echo "No app bundle under ${ARCHIVE_PATH}/Products/Applications; the archive layout is not what this expects." >&2
  exit 1
fi

trap - ERR

# ── Developer ID: export, notarize, publish ─────────────────────────────────

STAPLE_DIR="/tmp/${PRODUCT_BASENAME}-staple-${VERSION}"
ZIP_NAME="NoSpoilers-${VERSION}.zip"
ZIP_PATH="/tmp/${ZIP_NAME}"

echo "==> Exporting with Developer ID..."
xcodebuild -exportArchive \
  -archivePath "${ARCHIVE_PATH}" \
  -exportOptionsPlist "NoSpoilers/ExportOptions-DeveloperID.plist" \
  -exportPath "${EXPORT_PATH_DEVID}" \
  -allowProvisioningUpdates \
  "${SIGNING_AUTH[@]+"${SIGNING_AUTH[@]}"}"

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

# HOMEBREW_TAP_DIR and CASK_FILE were resolved and checked in preflight, and
# the tap is pulled again here for whatever landed during notarization. If
# that fails the release is already public, so the two values the cask needs
# are printed rather than left in a scrolled-away log.
echo "==> Updating homebrew-tap..."
if ! bring_tap_current; then
  echo "" >&2
  echo "v${VERSION} is published on GitHub, but the cask still names the previous version." >&2
  echo "Once ${HOMEBREW_TAP_DIR} is current, set these in Casks/no-spoilers.rb, commit and push:" >&2
  echo "  version \"${VERSION}\"" >&2
  echo "  sha256 \"${SHA256}\"" >&2
  exit 1
fi
sed -i '' "s/version \".*\"/version \"${VERSION}\"/" "${CASK_FILE}"
sed -i '' "s/sha256 \".*\"/sha256 \"${SHA256}\"/" "${CASK_FILE}"
(cd "${HOMEBREW_TAP_DIR}" && git add Casks/no-spoilers.rb && git commit -m "no-spoilers ${VERSION}" && git push)

echo ""
echo "Done. v${VERSION} build ${NEW_BUILD} is live on Homebrew."
