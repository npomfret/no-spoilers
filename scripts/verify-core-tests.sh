#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

mkdir -p \
  "$repo_root/tmp/home" \
  "$repo_root/tmp/home/.cache" \
  "$repo_root/tmp/swiftpm/NoSpoilersCore" \
  "$repo_root/tmp/test-results" \
  "$repo_root/tmp/clang-module-cache"

export HOME="$repo_root/tmp/home"
export CFFIXED_USER_HOME="$repo_root/tmp/home"
export XDG_CACHE_HOME="$repo_root/tmp/home/.cache"
export CLANG_MODULE_CACHE_PATH="$repo_root/tmp/clang-module-cache"
export MODULE_CACHE_DIR="$repo_root/tmp/clang-module-cache"
export SWIFT_MODULE_CACHE_PATH="$repo_root/tmp/clang-module-cache"

# The run's full output beside its report, in the folder `Verify: Swift tests`
# publishes: the report names a failing test, the log has what it printed.
# One worker, so the suite stays serial: SwiftPM writes XCTest's report only in
# its parallel mode, and without `--parallel` the run passes with no report.
swift test \
  --disable-sandbox \
  --package-path "$repo_root/NoSpoilersCore" \
  --scratch-path "$repo_root/tmp/swiftpm/NoSpoilersCore" \
  --parallel --num-workers 1 \
  --xunit-output "$repo_root/tmp/test-results/NoSpoilersCore.xml" \
  -Xcc "-fmodules-cache-path=$repo_root/tmp/clang-module-cache" \
  2>&1 | tee "$repo_root/tmp/test-results/swift-test.log"
