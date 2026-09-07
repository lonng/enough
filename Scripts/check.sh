#!/bin/bash
set -euo pipefail
ENOUGH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
swift run --package-path "$ENOUGH_ROOT" --scratch-path "${ENOUGH_BUILD_DIR:-$ENOUGH_ROOT/.build/checks}" EnoughChecks
