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
# Signing without an Xcode account (--signing-key, optional):
#
#   Automatic signing normally resolves profiles through an Apple ID signed into
#   Xcode. A build agent has no such account, and the fallback is the generic
#   "iOS Team Provisioning Profile: *" — which carries no App Group, so the
#   archive dies naming a capability rather than an account. Given these three,
#   xcodebuild talks to App Store Connect directly and creates the profile it
#   needs, which is what -allowProvisioningUpdates is for.
#
#     --signing-key /path/to.p8 --signing-key-id KEY_ID --signing-issuer ISSUER
#
#   Separate from --api-key on purpose: that one uploads and this one *writes*
#   profiles, which is a higher role. Callers with an Xcode account should keep
#   omitting these, so the path that has shipped real builds does not change.
#
#   both          Runs app-store then developer-id from the same archive (macos only)
#
# Build number (--build, optional):
#
#   Use this CFBundleVersion instead of asking for the next one. ship.sh passes
#   it so one ship run is one build number on every platform. Left out, the
#   number is `next_build_number` from _version.sh: the highest App Store
#   Connect holds on either platform, or the highest build/ tag, plus one.
#
# What a run leaves in git, since task 32 (2026-09-05):
#
#   open vX.Y.Z      a commit, only when MARKETING_VERSION changed, pushed
#                    before the archive
#   build/N          an annotated tag on the archived commit, pushed the moment
#                    the archive exists — this is the record of the upload
#   vX.Y.Z           an annotated tag, Developer ID channel only: the Homebrew
#                    cask downloads by that name
#
#   The App Store channels tag no version. `scripts/tag_approved.py` writes
#   `ios/vX.Y.Z` or `macos/vX.Y.Z` on the approved build's commit once App
#   Store Connect says users can get it. The committed CURRENT_PROJECT_VERSION
#   is frozen at 10022 and is not a build setting the archive reads.
#
# Dirty tree (--allow-dirty, optional):
#
#   Archive uncommitted work anyway. See the preflight for why that is refused
#   by default; there is no equivalent escape hatch for the test gate.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_version.sh"

# Every path below this line is relative to the repository, and preflight now
# runs git and the tests from here too. Same move `scripts/verify-core-tests.sh`
# makes for the same reason: a script that only works from one directory works
# by luck.
cd "${SCRIPT_DIR}/.."

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
ALLOW_DIRTY=""
NOTARYTOOL_KEY=""
NOTARYTOOL_KEY_ID=""
NOTARYTOOL_ISSUER=""
API_KEY=""
API_KEY_ID=""
API_ISSUER=""
SIGNING_KEY=""
SIGNING_KEY_ID=""
SIGNING_ISSUER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --platform)           PLATFORM="$2";          shift 2 ;;
    --channel)            CHANNEL="$2";           shift 2 ;;
    --build)              FORCED_BUILD="$2";      shift 2 ;;
    --allow-dirty)        ALLOW_DIRTY="yes";      shift ;;
    --notarytool-key)     NOTARYTOOL_KEY="$2";    shift 2 ;;
    --notarytool-key-id)  NOTARYTOOL_KEY_ID="$2"; shift 2 ;;
    --notarytool-issuer)  NOTARYTOOL_ISSUER="$2"; shift 2 ;;
    --api-key)            API_KEY="$2";            shift 2 ;;
    --api-key-id)         API_KEY_ID="$2";         shift 2 ;;
    --api-issuer)         API_ISSUER="$2";         shift 2 ;;
    --signing-key)        SIGNING_KEY="$2";        shift 2 ;;
    --signing-key-id)     SIGNING_KEY_ID="$2";     shift 2 ;;
    --signing-issuer)     SIGNING_ISSUER="$2";     shift 2 ;;
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

# ── Preflight: the working tree ─────────────────────────────────────────────
#
# `xcodebuild archive` builds the tree, not the commit, and this script stages
# only the project file. So an uncommitted edit is in the build, in the upload
# and in front of users, while the commit, the tag and the TestFlight note all
# describe something else — and since 2026-08-22 the note is derived from that
# commit, which turns a dirty ship from a note that is missing into one that is
# confidently wrong. Nothing here ever reverts your files; it stops instead.

if [[ -z "$ALLOW_DIRTY" ]]; then
  if [[ -n "$(git status --porcelain)" ]]; then
    echo "The working tree is not clean, so the build would not match the commit:" >&2
    git status --short >&2
    echo "" >&2
    echo "Commit it, stash it, or pass --allow-dirty if you meant it." >&2
    exit 1
  fi
fi

# ── Preflight: the branch tip ───────────────────────────────────────────────
#
# **A checkout that is behind its upstream cannot finish this run**, because
# the branch is pushed below with a bare `git push` and a non-fast-forward is
# rejected. Build 958 found that out the expensive way on 2026-08-26, when the
# push came after the archive: queued at the same revision as the run before
# it, it archived for four minutes and then died on the push, having built a
# number nothing recorded. The push now comes first, so the cost of arriving
# here is a fetch rather than an archive — but it is still refused, because
# the tag below has to land on a commit that is on `main`.
#
# TeamCity pins a revision when a build is *queued*, not when it starts, so a
# publish sitting behind another one in the queue is the ordinary way to arrive
# here rather than an exotic one.
#
# **Behind or diverged is refused; ahead is fine.** Shipping local commits that
# are not on the remote yet is the normal laptop flow — the push below carries
# them up. Only an upstream this checkout has not seen is a problem, so the
# question is whether the upstream is an ancestor of HEAD and not whether the
# two are equal.
#
# `--tags` because `next_build_number` and the `build/` guard below read tags,
# and a TeamCity checkout carries none of its own.

UPSTREAM="$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)"
if [[ -z "$UPSTREAM" ]]; then
  echo "This checkout's branch has no upstream, so nothing this run records could be pushed." >&2
  echo "Set one with: git branch --set-upstream-to origin/main" >&2
  exit 1
fi

echo "==> Checking ${UPSTREAM} has nothing this checkout is missing..."
git fetch --quiet --tags "${UPSTREAM%%/*}"
if ! git merge-base --is-ancestor "$UPSTREAM" HEAD; then
  echo "" >&2
  echo "${UPSTREAM} holds work this checkout does not, so the build would not be from" >&2
  echo "the tip of main and could not be recorded there:" >&2
  git --no-pager log --oneline "HEAD..${UPSTREAM}" >&2
  echo "" >&2
  echo "Rebase onto it and start again. Nothing was built." >&2
  exit 1
fi

# ── Preflight: the build number ─────────────────────────────────────────────
#
# **From App Store Connect, not from the project file.** CFBundleVersion is a
# counter Apple enforces across every upload of the app, so the record Apple
# keeps is the counter, and `next_build_number` reads it — plus the build/
# tags, for a number this repository tagged that never reached the record. The
# project file's CURRENT_PROJECT_VERSION stopped being edited by this script
# in task 32; the archive is stamped from the command line below, as it always
# was, and the committed value was only ever a ledger of the last upload.
#
# `--build` pins the number instead, for ship.sh: one ship run is one build
# number on every platform. A pinned number that is already tagged is fine
# only if the tag is on the commit about to be archived — which is the second
# platform of a ship run — and refused otherwise, here, before the archive
# rather than at `git tag` after it.

if [[ -n "$FORCED_BUILD" ]]; then
  NEW_BUILD="$FORCED_BUILD"
else
  echo "==> Asking App Store Connect for the next build number..."
  NEW_BUILD="$(next_build_number)"
fi
echo "  build ${NEW_BUILD}"

if TAGGED_AT="$(git rev-list -n1 "build/${NEW_BUILD}" 2>/dev/null)"; then
  if [[ "$TAGGED_AT" != "$(git rev-parse HEAD)" ]]; then
    echo "" >&2
    echo "build/${NEW_BUILD} already marks $(git log -1 --format='%h %s' "$TAGGED_AT"), which is not" >&2
    echo "this commit. That number was archived once already; pass a different --build or" >&2
    echo "none at all. Nothing was built." >&2
    exit 1
  fi
  if [[ "$(current_marketing_version)" != "$VERSION" ]]; then
    echo "" >&2
    echo "build/${NEW_BUILD} already marks this commit as $(git tag -l --format='%(subject)' "build/${NEW_BUILD}")," >&2
    echo "and shipping ${VERSION} would first commit the version change and archive a" >&2
    echo "different commit under the same number. Nothing was built." >&2
    exit 1
  fi
  echo "  build/${NEW_BUILD} already marks this commit; this run archives it for ${PLATFORM} under the same number."
fi

# **A spent (version, build) pair does not fail the build.** It compiles,
# archives, exports, uploads, goes green, and dies minutes later by email at
# "Preparing build for App Store Connect failed" — after every expensive step
# has already succeeded. Nor does an approved version: its train is closed,
# and altool refuses the package at validation, after the archive — three
# times on 2026-09-05. Two GETs answer both beforehand. The number above is
# free by construction when it was not pinned; the closed-train half is the
# one that still bites.
#
# The exit codes are read rather than the output: 0 free, 3 taken, anything else
# means the check itself did not run. Collapsing those would let a missing key
# or an offline laptop read as "the number is free", which is the outcome this
# is here to prevent.

if [[ "$CHANNEL" == "app-store" || "$CHANNEL" == "both" ]]; then
  echo "==> Checking App Store Connect for ${PLATFORM} ${VERSION} build ${NEW_BUILD}..."
  set +e
  python3 "${SCRIPT_DIR}/appstore_status.py" --spent "${PLATFORM}" "${VERSION}" "${NEW_BUILD}"
  SPENT_STATUS=$?
  set -e
  case "$SPENT_STATUS" in
    0) ;;
    3)
      echo "" >&2
      echo "Apple would refuse that upload after the archive rather than before it — the line" >&2
      echo "above says whether the build number is taken or the version is already approved." >&2
      echo "Pick another number with --build, or open a new train by shipping a different" >&2
      echo "version. Nothing was built." >&2
      exit 1
      ;;
    *)
      echo "" >&2
      echo "Could not find out whether ${VERSION} build ${NEW_BUILD} is free (exit ${SPENT_STATUS})." >&2
      echo "Stopping rather than guessing: the wrong guess costs a full archive and upload." >&2
      exit 1
      ;;
  esac
fi

# ── Preflight: the gate ─────────────────────────────────────────────────────
#
# **This is the same gate Xcode Cloud applies, in the path that now does the
# shipping.** `NoSpoilers/ci_scripts/ci_pre_xcodebuild.sh` runs this exact
# wrapper before every archive and its comment calls it "the only thing standing
# between a broken commit and TestFlight" — which stopped being true the moment
# Xcode Cloud ran out of compute quota and every release started coming from
# here instead. Build 10003 went out ungated on 2026-08-22.
#
# There is deliberately no way to skip it. The CI path has none either, and a
# release is the last place to start trusting a flag that says the tests do not
# matter this time.

echo "==> Running the release gate: scripts/verify-core-tests.sh..."
"${SCRIPT_DIR}/verify-core-tests.sh"

# ── Helpers: the two tags this engine writes ─────────────────────────────────
#
# Both annotated, so `git for-each-ref --format='%(taggerdate)'` says when, and
# both idempotent, so a re-run after a partial failure finishes instead of
# dying here. Both are pushed the moment they exist: a tag that only lives on
# the machine that shipped is a record nobody else can read.

# vX.Y.Z — the Developer ID release, and that channel only. The Homebrew cask
# downloads `releases/download/v#{version}/…`, so this is the one tag whose
# name cannot change. The App Store channels do not tag a version: which build
# of a version users get is decided by App Review, after this run, and
# `scripts/tag_approved.py` writes `ios/vX.Y.Z` or `macos/vX.Y.Z` then.
tag_version() {
  if git rev-parse -q --verify "refs/tags/v${VERSION}" >/dev/null; then
    echo "==> v${VERSION} already tagged, skipping."
  else
    echo "==> Tagging v${VERSION}..."
    git tag -a "v${VERSION}" -m "v${VERSION}: macOS Developer ID release, build ${NEW_BUILD}"
  fi
  git push origin "v${VERSION}"
}

# build/N — this commit was archived as build N. Written on HEAD, which is the
# commit `xcodebuild` just compiled: the version commit below is pushed before
# the archive and nothing moves HEAD after it, so the tag says what was built
# directly and no trailer has to. The preflight has already established that
# an existing build/N is on this commit, so finding one here is a ship.sh run
# on its second platform and not a collision.
tag_build() {
  local TAG="build/${NEW_BUILD}"
  if git rev-parse -q --verify "refs/tags/${TAG}" >/dev/null; then
    echo "==> ${TAG} already marks this commit."
  else
    echo "==> Tagging ${TAG}..."
    git tag -a "${TAG}" -m "v${VERSION} build ${NEW_BUILD}" \
      -m "Archived from this commit by release.sh --platform ${PLATFORM} --channel ${CHANNEL}."
  fi
  git push origin "${TAG}"
}

# ── Shared: open the version ────────────────────────────────────────────────
#
# **MARKETING_VERSION is the one thing this run still commits, and only when
# it changed.** It is what `ci-publish-ios.sh` reads to know which train to
# ask about and what `suggest_next_version` reads to offer the next one, so a
# new version has to reach `main`. The build number does not: it is stamped on
# the archive command line below and recorded by the build/ tag, which is why
# the "bump to vX (build N)" commit — twenty of them since 2026-08-22, three
# for builds Apple never received — is gone.
#
# **Committed and pushed before the archive, not after.** The bump commit was
# pushed afterwards on the reasoning that the archive is what makes a build
# number real, and the tag inherits that reasoning; an opened version is real
# the moment somebody asks for it, and a failed archive leaving `open v1.1.4`
# on `main` is an honest statement that the project now builds 1.1.4. Pushing
# first also means HEAD is final before `xcodebuild` reads the tree: the
# rebase below can only ever reorder what is about to be built, never what
# was built, which is what the `Built-From:` trailer used to have to guard.
#
# The tree is left dirty on failure on purpose — nothing here reverts a file
# the user may also have been editing.

trap 'echo "" >&2; echo "Release failed before v${VERSION} was opened. ${PBXPROJ} is modified and unpushed; nothing was built." >&2' ERR

echo "==> Setting MARKETING_VERSION to ${VERSION} in project..."
set_marketing_version "${VERSION}"

git add "${PBXPROJ}"
if git diff --cached --quiet; then
  echo "  (${VERSION} is already the project's version; nothing to commit)"
else
  git commit -q -m "open v${VERSION}" \
    -m "MARKETING_VERSION moves to ${VERSION}. Every upload of it is a build/N tag on the commit it was archived from."
  echo "  committed: $(git log -1 --format='%h %s')"
fi

# **The push has to survive main moving underneath it.** A bare `git push`
# loses to anything that lands between this run's checkout and this moment,
# and on 2026-08-26 build 990 lost by one second: a commit was pushed 29
# seconds into the run and the rejected push killed it under `set -e`. The
# preflight above cannot help, because that window opens after it. Rebasing
# is honest here because nothing has been built yet: whatever the rebase puts
# under HEAD is what the archive below compiles.
#
# It runs whether or not anything was committed, because a laptop ship may be
# carrying local commits, and the build/ tag has to land on a commit that is
# on `main` — a tag on a commit only this machine holds is a record nobody
# else can read.
#
# Three attempts, because losing the race twice in a row is a signal rather
# than bad luck. A conflict is not retried at all: the only file this run
# touches is the project file, so a conflict means another run is opening a
# version at the same time, and guessing which wins is worse than stopping.
echo "==> Pushing ${UPSTREAM%%/*}..."
PUSHED=""
for ATTEMPT in 1 2 3; do
  if git push --quiet; then
    PUSHED="yes"
    break
  fi
  echo ""
  echo "==> Push rejected (attempt ${ATTEMPT} of 3); rebasing onto the new tip..."
  if ! git pull --rebase --quiet; then
    git rebase --abort >/dev/null 2>&1 || true
    echo "" >&2
    echo "This run's commit conflicts with work pushed meanwhile, which means something" >&2
    echo "else is editing ${PBXPROJ} at the same time. Nothing was built." >&2
    exit 1
  fi
done

if [[ -z "$PUSHED" ]]; then
  echo "" >&2
  echo "Could not push after 3 attempts — main is moving faster than this run can" >&2
  echo "follow. Nothing was built." >&2
  exit 1
fi

# ── Shared: signing authentication ──────────────────────────────────────────
#
# Empty unless --signing-key was given, which is what keeps a machine with an
# Xcode account building exactly as it did before.

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

# ── Shared: clean → archive ──────────────────────────────────────────────────
#
# Nothing below this line edits the repository until the archive exists. A
# failure here leaves `main` exactly as the push above left it and consumes
# no build number: the number is recorded by the tag, and the tag is written
# only once there is an archive for it to describe.

trap 'echo "" >&2; echo "Release failed before build ${NEW_BUILD} was tagged. The number is unused and nothing was published." >&2' ERR

echo "==> Cleaning ${SCHEME}..."
xcodebuild clean \
  -project "${PROJECT}" \
  -scheme "${SCHEME}"

echo "==> Archiving ${SCHEME} v${VERSION} (${PLATFORM}) as build ${NEW_BUILD}..."
xcodebuild archive \
  -project "${PROJECT}" \
  -scheme "${SCHEME}" \
  -destination "${DESTINATION}" \
  -archivePath "${ARCHIVE_PATH}" \
  -allowProvisioningUpdates \
  "${SIGNING_AUTH[@]+"${SIGNING_AUTH[@]}"}" \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM=6FZN56WC8G \
  MARKETING_VERSION="${VERSION}" \
  CURRENT_PROJECT_VERSION="${NEW_BUILD}"

# ── Shared: the archive carries the number it was asked to ──────────────────
#
# **Every bundle in the archive has to read the same build number, and the
# archive is the thing to ask.** The number reaches the build from the command
# line above and nothing else, now that the project file is not stamped, and
# an app whose embedded widget extension disagrees with it is refused at
# upload — after the export and the wait. The export re-signs what is here and
# rewrites nothing, so a wrong number in the archive is a wrong number in the
# package, and asking here catches it before the tag as well as before the
# upload. iOS carries the app and the extension; macOS the app alone.

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
    echo "The archive does not carry the number it was asked to; nothing was tagged or uploaded." >&2
    exit 1
  fi
  echo "  ${BUNDLE#"${ARCHIVE_PATH}/Products/Applications/"}: ${STAMPED}"
  BUNDLES=$((BUNDLES + 1))
done < <(find "${ARCHIVE_PATH}/Products/Applications" -type d \( -name '*.app' -o -name '*.appex' \))
if [[ "$BUNDLES" -eq 0 ]]; then
  echo "No app bundle under ${ARCHIVE_PATH}/Products/Applications; the archive layout is not what this expects." >&2
  exit 1
fi
if [[ "$PLATFORM" == "ios" && "$BUNDLES" -lt 2 ]]; then
  echo "The iOS archive holds ${BUNDLES} bundle(s); the app and its widget extension make two." >&2
  exit 1
fi

trap - ERR

# ── Shared: record the build ────────────────────────────────────────────────
#
# The archive exists, so the number is spent and the record is written now,
# before the export and the upload — for the same reason the bump commit was
# committed here: an uploaded build must be recorded even if the upload then
# fails, and a number that is tagged and never uploaded is harmless where the
# reverse is a build on Apple's servers that nothing can name.

tag_build

# ── Channel: app-store ───────────────────────────────────────────────────────
#
# The App Store is the core product, so it goes first and Homebrew follows.
# Do not swap these back. Both channels export from the same archive, which is
# already built and valid by this point, but notarization is a multi-minute wait
# on an Apple service — and under `set -e` a notary failure used to kill the run
# before the store upload was ever attempted. In that order the add-on channel
# takes the core product down with it after the expensive work has succeeded.
# This way round, a Homebrew failure still fails the run loudly; it just cannot
# cost you the upload. See docs/guides/building.md.

if [[ "$CHANNEL" == "app-store" || "$CHANNEL" == "both" ]]; then
  PACKAGE_PATH="${EXPORT_PATH_APPSTORE}/${APPSTORE_PACKAGE_NAME}"

  echo "==> Exporting for App Store..."
  xcodebuild -exportArchive \
    -archivePath "${ARCHIVE_PATH}" \
    -exportOptionsPlist "NoSpoilers/ExportOptions-AppStore.plist" \
    -exportPath "${EXPORT_PATH_APPSTORE}" \
    -allowProvisioningUpdates \
    "${SIGNING_AUTH[@]+"${SIGNING_AUTH[@]}"}"

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

    echo ""
    echo "Done (app-store / ${PLATFORM})! v${VERSION} build ${NEW_BUILD} uploaded; build/${NEW_BUILD} marks the commit."
    echo ""
    # The upload reaches nobody on its own. A build sits in no tester group
    # until somebody puts it in one — internal groups included — and every
    # other signal reads as success while it does, which is how build 32 spent
    # three days VALID and uninstallable. Naming the command here costs a line
    # and is the only place the next step is ever said out loud.
    echo "It is uploaded, not delivered. Processing takes a few minutes, then:"
    echo "  scripts/testflight_distribute.py --platform ${PLATFORM} --apply"
    echo ""
    echo "Then submit for review in App Store Connect. Once it is on the store:"
    echo "  scripts/tag_approved.py ${PLATFORM} ${VERSION} --apply"
  else
    echo ""
    echo "No API key provided. Upload the package manually:"
    echo "  xcrun altool --upload-app -f '${PACKAGE_PATH}' --type ${ALTOOL_TYPE} \\"
    echo "    --apiKey KEY_ID --apiIssuer ISSUER_ID"
    echo "  Or drag '${PACKAGE_PATH}' into Transporter.app"
    echo ""
    echo "build/${NEW_BUILD} already marks the commit. Then submit for review in App Store Connect."
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

  # HOMEBREW_TAP_DIR and CASK_FILE were resolved and checked in preflight.
  echo "==> Updating homebrew-tap..."
  sed -i '' "s/version \".*\"/version \"${VERSION}\"/" "${CASK_FILE}"
  sed -i '' "s/sha256 \".*\"/sha256 \"${SHA256}\"/" "${CASK_FILE}"
  (cd "${HOMEBREW_TAP_DIR}" && git add Casks/no-spoilers.rb && git commit -m "no-spoilers ${VERSION}" && git push)

  echo ""
  echo "Done (developer-id)! v${VERSION} is live on Homebrew."
fi
