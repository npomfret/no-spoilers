#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

mkdir -p \
  "$repo_root/tmp/home" \
  "$repo_root/tmp/home/.cache" \
  "$repo_root/tmp/DerivedData/NoSpoilersApp" \
  "$repo_root/tmp/SourcePackages" \
  "$repo_root/tmp/clang-module-cache"

export HOME="$repo_root/tmp/home"
export CFFIXED_USER_HOME="$repo_root/tmp/home"
export XDG_CACHE_HOME="$repo_root/tmp/home/.cache"
export CLANG_MODULE_CACHE_PATH="$repo_root/tmp/clang-module-cache"
export MODULE_CACHE_DIR="$repo_root/tmp/clang-module-cache"
export SWIFT_MODULE_CACHE_PATH="$repo_root/tmp/clang-module-cache"

xcodebuild build \
  -project "$repo_root/NoSpoilers/NoSpoilers.xcodeproj" \
  -scheme "NoSpoilersApp" \
  -destination "generic/platform=iOS" \
  -derivedDataPath "$repo_root/tmp/DerivedData/NoSpoilersApp" \
  -clonedSourcePackagesDirPath "$repo_root/tmp/SourcePackages" \
  CODE_SIGNING_ALLOWED=NO \
  COMPILER_INDEX_STORE_ENABLE=NO \
  CLANG_MODULE_CACHE_PATH="$repo_root/tmp/clang-module-cache" \
  MODULE_CACHE_DIR="$repo_root/tmp/clang-module-cache" \
  SWIFT_MODULE_CACHE_PATH="$repo_root/tmp/clang-module-cache"
