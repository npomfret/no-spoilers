#!/usr/bin/env bash
# Sourced helper. Not meant to be executed directly.
#
# Reads the committed marketing/build versions, suggests the next marketing
# version, allocates the next build number, and opens marketing versions.
# Apple delivery and screenshot tooling share these reads.
#
# `build/N` reserves an archive number; `ios/vX.Y.Z` and `macos/vX.Y.Z`
# identify the builds Apple approved. Bare `vX.Y.Z` tags are retained history.
# All version families remain inputs so an already-used version is not offered
# again. A version is opened by open-version.sh, never by an archive operation.

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
# number**: since 2026-09-05 the committed CURRENT_PROJECT_VERSION is frozen at
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
  VERSION=$(grep -m1 -oE 'MARKETING_VERSION = [0-9]+\.[0-9]+\.[0-9]+;' "$PBXPROJ" |
    grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
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
  git tag -l 'v*' 'ios/v*' 'macos/v*' |
    sed -E 's#^(ios/|macos/)?v##' |
    grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' || true
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

  BASE=$(printf '%s\n%s\n' "${TAGGED}" "${PROJECT}" |
    grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1)

  if [[ -z "$BASE" ]]; then
    printf '%s' "1.0.0"
    return
  fi

  IFS='.' read -r MAJOR MINOR PATCH <<<"$BASE"
  PATCH=$((PATCH + 1))
  SUGGESTED="${MAJOR}.${MINOR}.${PATCH}"
  while version_tagged "${SUGGESTED}"; do
    PATCH=$((PATCH + 1))
    SUGGESTED="${MAJOR}.${MINOR}.${PATCH}"
  done
  printf '%s' "$SUGGESTED"
}

# There is no `version_to_ship` here any more. It chose the version a ship
# carried — the project's own while its train was open, the next one once Apple
# had closed it — for `ship.sh` and `ci-publish.sh`, and both stopped choosing on
# 2026-09-10: `submit_build.py` refuses a closed train, and `open-version.sh`
# opens the next version as a commit. Nothing that archives picks a version.

# ── The next build number ───────────────────────────────────────────────────
#
# **App Store Connect is the authority, because it is the thing that enforces
# the rule.** CFBundleVersion must increase across every upload of the app on
# either platform, and `appstore_status.py --next-build` reads every build the
# record holds and adds one. Until 2026-09-05 the counter was the committed
# CURRENT_PROJECT_VERSION and every upload was a commit on `main` whose only
# job was to remember it.
#
# **The build/ tags are the second source, and it needs both.** A number is
# reserved here before archiving and reaches App Store Connect only if the
# upload succeeds, so a number the record has not seen may still be taken. The higher of the
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

# There is no `set_build_number` here any more. It wrote CURRENT_PROJECT_VERSION
# into every build configuration, and nothing calls it now: release.sh stopped
# on 2026-09-05, stamping its number on the `xcodebuild archive` command
# line instead, and its last caller was the Xcode Cloud hook, deleted with the
# rest of that path. The committed value is frozen at 10022 and only Xcode
# stamps it now, into a local build, which is what `mac_screenshots.py` reads.
# `set_marketing_version` below is the survivor, and it proves its work the same
# careful way: a `sed` succeeds having matched nothing.

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
