#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
mkdir -p .build/module-cache .build/cache .build/config .build/security
export CLANG_MODULE_CACHE_PATH="$project_dir/.build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$project_dir/.build/module-cache"
# A tiny executable harness keeps checks runnable with Command Line Tools alone;
# no Xcode-only test runner or downloaded testing package is required.
swift run --disable-sandbox --cache-path .build/cache --config-path .build/config --security-path .build/security WalkCoreChecks
