#!/usr/bin/env bash
# Sourced helper. Not meant to be executed directly.
#
# Provides:
#   suggest_next_version  Print the next patch version after the highest version
#                         this repo has already claimed, skipping any tag that is
#                         already taken. Falls back to 1.0.0 for a repo with
#                         neither a version tag nor a project version.
#
# "Already claimed" is the higher of two sources, and it needs both:
#
#   the newest vX.Y.Z tag        what release.sh last shipped
#   MARKETING_VERSION            what the project will build right now
#
# They come apart whenever a version train is opened without shipping it, which
# is exactly what starting a fresh Xcode Cloud train does — TestFlight build
# numbers are unique per train, so a recreated product with its run counter back
# at 1 needs an unused MARKETING_VERSION and gets one by editing the project, not
# by tagging. Reading tags alone would then suggest a version *below* the one in
# the project, and release.sh seds MARKETING_VERSION to whatever it is given, so
# the suggestion silently walks the project backwards.

suggest_next_version() {
  local PBXPROJ TAGGED PROJECT BASE MAJOR MINOR PATCH SUGGESTED
  PBXPROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/NoSpoilers/NoSpoilers.xcodeproj/project.pbxproj"
  if [[ ! -f "$PBXPROJ" ]]; then
    echo "suggest_next_version: no project at ${PBXPROJ}" >&2
    return 1
  fi

  TAGGED=$(git tag --sort=-v:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -1)
  PROJECT=$(grep -m1 -oE 'MARKETING_VERSION = [0-9]+\.[0-9]+\.[0-9]+;' "$PBXPROJ" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')

  # sort -V rather than string order: 1.0.9 must lose to 1.0.22.
  BASE=$(printf '%s\n%s\n' "${TAGGED#v}" "${PROJECT}" \
    | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1)

  if [[ -z "$BASE" ]]; then
    printf '%s' "1.0.0"
    return
  fi

  IFS='.' read -r MAJOR MINOR PATCH <<< "$BASE"
  PATCH=$((PATCH + 1))
  SUGGESTED="${MAJOR}.${MINOR}.${PATCH}"
  while git tag | grep -qx "v${SUGGESTED}"; do
    PATCH=$((PATCH + 1))
    SUGGESTED="${MAJOR}.${MINOR}.${PATCH}"
  done
  printf '%s' "$SUGGESTED"
}
