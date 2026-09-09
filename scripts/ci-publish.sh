#!/usr/bin/env bash
set -euo pipefail

# The CI entry point for an App Store upload. Runs on a TeamCity agent.
#
# **Deliberately thin.** Everything worth arguing about — the clean-tree refusal,
# the build number from App Store Connect, the `verify-core-tests.sh` gate, the
# archive, the `build/N` tag and the upload — is in `release.sh`, which has
# shipped real builds and must stay the one release engine. There is no second
# one here and there must never be.
#
# What is left is the things `release.sh` reasonably assumes about the machine it
# runs on, and which are all false by default on a build agent. Each is asserted
# here, in seconds, before anything expensive happens. That is the recipe
# `docs/TEAMCITY-AGENTS.md` §243 names: assert the toolchain in the first step,
# where it fails fast and says what is missing, rather than letting a build queue
# or die ten minutes in.
#
# **Every channel, one file.** This was `ci-publish-ios.sh` and covered iOS
# alone, because the agent held an *Apple Distribution* certificate and nothing
# else, so any other press could only have failed. The difference between the
# platforms is which wrapper runs and which certificates are asserted, so there
# is one file rather than copies that will drift.
#
# **The certificates the agent needs beyond iOS are still to be installed** —
# task 36 tracks them — and the assertions below are how a press says which one
# is missing, in seconds, rather than after an archive.
#
# **`--platform all` is the button, and the other two are repairs.** A release
# is one marketing version and *one build number* across all three channels,
# and a platform at a time cannot hold that: each press asks App Store Connect
# for the next number and gets a different one, which is how 1.1.1 came to be
# build 10001 on macOS and 10002 on iOS. So `all` hands over to `scripts/ship.sh`
# — already the thing that picks the version once, picks the number once and
# runs macOS `--channel both` then iOS — rather than orchestrating a second
# copy of it here. The Developer ID / Homebrew channel rides along inside that
# macOS run, which is what makes the number shared rather than merely equal.
#
# The price is what the agent has to hold: on top of the App Store
# certificates, a *Developer ID Application* certificate, notarization
# credentials, an authenticated `gh`, and a `homebrew-tap` checkout beside the
# build directory. Every one of them is asserted below before anything is
# built, because the Homebrew half fails at the *end* of a run — after the
# archive, the notarization and a public GitHub release — where there is no way
# to finish and no way back.
#
# Usage:
#   scripts/ci-publish.sh --platform all            # the whole release, one build number
#   scripts/ci-publish.sh --platform ios            # one channel, e.g. re-running a failed leg
#   scripts/ci-publish.sh --platform macos 1.2.0    # exactly this version
#   scripts/ci-publish.sh --platform all --check    # run the assertions and stop
#
# **The first form has to just work, every time the button is pressed.** While
# the project's version is still taking builds it ships that version, so a
# train fills up with TestFlight builds the ordinary way. Once Apple has
# approved it the train is closed and every further upload of it is refused,
# so this asks App Store Connect first and, when the train is closed, ships
# the next patch version instead — `suggest_next_version`, the same answer
# `ship.sh` offers at its prompt. On 2026-09-05 four runs were pressed with
# `publish.args` empty the day after 1.1.2 was approved: three reached altool
# before `release.sh` learned to refuse a closed train, and the fourth was
# refused in two seconds and was still a red build for pressing a button.
# The decision is here and not in `release.sh` on purpose: the engine ships
# the version it is told and never guesses, and this is the one caller that
# is not a person who can be asked.
#
# **`--check` exists because the assertions are the only part of this that can
# be tested without shipping something.** Whether a build agent's login keychain
# is unlocked in its own session cannot be answered from an SSH shell, from a
# unit test, or by reading anything; it needs a build. Without a way to ask that
# question on its own, the only way to find out is to press the button that
# uploads to Apple, pushes a commit and pushes a tag — and to find out by having
# all three not happen. Run this first on a new agent, after an OS update, and
# after anything touches the keychain.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_version.sh"
cd "${SCRIPT_DIR}/.."

# The signing identity `release.sh` archives with. Named once, here, because the
# assertion below and the team it belongs to have to agree. One identity covers
# both platforms: *Apple Distribution* signs an iOS app and a Mac App Store app
# alike.
IDENTITY="Apple Distribution: Nick Pomfret (6FZN56WC8G)"

# **The Mac App Store needs a second certificate, and only for the package.**
# The `.app` is signed with the identity above; the `.pkg` that carries it to
# App Store Connect is signed with the *Mac Installer Distribution* certificate,
# which the keychain still calls by its old name. Absent, the export fails after
# the archive — the expensive half — with a message about a missing installer
# identity rather than a missing certificate.
INSTALLER_IDENTITY="3rd Party Mac Developer Installer: Nick Pomfret (6FZN56WC8G)"

# **A third certificate, for the channel that never touches the App Store.**
# The Homebrew zip is signed with *Developer ID Application* and notarized;
# neither of the two identities above can produce a build Gatekeeper will open
# outside the store. Only `--platform all` needs it.
DEVID_IDENTITY="Developer ID Application: Nick Pomfret (6FZN56WC8G)"

API_KEY_ID="S394C74APG"
PUSH_REMOTE="git@github.com:npomfret/no-spoilers.git"

# **A second key, and it has to be a second one.** `API_KEY_ID` uploads;
# this one lets `xcodebuild` create the provisioning profile, which is a write
# against the developer account and needs the App Manager role. Build 725 is
# what settled that this step is necessary at all: automatic signing with no
# Xcode account falls back to the generic "iOS Team Provisioning Profile: *",
# and the archive then fails naming a missing App Group rather than a missing
# account, which sends you looking at entitlements.
SIGNING_KEY_ID="ASC6H3SL2D"
ASC_ISSUER="69a6de6e-6d3e-47e3-e053-5b8c7c11a4d1"

# **Notarization is given a key rather than a keychain profile.** `release.sh`
# defaults to the `no-spoilers-notarytool` profile, which is right on a laptop
# and wrong here: a profile is created by `notarytool store-credentials` in an
# interactive session and lives in the login keychain, so it is one more thing
# that is present and unusable when that keychain is locked — the failure this
# file exists to catch. An App Store Connect key is a file, and the agent
# already keeps the two above beside it. The App Manager key, because
# notarization is a developer-account action and the upload key's role is not.
NOTARY_KEY_ID="ASC6H3SL2D"

CHECK_ONLY=""
PLATFORM=""
REQUESTED_VERSION=""

# `--platform` is required and has no default. `release.sh` made the same
# decision for the same reason: the only sensible default was one platform, so
# asking for nothing shipped one platform silently. A button that ships the
# wrong store is worse than one that refuses to run.
while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) CHECK_ONLY="yes"; shift ;;
    --platform) PLATFORM="${2:-}"; shift 2 ;;
    -*) echo "ci-publish: unknown option $1" >&2; exit 1 ;;
    # The version is decided below, after the preflight: choosing it can need
    # the App Store Connect key, which step 2 asserts.
    *) REQUESTED_VERSION="$1"; shift ;;
  esac
done

fail() {
  echo "" >&2
  echo "ci-publish: $1" >&2
  exit 1
}

# What this agent actually holds, for a failure that says a certificate is
# missing. The three identity strings above are conventions — a team name and
# a team id, written here by hand — and the first press of a new button is the
# first time anything compares them with the keychain. Printing the real list
# turns "no such identity" into one round trip instead of a guess per attempt.
# The names are not a secret: they are in this file already, and a TeamCity log
# is as private as this repository.
what_the_agent_has() {
  echo "  what this agent does have:" >&2
  security find-identity -v 2>&1 | sed 's/^/  /' >&2
}

case "$PLATFORM" in
  ios)   WRAPPER="ship-ios.sh" ;;
  macos) WRAPPER="ship-appstore.sh" ;;
  all)   WRAPPER="ship.sh" ;;
  "")    fail "--platform is required (all, ios or macos)" ;;
  *)     fail "unknown platform '${PLATFORM}' (expected all, ios or macos)" ;;
esac

# Which extra certificates this run needs, asked once so the assertions below
# and the handover at the bottom cannot disagree about what a platform means.
# `if` rather than `[[ … ]] && …`: under `set -e` the second form exits the
# script whenever the test is false, which is every iOS run.
NEEDS_INSTALLER=""
NEEDS_DEVID=""
if [[ "$PLATFORM" == "macos" || "$PLATFORM" == "all" ]]; then NEEDS_INSTALLER="yes"; fi
if [[ "$PLATFORM" == "all" ]]; then NEEDS_DEVID="yes"; fi

# ── 1. The signing identity has to be usable, not merely present ─────────────
#
# **`security find-identity` listing it is not evidence.** The agents are
# LaunchAgents running as a real user, so they inherit that user's login
# keychain — and a locked keychain lists its identities happily and then refuses
# to sign with `errSecInternalComponent`, which is what an SSH session on this
# machine does today. The difference between the two sessions is exactly the
# thing that cannot be checked from anywhere but inside a build.
#
# So this signs something. A throwaway binary costs milliseconds and answers the
# real question, where `find-identity` answers a different one that looks the
# same in a green log.

echo "==> Asserting the signing identity can actually sign..."
if ! security find-identity -v -p codesigning | grep -qF "${IDENTITY}"; then
  what_the_agent_has
  fail "no '${IDENTITY}' in any keychain this agent can see"
fi

PROBE="$(mktemp -d)"
trap 'rm -rf "${PROBE}"' EXIT
printf 'int main(void){return 0;}\n' > "${PROBE}/probe.c"
clang -o "${PROBE}/probe" "${PROBE}/probe.c" || fail "clang could not build the signing probe"
if ! codesign -s "${IDENTITY}" "${PROBE}/probe" 2>"${PROBE}/err"; then
  echo "  codesign said: $(cat "${PROBE}/err")" >&2
  fail "the identity is present but cannot sign — the login keychain is locked for this session.
Unlock it for the agent, or give the build a dedicated keychain and unlock it here.
An archive would have failed the same way, ten minutes later."
fi

# The installer certificate is a presence check and not a probe, because signing
# a package needs a package: `productbuild` has nothing equivalent to the
# throwaway binary above. `-p codesigning` would not list it — an installer
# identity is not a codesigning one — so this asks for every valid identity.
if [[ -n "$NEEDS_INSTALLER" ]]; then
  echo "==> Asserting the Mac installer identity is present..."
  if ! security find-identity -v | grep -qF "${INSTALLER_IDENTITY}"; then
    what_the_agent_has
    fail "no '${INSTALLER_IDENTITY}' in any keychain this agent can see.
That is the *Mac Installer Distribution* certificate, and without it the export
signs no package: the run would archive first and fail after. Create it in the
Apple Developer portal and install it in the keychain this agent runs under."
  fi
fi

# The Developer ID certificate gets the probe treatment rather than a presence
# check, because it signs a binary like the first one does and the keychain can
# refuse it for exactly the same reason. This is the identity whose failure is
# most expensive: `--channel both` archives, uploads to the App Store, and only
# then exports for Developer ID, so a locked keychain here is discovered after
# a build is already with Apple.
if [[ -n "$NEEDS_DEVID" ]]; then
  echo "==> Asserting the Developer ID identity can actually sign..."
  if ! security find-identity -v -p codesigning | grep -qF "${DEVID_IDENTITY}"; then
    what_the_agent_has
    fail "no '${DEVID_IDENTITY}' in any keychain this agent can see.
That is the *Developer ID Application* certificate, which signs the Homebrew
zip. It is not the one the App Store uses and nothing else can stand in for it."
  fi
  if ! codesign -f -s "${DEVID_IDENTITY}" "${PROBE}/probe" 2>"${PROBE}/err"; then
    echo "  codesign said: $(cat "${PROBE}/err")" >&2
    fail "the Developer ID identity is present but cannot sign."
  fi
fi

# ── 2. The App Store Connect key ─────────────────────────────────────────────
#
# `ship-ios.sh` passes this path and `altool` resolves the key by filename from
# `~/.appstoreconnect/private_keys`. Absent, the upload half of `release.sh`
# silently becomes "print manual upload instructions" and the run goes green
# having delivered nothing — the failure mode this whole file exists to make
# impossible.

echo "==> Asserting the App Store Connect keys are present..."
KEYS="${HOME}/.appstoreconnect/private_keys"
[[ -f "${KEYS}/AuthKey_${API_KEY_ID}.p8" ]] \
  || fail "no AuthKey_${API_KEY_ID}.p8 in ${KEYS} — nothing could be uploaded"
[[ -f "${KEYS}/AuthKey_${SIGNING_KEY_ID}.p8" ]] \
  || fail "no AuthKey_${SIGNING_KEY_ID}.p8 in ${KEYS} — nothing could be signed"

# **Notarization is asked to prove itself, not merely to exist.** `notarytool
# history` is a read: it authenticates, lists this team's past submissions and
# changes nothing, so the credentials that will be used to notarize are the
# credentials that were tested. That matters more here than anywhere else in
# this file — a bad key is discovered by `notarytool submit --wait`, which is
# minutes into the one step that cannot be retried cheaply, with the App Store
# upload already done.
if [[ -n "$NEEDS_DEVID" ]]; then
  [[ -f "${KEYS}/AuthKey_${NOTARY_KEY_ID}.p8" ]] \
    || fail "no AuthKey_${NOTARY_KEY_ID}.p8 in ${KEYS} — nothing could be notarized"
  echo "==> Asserting the notarization credentials work..."
  if ! NOTARY_SAYS="$(xcrun notarytool history \
      --key "${KEYS}/AuthKey_${NOTARY_KEY_ID}.p8" \
      --key-id "${NOTARY_KEY_ID}" \
      --issuer "${ASC_ISSUER}" 2>&1)"; then
    echo "  notarytool said: ${NOTARY_SAYS}" >&2
    fail "AuthKey_${NOTARY_KEY_ID}.p8 cannot talk to the notary service.
The key needs the App Manager role: notarization is a developer-account action
and the upload key is not allowed to take it."
  fi
fi

# ── 3. A push remote that can actually push ──────────────────────────────────
#
# TeamCity checks out the public GitHub remote anonymously and read-only, which
# is right for the five verification configurations and wrong for this one:
# `release.sh` pushes `main` before the archive and the `build/N` tag the
# moment the archive exists, and `tag_approved.py` below pushes an approval
# tag. A tag push that fails leaves an uploaded build whose number is recorded
# nowhere.
#
# Rewritten to SSH rather than carrying a credential, because the agent account
# already holds a key GitHub accepts. That is also the weakness: it is the
# machine's own key, unscoped and shared with everything else that runs here. A
# per-repository deploy key with write access is the better answer and is a
# follow-up, not a blocker.

echo "==> Asserting the checkout can push..."
git remote set-url --push origin "${PUSH_REMOTE}"

# **`ssh -T git@github.com` exits 1 on success.** GitHub authenticates you, says
# so, and closes the connection because it offers no shell — and ssh reports the
# closed connection. Under `set -o pipefail` that made the first version of this
# check fail on a working agent, which cost a whole queue wait to find out. The
# output is what carries the answer, so the output is what is read; the exit code
# is deliberately discarded.
#
# What ssh said is printed on failure. A check that reports "cannot authenticate"
# and hides the reason sends the next person to look at GitHub permissions, which
# is where this one was not.
GITHUB_SAYS="$(ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 \
  -T git@github.com 2>&1 || true)"
case "${GITHUB_SAYS}" in
  *"successfully authenticated"*) ;;
  *) fail "this agent cannot authenticate to GitHub, so the version bump could not be pushed.
GitHub said: ${GITHUB_SAYS}" ;;
esac

git config user.name  >/dev/null || fail "no git user.name on this agent, so nothing this run commits or tags has an author"
git config user.email >/dev/null || fail "no git user.email on this agent, so nothing this run commits or tags has an author"

# ── 3b. What the Homebrew half publishes to ──────────────────────────────────
#
# **This is the tail of the run, which is why it is checked at the head of it.**
# `release.sh` exports for Developer ID, notarizes, staples, creates a *public
# GitHub release*, and only then commits the cask. A missing `gh` login or a
# missing tap checkout is discovered at that last step, with the release
# already published and the App Store upload already done — a half-shipped
# version, and nothing here can unpublish it. `release.sh` makes the same
# argument about the tap in its own preflight; this adds the two things it
# assumes rather than checks, and does it before the queue wait.

if [[ -n "$NEEDS_DEVID" ]]; then
  echo "==> Asserting the Homebrew channel has somewhere to publish..."

  command -v gh >/dev/null \
    || fail "no 'gh' on this agent, so no GitHub release could be created"
  if ! GH_SAYS="$(gh auth status 2>&1)"; then
    echo "  gh said: ${GH_SAYS}" >&2
    fail "'gh' is installed but not logged in, so no GitHub release could be created.
The SSH key checked above pushes git; it does not authenticate the GitHub API."
  fi

  # The same path `release.sh` resolves, computed the same way rather than
  # assumed: it is a sibling of the *checkout*, and a TeamCity checkout lives
  # under the agent's work directory, not beside a laptop's projects.
  TAP_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)/homebrew-tap"
  [[ -f "${TAP_DIR}/Casks/no-spoilers.rb" ]] \
    || fail "no Homebrew cask at ${TAP_DIR}/Casks/no-spoilers.rb.
The Developer ID channel commits the cask to a checkout beside this one. Clone
npomfret/homebrew-tap there — over SSH, because this run pushes it."
  git -C "${TAP_DIR}" rev-parse --git-dir >/dev/null 2>&1 \
    || fail "${TAP_DIR} is not a git checkout, so the cask update could not be pushed"
  git -C "${TAP_DIR}" push --dry-run --quiet \
    || fail "${TAP_DIR} cannot push, so the cask update would be committed and stranded"
fi

# ── 4. Which version ─────────────────────────────────────────────────────────
#
# Told one, ship it; `release.sh` still refuses it if Apple would. Told
# nothing, the answer is `_version.sh: version_to_ship` — the project's version
# while its train is open, the next patch version once it is closed, and a
# stop rather than a guess if App Store Connect did not answer. That decision
# lived here until 2026-09-09 and now lives beside `suggest_next_version`,
# because `ship.sh` needs the same answer and two copies of "which version
# ships" is how they come to disagree. Tags are fetched first because the
# answer skips versions already tagged, and a TeamCity checkout carries none.
#
# **A closed train is also the moment the approval is recorded.** The
# version is closed because users can get one of its builds, and this is the
# first thing that runs after learning so — the same run, before the next
# train opens. `tag_approved.py` writes `ios/vX.Y.Z` on that build's commit,
# and is idempotent, so a version tagged by an earlier press costs a GET. It
# is allowed to stop the run: it fails only when App Store Connect and git
# disagree about which build shipped, and shipping the next version on top
# of that is not the answer.

if [[ -n "$REQUESTED_VERSION" ]]; then
  VERSION="$REQUESTED_VERSION"
else
  PROJECT_VERSION="$(current_marketing_version)"
  git fetch --quiet --tags origin
  echo "==> Asking App Store Connect whether ${PLATFORM} ${PROJECT_VERSION} is still taking builds..."
  VERSION="$(version_to_ship "${PLATFORM}")" \
    || fail "no version was chosen for ${PLATFORM} ${PROJECT_VERSION}"

  if [[ "$VERSION" != "$PROJECT_VERSION" ]]; then
    echo "==> Recording which build of ${PROJECT_VERSION} users got..."
    # One tag per platform, because the approval is per platform and the two
    # trains close on their own schedule. `all` reaches here only when both
    # said closed — `version_to_ship all` refuses to answer otherwise — so both
    # tags are owed and writing one of them would leave the record half true.
    if [[ "$PLATFORM" == "all" ]]; then TAG_PLATFORMS=(macos ios); else TAG_PLATFORMS=("$PLATFORM"); fi
    for TAG_PLATFORM in "${TAG_PLATFORMS[@]}"; do
      if [[ -n "$CHECK_ONLY" ]]; then
        python3 "${SCRIPT_DIR}/tag_approved.py" "${TAG_PLATFORM}" "${PROJECT_VERSION}"
      else
        python3 "${SCRIPT_DIR}/tag_approved.py" "${TAG_PLATFORM}" "${PROJECT_VERSION}" --apply
      fi
    done
    echo "  ${PROJECT_VERSION} is closed, so this run opens ${VERSION}."
  fi
fi

# ── Hand over ────────────────────────────────────────────────────────────────

if [[ -n "$CHECK_ONLY" ]]; then
  echo ""
  echo "This run would ship ${PLATFORM} ${VERSION}."
  echo ""
  echo "Preflight passed. This agent can sign, can upload and can push."
  if [[ -n "$NEEDS_DEVID" ]]; then
    echo "It can also sign with Developer ID, notarize, and publish the cask."
  fi
  echo "Nothing was built and nothing was shipped: --check was passed."
  exit 0
fi

echo ""
echo "==> Preflight passed. Shipping ${PLATFORM} ${VERSION} via scripts/${WRAPPER}..."
echo ""

# The credentials, in the shape every wrapper already forwards to `release.sh`.
# Notarization is added only where it is used, so an iOS run cannot be handed a
# key for a step it does not have.
CREDENTIALS=(
  --signing-key "${KEYS}/AuthKey_${SIGNING_KEY_ID}.p8"
  --signing-key-id "${SIGNING_KEY_ID}"
  --signing-issuer "${ASC_ISSUER}"
)
if [[ -n "$NEEDS_DEVID" ]]; then
  CREDENTIALS+=(
    --notarytool-key "${KEYS}/AuthKey_${NOTARY_KEY_ID}.p8"
    --notarytool-key-id "${NOTARY_KEY_ID}"
    --notarytool-issuer "${ASC_ISSUER}"
  )
fi

exec "${SCRIPT_DIR}/${WRAPPER}" "${VERSION}" "${CREDENTIALS[@]}"
