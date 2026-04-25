#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

mkdir -p \
  "$repo_root/tmp/home" \
  "$repo_root/tmp/home/.cache" \
  "$repo_root/tmp/swiftpm/NoSpoilersCore" \
  "$repo_root/tmp/clang-module-cache"

export HOME="$repo_root/tmp/home"
export CFFIXED_USER_HOME="$repo_root/tmp/home"
export XDG_CACHE_HOME="$repo_root/tmp/home/.cache"
export CLANG_MODULE_CACHE_PATH="$repo_root/tmp/clang-module-cache"
export MODULE_CACHE_DIR="$repo_root/tmp/clang-module-cache"
export SWIFT_MODULE_CACHE_PATH="$repo_root/tmp/clang-module-cache"

swift test \
  --disable-sandbox \
  --package-path "$repo_root/NoSpoilersCore" \
  --scratch-path "$repo_root/tmp/swiftpm/NoSpoilersCore" \
  -Xcc "-fmodules-cache-path=$repo_root/tmp/clang-module-cache"
