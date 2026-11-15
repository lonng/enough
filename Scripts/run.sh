#!/bin/bash
set -euo pipefail
ENOUGH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENOUGH_DIST="${ENOUGH_OUTPUT_DIR:-$ENOUGH_ROOT/dist}"
ENOUGH_APP="$ENOUGH_DIST/Enough.app"
if [[ ! -x "$ENOUGH_APP/Contents/MacOS/Enough" ]]; then
  printf 'No built app at %s. Run make build first.\n' "$ENOUGH_APP" >&2
  exit 1
fi
osascript -l JavaScript "$ENOUGH_ROOT/Scripts/quit-running.js"
open -n "$ENOUGH_APP" --args --show
