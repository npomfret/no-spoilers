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
# See docs/guides/building.md.

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
#
# `set_build_number` lives in `scripts/_version.sh` rather than here, and
# since task 32 this is its only caller: `scripts/release.sh` stamps its
# number on the `xcodebuild archive` command line and records it as a
# `build/N` tag, leaving the committed CURRENT_PROJECT_VERSION alone. It was
# repeated in both until 2026-08-22, and the two copies had drifted in the way
# that matters: this one used `agvtool -all` and then counted the
# configurations that took the value, and release.sh used a `sed` keyed on
# whichever value it read first and counted nothing. It stays shared so that
# the careful implementation is the only one.

# shellcheck disable=SC1091
source "${CI_PRIMARY_REPOSITORY_PATH}/scripts/_version.sh"

echo "ci_pre_xcodebuild: stamping CURRENT_PROJECT_VERSION ${CI_BUILD_NUMBER}"
set_build_number "${CI_BUILD_NUMBER}"
