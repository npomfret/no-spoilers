#!/usr/bin/env bash
set -euo pipefail

# Xcode Cloud hook: runs before EVERY xcodebuild invocation in a build action.
#
# Two jobs:
#   1. Gate delivery on the NoSpoilersCore tests.
#   2. Stamp CURRENT_PROJECT_VERSION with the run number, so the archive agrees
#      with the build that gets uploaded.
#
# A non-zero exit here fails the enclosing action before anything is uploaded.
# That is deliberate — see the gate section below.
#
# The stamp is CI_BUILD_NUMBER exactly, with no offset. An earlier version added
# 1000 to keep clear of the build numbers scripts/release.sh produces, and it
# could never have worked: Xcode Cloud rewrites CFBundleVersion to
# CI_BUILD_NUMBER when it exports the IPA, after this hook and after the archive
# action. Run 3 proved it — the xcarchive read 1003, the uploaded IPA read 3.
# The two upload paths are kept apart on release.sh's side instead, which is the
# one nothing overrides: its committed CURRENT_PROJECT_VERSION starts at 10000.
# See tasks/14-xcode-cloud-testflight.md, Phase 0 Decision 1.

echo "ci_pre_xcodebuild: run ${CI_BUILD_NUMBER:-<unset>}, commit ${CI_COMMIT:-<unset>}"

# Not every stage has a checkout. This hook runs before each xcodebuild
# invocation, and some stages run on a machine holding the built products and
# nothing else, with CI_PRIMARY_REPOSITORY_PATH unset. Under `set -u` that is an
# exit 1 one stage after the script did its job correctly.
if [[ -z "${CI_PRIMARY_REPOSITORY_PATH:-}" ]]; then
  echo "ci_pre_xcodebuild: no checkout in this stage, nothing to stamp"
  exit 0
fi

if [[ -z "${CI_BUILD_NUMBER:-}" ]]; then
  echo "ci_pre_xcodebuild: CI_BUILD_NUMBER is unset" >&2
  exit 1
fi

# ── The gate ─────────────────────────────────────────────────────────────────
#
# Xcode Cloud does not gate delivery on its TEST action: actions run
# concurrently and the distribution audience belongs to the archive action
# alone, so a run with red tests still puts a build on a tester's phone. A
# failing pre-build hook does stop it. This line is the only thing standing
# between a broken commit and TestFlight — do not remove it without replacing
# the gate.

echo "ci_pre_xcodebuild: running scripts/verify-core-tests.sh"
"${CI_PRIMARY_REPOSITORY_PATH}/scripts/verify-core-tests.sh"
echo "ci_pre_xcodebuild: core tests passed"

# ── The stamp ────────────────────────────────────────────────────────────────

build="${CI_BUILD_NUMBER}"
cd "${CI_PRIMARY_REPOSITORY_PATH}/NoSpoilers"

# `-all` updates every build configuration, which is what we need:
# NoSpoilersWidgetExtension carries its own CURRENT_PROJECT_VERSION and is
# embedded in NoSpoilersApp. An app whose extension disagrees about its build
# number is rejected at upload.
#
# agvtool also prints `Cannot find ".../YES"` here. That is it misreading
# GENERATE_INFOPLIST_FILE = YES as a plist path. It is noise, it does not affect
# the exit status, and it is not the failure you are looking for.
xcrun agvtool new-version -all "${build}"

# Trust the file, not the tool: agvtool exits 0 in cases where it changed
# nothing at all. Every occurrence must carry the new value, not just the first
# one — a partial stamp is the extension-mismatch rejection above.
#
# `|| true` on both counts: grep exits 1 on zero matches, and under `set -e` that
# would kill the script one line before the message explaining why.
pbxproj="NoSpoilers.xcodeproj/project.pbxproj"
total=$(grep -c "CURRENT_PROJECT_VERSION = " "${pbxproj}" || true)
stamped=$(grep -c "CURRENT_PROJECT_VERSION = ${build};" "${pbxproj}" || true)

if [[ "${total}" -eq 0 || "${stamped}" -ne "${total}" ]]; then
  echo "ci_pre_xcodebuild: agvtool exited 0 but stamped ${stamped}/${total} configurations" >&2
  grep -n "CURRENT_PROJECT_VERSION" "${pbxproj}" >&2
  exit 1
fi

echo "ci_pre_xcodebuild: CURRENT_PROJECT_VERSION is now ${build} in all ${total} configurations"
