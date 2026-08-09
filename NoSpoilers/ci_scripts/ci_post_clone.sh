#!/usr/bin/env bash

# Xcode Cloud hook: runs after the repository is cloned, before anything builds.
#
# Writes the TestFlight "What to Test" note from the commit being built, so the
# tester note is never stale and nobody has to remember to write one.
#
# Opposite rule to ci_pre_xcodebuild.sh: a non-zero exit here fails the ENTIRE
# run, not just one action. No missing tester note is worth a failed delivery,
# so every path below ends at exit 0 and `set -e` is deliberately not used.
# Do not put the test gate in this script.

repo="${CI_PRIMARY_REPOSITORY_PATH:-}"
if [[ -z "${repo}" ]]; then
  echo "ci_post_clone: CI_PRIMARY_REPOSITORY_PATH is unset, skipping tester note"
  exit 0
fi

# Apple looks for this directory beside the Xcode project, not at the repo root.
notes_dir="${repo}/NoSpoilers/TestFlight"
out="${notes_dir}/WhatToTest.en-GB.txt"

echo "ci_post_clone: writing ${out}"
mkdir -p "${notes_dir}" || exit 0

subject=$(git -C "${repo}" log -1 --format=%s "${CI_COMMIT:-HEAD}" 2>/dev/null)
short=$(printf '%s' "${CI_COMMIT:-}" | cut -c1-12)

if [[ -n "${subject}" ]]; then
  printf '%s\n\nBuild %s from %s\n' "${subject}" "${CI_BUILD_NUMBER:-?}" "${short:-unknown}" > "${out}"
else
  printf 'Build %s from %s\n' "${CI_BUILD_NUMBER:-?}" "${short:-unknown}" > "${out}"
fi

# Echo on success deliberately: an empty log is indistinguishable from a script
# that never ran, and Xcode Cloud gives you nothing else to tell them apart.
cat "${out}"
exit 0
