#!/usr/bin/env bash
set -euo pipefail

# The CI entry point for an iOS TestFlight upload. Runs on a TeamCity agent.
#
# **Deliberately thin.** Everything worth arguing about — the clean-tree refusal,
# the spent-build-number GET, the `verify-core-tests.sh` gate, the archive, the
# upload, the bump commit and the tag — is in `release.sh`, which has shipped
# real builds and must stay the one release engine. There is no second one here
# and there must never be.
#
# What is left is the three things `release.sh` reasonably assumes about the
# machine it runs on, and which are all false by default on a build agent. Each
# is asserted here, in seconds, before anything expensive happens. That is the
# recipe `docs/TEAMCITY-AGENTS.md` §243 names: assert the toolchain in the first
# step, where it fails fast and says what is missing, rather than letting a
# build queue or die ten minutes in.
#
# Usage:
#   scripts/ci-publish-ios.sh          # ships the project's version, or the next one
#   scripts/ci-publish-ios.sh 1.2.0    # ships exactly this version
#   scripts/ci-publish-ios.sh --check  # run the assertions and stop
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
# assertion below and the team it belongs to have to agree.
IDENTITY="Apple Distribution: Nick Pomfret (6FZN56WC8G)"
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

CHECK_ONLY=""
if [[ "${1:-}" == "--check" ]]; then
  CHECK_ONLY="yes"
  shift
fi
# The version is decided below, after the preflight: choosing it can need the
# App Store Connect key, which step 2 asserts.
REQUESTED_VERSION="${1:-}"

fail() {
  echo "" >&2
  echo "ci-publish-ios: $1" >&2
  exit 1
}

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
security find-identity -v -p codesigning | grep -qF "${IDENTITY}" \
  || fail "no '${IDENTITY}' in any keychain this agent can see"

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

# ── 3. A push remote that can actually push ──────────────────────────────────
#
# TeamCity checks out the public GitHub remote anonymously and read-only, which
# is right for the five verification configurations and wrong for this one:
# `release.sh` commits the version bump and pushes it, then pushes a tag, and it
# does both *after* the archive exists. A push that fails there leaves an
# uploaded build whose number is recorded nowhere.
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

git config user.name  >/dev/null || fail "no git user.name on this agent, so the bump commit has no author"
git config user.email >/dev/null || fail "no git user.email on this agent, so the bump commit has no author"

# ── 4. Which version ─────────────────────────────────────────────────────────
#
# Told one, ship it; `release.sh` still refuses it if Apple would. Told
# nothing, ship the project's version while its train is open and the next
# patch version once it is closed. The question is `appstore_status.py
# --train`, and its exit codes are read the same way `release.sh` reads
# `--spent`: 0 open, 3 closed, anything else means the question was not
# answered and the run stops rather than guessing. Tags are fetched first
# because `suggest_next_version` skips versions that are already tagged, and
# a TeamCity checkout does not carry them on its own.

if [[ -n "$REQUESTED_VERSION" ]]; then
  VERSION="$REQUESTED_VERSION"
else
  PROJECT_VERSION="$(current_marketing_version)"
  echo "==> Asking App Store Connect whether ios ${PROJECT_VERSION} is still taking builds..."
  set +e
  python3 "${SCRIPT_DIR}/appstore_status.py" --train ios "${PROJECT_VERSION}"
  TRAIN_STATUS=$?
  set -e
  case "$TRAIN_STATUS" in
    0) VERSION="$PROJECT_VERSION" ;;
    3)
      git fetch --quiet --tags origin
      VERSION="$(suggest_next_version)"
      echo "  ${PROJECT_VERSION} is closed, so this run opens ${VERSION}."
      ;;
    *) fail "could not find out whether ${PROJECT_VERSION} is still taking builds (exit ${TRAIN_STATUS}), so no version was chosen" ;;
  esac
fi

# ── Hand over ────────────────────────────────────────────────────────────────

if [[ -n "$CHECK_ONLY" ]]; then
  echo ""
  echo "This run would ship iOS ${VERSION}."
  echo ""
  echo "Preflight passed. This agent can sign, can upload and can push."
  echo "Nothing was built and nothing was shipped: --check was passed."
  exit 0
fi

echo ""
echo "==> Preflight passed. Shipping iOS ${VERSION} via scripts/ship-ios.sh..."
echo ""
exec "${SCRIPT_DIR}/ship-ios.sh" "${VERSION}" \
  --signing-key "${KEYS}/AuthKey_${SIGNING_KEY_ID}.p8" \
  --signing-key-id "${SIGNING_KEY_ID}" \
  --signing-issuer "${ASC_ISSUER}"
