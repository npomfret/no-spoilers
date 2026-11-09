#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

mkdir -p \
  "$repo_root/tmp/home" \
  "$repo_root/tmp/home/.cache" \
  "$repo_root/tmp/DerivedData/NoSpoilersMac" \
  "$repo_root/tmp/SourcePackages" \
  "$repo_root/tmp/clang-module-cache"

export HOME="$repo_root/tmp/home"
export CFFIXED_USER_HOME="$repo_root/tmp/home"
export XDG_CACHE_HOME="$repo_root/tmp/home/.cache"
export CLANG_MODULE_CACHE_PATH="$repo_root/tmp/clang-module-cache"
export MODULE_CACHE_DIR="$repo_root/tmp/clang-module-cache"
export SWIFT_MODULE_CACHE_PATH="$repo_root/tmp/clang-module-cache"

# **What a failure needs without a re-run**: the full xcodebuild log and Xcode's
# result bundle, one folder per build, which `Verify: Xcode` publishes. Named for
# the configuration because this script runs twice per build, and a result
# bundle path that already exists is an error. Emptied first, so a local run
# never leaves an earlier build's evidence behind.
configuration="default"
previous=""
for argument in "$@"; do
  if [[ "$previous" == "-configuration" ]]; then configuration="$argument"; fi
  previous="$argument"
done
evidence="$repo_root/tmp/build-evidence/mac-$configuration"
rm -rf "$evidence"
mkdir -p "$evidence"

xcodebuild build \
  -resultBundlePath "$evidence/build.xcresult" \
  -project "$repo_root/NoSpoilers/NoSpoilers.xcodeproj" \
  -scheme "NoSpoilers" \
  -destination "generic/platform=macOS" \
  -derivedDataPath "$repo_root/tmp/DerivedData/NoSpoilersMac" \
  -clonedSourcePackagesDirPath "$repo_root/tmp/SourcePackages" \
  "$@" \
  CODE_SIGNING_ALLOWED=NO \
  COMPILER_INDEX_STORE_ENABLE=NO \
  CLANG_MODULE_CACHE_PATH="$repo_root/tmp/clang-module-cache" \
  MODULE_CACHE_DIR="$repo_root/tmp/clang-module-cache" \
  SWIFT_MODULE_CACHE_PATH="$repo_root/tmp/clang-module-cache" \
  2>&1 | tee "$evidence/xcodebuild.log"
