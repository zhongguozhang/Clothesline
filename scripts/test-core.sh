#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$PWD/.build/ModuleCache}"
export SWIFT_MODULECACHE_PATH="${SWIFT_MODULECACHE_PATH:-$CLANG_MODULE_CACHE_PATH}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
swiftc Sources/Clothesline/DownloadIndex.swift Sources/Clothesline/DisplayPreferences.swift Tests/DownloadIndexTests.swift -o "$TMP/tests"
"$TMP/tests"
