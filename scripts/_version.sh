#!/usr/bin/env bash
# Sourced helper. Not meant to be executed directly.
#
# Provides:
#   suggest_next_version  Print the next patch version after the highest existing
#                         vX.Y.Z tag, skipping any already-taken tag. Falls back
#                         to 1.0.0 if no tags exist.

suggest_next_version() {
  local LATEST MAJOR MINOR PATCH SUGGESTED
  LATEST=$(git tag --sort=-v:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -1)
  if [[ -n "$LATEST" ]]; then
    IFS='.' read -r MAJOR MINOR PATCH <<< "${LATEST#v}"
    PATCH=$((PATCH + 1))
    SUGGESTED="${MAJOR}.${MINOR}.${PATCH}"
    while git tag | grep -qx "v${SUGGESTED}"; do
      PATCH=$((PATCH + 1))
      SUGGESTED="${MAJOR}.${MINOR}.${PATCH}"
    done
  else
    SUGGESTED="1.0.0"
  fi
  printf '%s' "$SUGGESTED"
}
