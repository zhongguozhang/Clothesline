#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$PWD/.build/ModuleCache}"
export SWIFT_MODULECACHE_PATH="${SWIFT_MODULECACHE_PATH:-$CLANG_MODULE_CACHE_PATH}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
swiftc -parse-as-library $(find Sources/Clothesline -name '*.swift' ! -name main.swift) Tests/MacIntegrationTests.swift Tests/AppServicesTests.swift Tests/MissionControlTests.swift Tests/MissionControlReplayTests.swift Tests/MissionControlReturnTests.swift -o "$TMP/tests"
"$TMP/tests"
