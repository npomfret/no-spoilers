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
#   scripts/ci-publish-ios.sh          # ships the version the project holds
#   scripts/ci-publish-ios.sh 1.1.3    # opens a new version train

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_version.sh"
cd "${SCRIPT_DIR}/.."

# The signing identity `release.sh` archives with. Named once, here, because the
# assertion below and the team it belongs to have to agree.
IDENTITY="Apple Distribution: Nick Pomfret (6FZN56WC8G)"
API_KEY_ID="S394C74APG"
PUSH_REMOTE="git@github.com:npomfret/no-spoilers.git"

VERSION="${1:-$(current_marketing_version)}"

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

echo "==> Asserting the App Store Connect key is present..."
[[ -f "${HOME}/.appstoreconnect/private_keys/AuthKey_${API_KEY_ID}.p8" ]] \
  || fail "no AuthKey_${API_KEY_ID}.p8 in ${HOME}/.appstoreconnect/private_keys"

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
ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 \
  -T git@github.com 2>&1 | grep -q "successfully authenticated" \
  || fail "this agent cannot authenticate to GitHub, so the version bump could not be pushed"

git config user.name  >/dev/null || fail "no git user.name on this agent, so the bump commit has no author"
git config user.email >/dev/null || fail "no git user.email on this agent, so the bump commit has no author"

# ── Hand over ────────────────────────────────────────────────────────────────

echo ""
echo "==> Preflight passed. Shipping iOS ${VERSION} via scripts/ship-ios.sh..."
echo ""
exec "${SCRIPT_DIR}/ship-ios.sh" "${VERSION}"
