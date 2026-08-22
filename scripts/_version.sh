#!/usr/bin/env bash
# Sourced helper. Not meant to be executed directly.
#
# Provides:
#   suggest_next_version  Print the next patch version after the highest version
#                         this repo has already claimed, skipping any tag that is
#                         already taken. Falls back to 1.0.0 for a repo with
#                         neither a version tag nor a project version.
#   current_build_number  Print the CURRENT_PROJECT_VERSION the project holds.
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

pbxproj_path() {
  local PBXPROJ
  PBXPROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/NoSpoilers/NoSpoilers.xcodeproj/project.pbxproj"
  if [[ ! -f "$PBXPROJ" ]]; then
    echo "no project at ${PBXPROJ}" >&2
    return 1
  fi
  printf '%s' "$PBXPROJ"
}

# The build number the project currently holds. Shared because ship.sh has to
# know it before it calls release.sh: one ship run is one build number across
# every platform, and two readers of the same line would drift.
current_build_number() {
  local PBXPROJ BUILD
  PBXPROJ="$(pbxproj_path)" || return 1
  BUILD=$(grep -m1 -E "CURRENT_PROJECT_VERSION = [0-9]+;" "$PBXPROJ" | grep -oE "[0-9]+")
  if [[ -z "$BUILD" ]]; then
    echo "could not read CURRENT_PROJECT_VERSION from ${PBXPROJ}" >&2
    return 1
  fi
  printf '%s' "$BUILD"
}

# The MARKETING_VERSION the project holds. Shared for the same reason as
# current_build_number: anything that needs to know what this checkout builds
# must read the one line, not its own grep of the same file.
current_marketing_version() {
  local PBXPROJ VERSION
  PBXPROJ="$(pbxproj_path)" || return 1
  VERSION=$(grep -m1 -oE 'MARKETING_VERSION = [0-9]+\.[0-9]+\.[0-9]+;' "$PBXPROJ" \
    | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
  if [[ -z "$VERSION" ]]; then
    echo "could not read MARKETING_VERSION from ${PBXPROJ}" >&2
    return 1
  fi
  printf '%s' "$VERSION"
}

suggest_next_version() {
  local PBXPROJ TAGGED PROJECT BASE MAJOR MINOR PATCH SUGGESTED
  PBXPROJ="$(pbxproj_path)" || return 1

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

# ── Writing the version into the project ────────────────────────────────────
#
# Both setters prove their work against the file afterwards. Neither tool is
# trustworthy on its own: `agvtool` exits 0 in cases where it changed nothing,
# and a `sed` reports success for a pattern that matched no lines. The failure
# they guard is silent and expensive — NoSpoilersWidgetExtension carries its own
# CURRENT_PROJECT_VERSION and is embedded in NoSpoilersApp, and an app whose
# extension disagrees about its build number is refused at upload, after the
# archive, the export and the wait.

# Set CURRENT_PROJECT_VERSION in every build configuration.
#
# One implementation, two callers: scripts/release.sh on a laptop and
# NoSpoilers/ci_scripts/ci_pre_xcodebuild.sh in Xcode Cloud. It was two until
# 2026-08-22 and only the CI one counted its work — release.sh used a `sed`
# keyed on whichever CURRENT_PROJECT_VERSION it read first, which silently
# stamps a subset the moment the configurations disagree. That is the only case
# where the stamp matters at all, so the careful half was missing from exactly
# the path that now ships everything.
set_build_number() {
  local BUILD="$1" PBXPROJ TOTAL STAMPED
  if [[ ! "$BUILD" =~ ^[0-9]+$ ]]; then
    echo "set_build_number needs a whole number (got: ${BUILD})" >&2
    return 1
  fi
  PBXPROJ="$(pbxproj_path)" || return 1

  # agvtool reads the directory it is run from, not a path. It also prints
  # `Cannot find ".../YES"` — that is it misreading GENERATE_INFOPLIST_FILE = YES
  # as a plist path. Noise, not the failure you are looking for.
  ( cd "$(dirname "$(dirname "${PBXPROJ}")")" && xcrun agvtool new-version -all "${BUILD}" ) || return 1

  # `|| true` on both: grep exits 1 on zero matches, which under `set -e` would
  # kill the caller one line before the message explaining why.
  TOTAL=$(grep -cF "CURRENT_PROJECT_VERSION = " "${PBXPROJ}" || true)
  STAMPED=$(grep -cF "CURRENT_PROJECT_VERSION = ${BUILD};" "${PBXPROJ}" || true)
  if [[ "$TOTAL" -eq 0 || "$STAMPED" -ne "$TOTAL" ]]; then
    echo "agvtool exited 0 but stamped ${STAMPED}/${TOTAL} configurations" >&2
    grep -n "CURRENT_PROJECT_VERSION" "${PBXPROJ}" >&2
    return 1
  fi
  echo "  CURRENT_PROJECT_VERSION = ${BUILD} in all ${TOTAL} configurations"
}

# Set MARKETING_VERSION in every build configuration.
#
# The pattern is unguarded on the current value, unlike the build number's used
# to be, so it cannot stamp a subset — but it can still match nothing at all if
# the project stops spelling the setting this way, and a release that silently
# ships the previous version string is worth one grep to rule out.
set_marketing_version() {
  local VERSION="$1" PBXPROJ TOTAL STAMPED
  if [[ -z "$VERSION" ]]; then
    echo "set_marketing_version needs a version" >&2
    return 1
  fi
  PBXPROJ="$(pbxproj_path)" || return 1

  sed -i '' "s/MARKETING_VERSION = .*;/MARKETING_VERSION = ${VERSION};/g" "${PBXPROJ}"

  TOTAL=$(grep -cF "MARKETING_VERSION = " "${PBXPROJ}" || true)
  STAMPED=$(grep -cF "MARKETING_VERSION = ${VERSION};" "${PBXPROJ}" || true)
  if [[ "$TOTAL" -eq 0 || "$STAMPED" -ne "$TOTAL" ]]; then
    echo "MARKETING_VERSION is ${VERSION} in ${STAMPED}/${TOTAL} configurations" >&2
    grep -n "MARKETING_VERSION" "${PBXPROJ}" >&2
    return 1
  fi
  echo "  MARKETING_VERSION = ${VERSION} in all ${TOTAL} configurations"
}
