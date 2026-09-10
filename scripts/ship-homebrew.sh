#!/usr/bin/env bash
set -euo pipefail

# Release the macOS Developer ID / Homebrew channel: notarized zip, GitHub
# release, cask. Independent of TestFlight delivery, which is
# scripts/submit_build.py; neither waits for the other.
#
# Releases the version the commit holds. Notarizes with the keychain profile
# "no-spoilers-notarytool" unless given --notarytool-key, which
# `ci-publish.sh --platform homebrew` passes.
#
# Usage:
#   scripts/ship-homebrew.sh          # the project's version
#   scripts/ship-homebrew.sh 1.1.4    # the same, stated

exec "$(dirname "$0")/release.sh" "$@"
