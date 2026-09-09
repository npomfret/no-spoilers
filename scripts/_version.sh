#!/usr/bin/env bash
# Sourced helper. Not meant to be executed directly.
#
# Provides:
#   suggest_next_version  Print the next patch version after the highest version
#                         this repo has already claimed, skipping any version
#                         that is already tagged. Falls back to 1.0.0 for a
#                         repo with neither a version tag nor a project version.
#   next_build_number     Print the build number the next upload should carry.
#   current_build_number  Print the CURRENT_PROJECT_VERSION the project holds.
#
# "Already claimed" is the higher of two sources, and it needs both:
#
#   the newest version tag       v*, ios/v* or macos/v* — see below
#   MARKETING_VERSION            what the project will build right now
#
# They come apart whenever a version train is opened without shipping it, which
# is exactly what starting a fresh Xcode Cloud train does — TestFlight build
# numbers are unique per train, so a recreated product with its run counter back
# at 1 needs an unused MARKETING_VERSION and gets one by editing the project, not
# by tagging. Reading tags alone would then suggest a version *below* the one in
# the project, and release.sh seds MARKETING_VERSION to whatever it is given, so
# the suggestion silently walks the project backwards.
#
# **Three tag families, since task 32 (2026-09-05), and each means one thing.**
#
#   build/N       this commit was archived as build N — one per upload, written
#                 by release.sh on the commit it archived, annotated
#   ios/vX.Y.Z    the build of X.Y.Z Apple approved for iOS, on that build's
#   macos/vX.Y.Z  commit — written by scripts/tag_approved.py once App Store
#                 Connect says the version is on the store
#   vX.Y.Z        the macOS Developer ID release — written by release.sh on
#                 that channel only, because the Homebrew cask downloads
#                 `releases/download/vX.Y.Z/…` and the name cannot change
#
# The 26 bare `vX.Y.Z` tags up to and including v1.1.3 predate this and mean
# "the first upload of that train", which is not the build users got: v1.1.2
# marks build 10003 while 10012 is the one on sale. They are left where they
# are — the cask and the GitHub releases point at them — and are history.
# See docs/guides/building.md.

pbxproj_path() {
  local PBXPROJ
  PBXPROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/NoSpoilers/NoSpoilers.xcodeproj/project.pbxproj"
  if [[ ! -f "$PBXPROJ" ]]; then
    echo "no project at ${PBXPROJ}" >&2
    return 1
  fi
  printf '%s' "$PBXPROJ"
}

# The build number the project currently holds. **Not the next upload's
# number**: since task 32 the committed CURRENT_PROJECT_VERSION is frozen at
# 10022, the last upload recorded by a bump commit, and every upload since is
# a build/N tag whose number came from App Store Connect (`next_build_number`
# below). What is left of this is what a local Xcode build stamps into a
# bundle, which is what `mac_screenshots.py` reads it for.
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

# Every version this repository has tagged, under any of the three version
# families, one bare X.Y.Z per line. `|| true` because grep exits 1 on zero
# matches, which under a caller's `set -e -o pipefail` would kill it one line
# before the "nothing tagged yet" case is handled.
tagged_versions() {
  git tag -l 'v*' 'ios/v*' 'macos/v*' \
    | sed -E 's#^(ios/|macos/)?v##' \
    | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' || true
}

# Whether any of the three families already claims this version.
version_tagged() {
  tagged_versions | grep -qx "$1"
}

suggest_next_version() {
  local PBXPROJ TAGGED PROJECT BASE MAJOR MINOR PATCH SUGGESTED
  PBXPROJ="$(pbxproj_path)" || return 1

  # sort -V rather than string order: 1.0.9 must lose to 1.0.22.
  TAGGED=$(tagged_versions | sort -V | tail -1)
  PROJECT=$(grep -m1 -oE 'MARKETING_VERSION = [0-9]+\.[0-9]+\.[0-9]+;' "$PBXPROJ" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')

  BASE=$(printf '%s\n%s\n' "${TAGGED}" "${PROJECT}" \
    | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1)

  if [[ -z "$BASE" ]]; then
    printf '%s' "1.0.0"
    return
  fi

  IFS='.' read -r MAJOR MINOR PATCH <<< "$BASE"
  PATCH=$((PATCH + 1))
  SUGGESTED="${MAJOR}.${MINOR}.${PATCH}"
  while version_tagged "${SUGGESTED}"; do
    PATCH=$((PATCH + 1))
    SUGGESTED="${MAJOR}.${MINOR}.${PATCH}"
  done
  printf '%s' "$SUGGESTED"
}

# ── The next build number ───────────────────────────────────────────────────
#
# **App Store Connect is the authority, because it is the thing that enforces
# the rule.** CFBundleVersion must increase across every upload of the app on
# either platform, and `appstore_status.py --next-build` reads every build the
# record holds and adds one. Until task 32 the counter was the committed
# CURRENT_PROJECT_VERSION and every upload was a commit on `main` whose only
# job was to remember it.
#
# **The build/ tags are the second source, and it needs both.** A number is
# tagged here the moment the archive exists and reaches App Store Connect only
# if the upload then succeeds — a Developer ID release never uploads at all —
# so a number the record has not seen may still be taken. The higher of the
# two, plus one, is free by both accounts. Tags are fetched first because a
# TeamCity checkout does not carry them, and a stale answer here costs an
# archive: the number would be refused at `git tag`, after the build.

highest_tagged_build() {
  git tag -l 'build/*' | sed 's|^build/||' | grep -E '^[0-9]+$' | sort -n | tail -1 || true
}

next_build_number() {
  local SCRIPTS NEXT TAGGED
  SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  git fetch --quiet --tags origin || return 1
  NEXT="$(python3 "${SCRIPTS}/appstore_status.py" --next-build)" || return 1
  if [[ ! "$NEXT" =~ ^[0-9]+$ ]]; then
    echo "appstore_status.py --next-build printed '${NEXT}', not a build number" >&2
    return 1
  fi
  TAGGED="$(highest_tagged_build)"
  if [[ -n "$TAGGED" && "$TAGGED" -ge "$NEXT" ]]; then
    NEXT=$((TAGGED + 1))
  fi
  printf '%s' "$NEXT"
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
# One caller since task 32: NoSpoilers/ci_scripts/ci_pre_xcodebuild.sh, which
# stamps the Xcode Cloud run number into the project before that path
# archives. scripts/release.sh used to be the second — it wrote the next
# number here and committed the file — and now stamps its number on the
# `xcodebuild archive` command line instead, leaving the committed value
# alone. It stays here rather than moving into the hook because it is the
# careful implementation: a second copy in release.sh had drifted into a
# `sed` that silently stamped a subset of the configurations, which is the
# one case where the stamp matters at all.
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
