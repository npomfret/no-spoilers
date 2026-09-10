#!/usr/bin/env bash
set -euo pipefail

# Open a marketing version: set MARKETING_VERSION, commit `open vX.Y.Z`, push.
#
# **The one way the version changes, since 2026-09-10.** Apple takes builds of a
# version until it approves one, and then refuses every further upload of it
# after the archive. `scripts/submit_build.py` checks that first, refuses a
# closed train, and names this command — it never opens a version itself,
# because a version changed by the thing that archives is an archive of a
# commit nothing verified. Opened here, the change is an ordinary commit:
# TeamCity verifies it and `Ship` delivers it like any other.
#
# **The version only moves forward.** A lower or equal version, or one any
# version tag already claims, is refused: `release.sh` used to set whatever it
# was given, and an older version on `main` is a project that silently builds
# a closed train.
#
# Refuses a dirty tree and a checkout that is not exactly `origin/main`, so the
# commit carries this one change and the push cannot need a rebase. A rejected
# push is not retried: `main` moved, and pulling and running this again costs
# less than guessing what landed.
#
# Usage:
#   scripts/open-version.sh 1.1.5

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_version.sh"
cd "${SCRIPT_DIR}/.."

VERSION="${1:-}"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "usage: scripts/open-version.sh X.Y.Z (got: '${VERSION}')" >&2
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "The working tree is not clean, and this commit must carry the version change alone:" >&2
  git status --short >&2
  exit 1
fi

git fetch --quiet --tags origin +refs/heads/main:refs/remotes/origin/main
if [[ "$(git rev-parse HEAD)" != "$(git rev-parse refs/remotes/origin/main)" ]]; then
  echo "This checkout is not exactly origin/main. Check out main and bring it level first." >&2
  exit 1
fi

CURRENT="$(current_marketing_version)"
HIGHER="$(printf '%s\n%s\n' "$CURRENT" "$VERSION" | sort -V | tail -1)"
if [[ "$VERSION" == "$CURRENT" || "$HIGHER" != "$VERSION" ]]; then
  echo "The project is already at ${CURRENT}; a version only moves forward, and ${VERSION} does not." >&2
  exit 1
fi
if version_tagged "$VERSION"; then
  echo "A version tag already claims ${VERSION}. Pick the next one: $(suggest_next_version)" >&2
  exit 1
fi

set_marketing_version "$VERSION"
git add "$(pbxproj_path)"
git commit -q -m "open v${VERSION}" \
  -m "MARKETING_VERSION moves from ${CURRENT} to ${VERSION}. Every upload of it is a build/N tag on the commit it was archived from."
echo "  committed: $(git log -1 --format='%h %s')"

if ! git push --quiet origin HEAD:main; then
  echo "" >&2
  echo "The push was refused, so main moved since the fetch. The commit is local only;" >&2
  echo "reset it (git reset --hard origin/main after fetching), pull, and run this again." >&2
  exit 1
fi
echo "Pushed. TeamCity verifies it, and Ship delivers ${VERSION} once Verify is green."
