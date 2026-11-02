#!/usr/bin/env bash
set -euo pipefail

# The CI entry point for a delivery. Runs on a TeamCity agent.
#
#   --platform ios|macos       Apple: TestFlight, one platform per run, as
#                              `Ship iOS` and `Ship macOS`. Hands over to
#                              `scripts/submit_build.py`, which archives the
#                              verified commit, uploads, waits for processing
#                              and delivers that exact build to the testers.
#
# **Deliberately thin.** What decides anything lives in the engine it hands
# over to. What is left is the things those engines reasonably assume about the
# machine, which are false by default on a build agent. Each is asserted here,
# in seconds, before anything expensive — `docs/TEAMCITY-AGENTS.md` §7's recipe:
# assert the toolchain in the first step, where it fails fast and names what is
# missing.
#
# Usage:
#   scripts/ci-publish.sh --platform ios --tested          # what Ship iOS runs
#   scripts/ci-publish.sh --platform macos --tested        # what Ship macOS runs
#   scripts/ci-publish.sh --platform macos --archive-only  # prove signing, upload nothing
#   scripts/ci-publish.sh --platform ios --check           # assert the agent, then a dry run
#
# Anything else after an Apple platform goes to `submit_build.py` unchanged,
# except `--apply`, which is refused: this script adds it to a real run itself.
# `--tested` belongs in the TeamCity step, beside the snapshot dependency on
# `Verify` that makes it true, and nowhere else.
#
# **`--check` exists because the assertions are the only part of this that can
# be tested without shipping something.** Whether an agent's login keychain is
# unlocked in its own session cannot be answered from an SSH shell, from a unit
# test, or by reading anything; it needs a build. Run it first on a new agent,
# after an OS update, and after anything touches the keychain. For an Apple
# platform it then runs `submit_build.py` without `--apply`, which asks App
# Store Connect everything a real run would and changes nothing.
#
# **It reports every gap, where a real press stops at the first.** An agent that
# has never shipped is missing several things at once, and one per press is a
# queue wait each. See `refuse`.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "${SCRIPT_DIR}/.."

# The signing identity every Apple archive uses. *Apple Distribution* signs an
# iOS app and a Mac App Store app alike.
IDENTITY="Apple Distribution: Nick Pomfret (6FZN56WC8G)"

# **The Mac App Store needs a second certificate, and only for the package.**
# The `.app` is signed with the identity above; the `.pkg` that carries it to
# App Store Connect is signed with *Mac Installer Distribution*, which the
# keychain calls by its old name. **On an agent it has to be local.** A laptop
# whose Xcode is signed in as the Account Holder cloud-signs the package; an
# agent has only the App Manager key, and Ship #8 (2026-09-10) showed Apple
# refuses that key cloud-managed certificates. This check was removed for that
# run and put back once the certificate was created on this Mac. See task 38.
INSTALLER_IDENTITY="3rd Party Mac Developer Installer: Nick Pomfret (6FZN56WC8G)"

# The Developer key reads App Store Connect for the next build number.
# The App Manager key authenticates signing and delivery.
# `asc_write.ADMIN_KEY_ID` and `appstore_status.KEY_ID` are the same two.
READ_KEY_ID="S394C74APG"
ADMIN_KEY_ID="ASC6H3SL2D"

PUSH_REMOTE="git@github.com:npomfret/no-spoilers.git"

CHECK_ONLY=""
APPLY_PASSED=""
PLATFORM=""
FORWARD=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check)
      CHECK_ONLY="yes"
      shift
      ;;
    --apply)
      APPLY_PASSED="yes"
      shift
      ;;
    --platform)
      PLATFORM="${2:-}"
      shift 2
      ;;
    *)
      FORWARD+=("$1")
      shift
      ;;
  esac
done

fail() {
  echo "" >&2
  echo "ci-publish: $1" >&2
  exit 1
}

# **`--apply` is this script's to add, and it never adds it under `--check`.**
# Until 2026-09-10 a supplied `--apply` travelled with the other arguments to
# `--check`'s dry run, so `--check --apply` would have reserved, uploaded and
# delivered under a banner saying it changed nothing. Refused here, before a
# single assertion. `submit_build.py` refuses abbreviations, so `--app` cannot
# stand in for it.
if [[ -n "$APPLY_PASSED" ]]; then
  fail "--apply is not an argument here: a real run passes it to submit_build.py itself, and --check never does"
fi

# **A failed assertion stops the run, except under `--check`, which carries on.**
# A real press wants the first gap: everything after it describes a machine that
# cannot ship anyway. `--check` wants every gap, because its job is to describe
# the agent — the first two presses on 2026-09-09 both stopped at the same
# missing certificate with four assertions behind it still unrun.
#
# Returns 0 either way, so `cmd || refuse "..."` does not end under `set -e` the
# run this is trying to continue. A check that depends on an earlier one is
# guarded rather than left to fail again, so one gap is one message.
GAPS=()
refuse() {
  if [[ -z "$CHECK_ONLY" ]]; then fail "$1"; fi
  GAPS+=("$1")
  return 0
}

# What this agent actually holds, printed once, for a failure that says a
# certificate is missing. The identity strings above are written by hand and the
# first press is the first comparison with a real keychain.
IDENTITIES_PRINTED=""
what_the_agent_has() {
  if [[ -n "$IDENTITIES_PRINTED" ]]; then return 0; fi
  IDENTITIES_PRINTED="yes"
  echo "  what this agent does have:" >&2
  security find-identity -v 2>&1 | sed 's/^/  /' >&2
}

case "$PLATFORM" in
  ios | macos) ;;
  "") fail "--platform is required (ios or macos)" ;;
  *) fail "unknown platform '${PLATFORM}' (expected ios or macos; one Apple platform per run)" ;;
esac

# `if` rather than `[[ … ]] && …`: under `set -e` the second form exits the
# script whenever the test is false.
NEEDS_INSTALLER=""
if [[ "$PLATFORM" == "macos" ]]; then NEEDS_INSTALLER="yes"; fi

KEYS="${HOME}/.appstoreconnect/private_keys"

# ── A throwaway binary to sign ───────────────────────────────────────────────
#
# **`security find-identity` listing an identity is not evidence it can sign.**
# The agents are LaunchAgents running as a real user and inherit that user's
# login keychain; a locked keychain lists its identities happily and then
# refuses with `errSecInternalComponent`. Signing something answers the real
# question. An explicit template, because macOS `mktemp -d` without one ignores
# `TMPDIR` — measured 2026-09-10.

PROBE="$(mktemp -d "${TMPDIR:-/tmp}/ci-publish-probe.XXXXXX")"
trap 'rm -rf "${PROBE}"' EXIT
printf 'int main(void){return 0;}\n' >"${PROBE}/probe.c"
# `fail` and not `refuse`: a broken compiler is no certificate problem.
clang -o "${PROBE}/probe" "${PROBE}/probe.c" || fail "clang could not build the signing probe"

# Signs the probe with one identity, or records why it could not.
probe_identity() {
  local NAME="$1" WHAT="$2"
  if ! security find-identity -v -p codesigning | grep -qF "${NAME}"; then
    what_the_agent_has
    refuse "no '${NAME}' in any keychain this agent can see. ${WHAT}"
  elif ! codesign -f -s "${NAME}" "${PROBE}/probe" 2>"${PROBE}/err"; then
    echo "  codesign said: $(cat "${PROBE}/err")" >&2
    refuse "'${NAME}' is present but cannot sign — the login keychain is locked for this session.
Unlock it for the agent, or give the build a dedicated keychain and unlock it here."
  fi
}

# ── Shared: a checkout that can push a tag, with an author ──────────────────
#
# TeamCity checks out the public remote anonymously and read-only, which is
# right for the verification configurations and wrong here: both platforms push
# a `build/N` tag, and a tag push that fails leaves a number recorded nowhere.
# Rewritten to SSH rather than carrying a credential, because the agent account
# already holds a key GitHub accepts — the machine's own, unscoped, which a
# per-repository deploy key would improve on.
#
# **`ssh -T git@github.com` exits 1 on success**: GitHub authenticates, says so
# and offers no shell. The output carries the answer, so the output is read.
assert_push() {
  echo "==> Asserting the checkout can push a tag..."
  git remote set-url --push origin "${PUSH_REMOTE}"
  local SAYS
  SAYS="$(ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 \
    -T git@github.com 2>&1 || true)"
  case "${SAYS}" in
    *"successfully authenticated"*) ;;
    *) refuse "this agent cannot authenticate to GitHub, so no build/ tag could be pushed.
GitHub said: ${SAYS}" ;;
  esac
  git config user.name >/dev/null || refuse "no git user.name on this agent, so no tag this run writes has an author"
  git config user.email >/dev/null || refuse "no git user.email on this agent, so no tag this run writes has an author"
}

report_gaps() {
  if [[ ${#GAPS[@]} -eq 0 ]]; then return 0; fi
  echo "" >&2
  echo "ci-publish: this agent cannot deliver ${PLATFORM}. ${#GAPS[@]} of the preflight assertions failed:" >&2
  local NUMBER=0 GAP
  for GAP in "${GAPS[@]}"; do
    NUMBER=$((NUMBER + 1))
    echo "" >&2
    echo "${NUMBER}. ${GAP}" >&2
  done
  echo "" >&2
  echo "Nothing was built and nothing was shipped: --check was passed." >&2
  exit 1
}

echo "==> Asserting the signing identity can actually sign..."
probe_identity "${IDENTITY}" "It signs every Apple archive, on both platforms."

# A presence check and not a probe: signing a package needs a package, and
# `productbuild` has nothing like the throwaway binary. `-p codesigning`
# would not list it — an installer identity is not a codesigning one.
# `--archive-only` on macOS is the proof that it signs: it exports the
# package and checks its signature without uploading anything.
if [[ -n "$NEEDS_INSTALLER" ]]; then
  echo "==> Asserting the Mac installer identity is present..."
  if ! security find-identity -v | grep -qF "${INSTALLER_IDENTITY}"; then
    what_the_agent_has
    refuse "no '${INSTALLER_IDENTITY}' in any keychain this agent can see.
That is the *Mac Installer Distribution* certificate, and without it the export
signs no package: the run would archive first and fail after. It has to be local:
Apple refuses the App Manager key cloud-managed certificates (Ship #8). Create it
in Xcode's Manage Certificates on the agent machine, in the login keychain of the
user the agents run as."
  fi
fi

echo "==> Asserting the App Store Connect keys are present..."
[[ -f "${KEYS}/AuthKey_${READ_KEY_ID}.p8" ]] ||
  refuse "no AuthKey_${READ_KEY_ID}.p8 in ${KEYS} — nothing could read App Store Connect"
[[ -f "${KEYS}/AuthKey_${ADMIN_KEY_ID}.p8" ]] ||
  refuse "no AuthKey_${ADMIN_KEY_ID}.p8 in ${KEYS} — nothing could be signed, uploaded or delivered"

assert_push
report_gaps

if [[ -n "$CHECK_ONLY" ]]; then
  echo ""
  echo "==> Preflight passed. What a real run would do, asking App Store Connect and changing nothing:"
  # The arguments the real run gets below, without `--apply`. Until 2026-09-10
  # they were dropped here, so `--tested` never arrived and Ship #6 described a
  # test gate that its real run would have skipped.
  python3 "${SCRIPT_DIR}/submit_build.py" --platform "${PLATFORM}" "${FORWARD[@]+"${FORWARD[@]}"}"
  exit $?
fi

echo ""
echo "==> Preflight passed. Handing over to scripts/submit_build.py --platform ${PLATFORM}..."
exec python3 "${SCRIPT_DIR}/submit_build.py" --platform "${PLATFORM}" --apply \
  "${FORWARD[@]+"${FORWARD[@]}"}"
