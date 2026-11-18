#!/bin/bash
set -euo pipefail
ENOUGH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENOUGH_DIST="${ENOUGH_OUTPUT_DIR:-$ENOUGH_ROOT/dist}"
ENOUGH_APP="$ENOUGH_DIST/Enough.app"
ENOUGH_INSTALL_DIR="${ENOUGH_INSTALL_DIR:-/Applications}"
ENOUGH_IDENTITY="${ENOUGH_SIGN_IDENTITY:-}"
if [[ ! -w "$ENOUGH_INSTALL_DIR" ]]; then
  printf 'Cannot write to %s. Check permissions or set ENOUGH_INSTALL_DIR.\n' "$ENOUGH_INSTALL_DIR" >&2
  exit 1
fi
if [[ -z "$ENOUGH_IDENTITY" ]] && security find-identity -p codesigning 2>/dev/null | grep -q '"Enough Development"'; then
  ENOUGH_IDENTITY="Enough Development"
fi
if [[ -n "$ENOUGH_IDENTITY" ]]; then
  printf 'Signing as: %s\n' "$ENOUGH_IDENTITY"
else
  printf 'No stable signing identity; using an ad hoc signature. Run make dev-identity once to keep Accessibility across installs.\n' >&2
fi
ENOUGH_SIGN_IDENTITY="${ENOUGH_IDENTITY:--}" "$ENOUGH_ROOT/Scripts/build.sh"
if [[ ! -x "$ENOUGH_APP/Contents/MacOS/Enough" ]]; then
  printf 'Build did not produce %s.\n' "$ENOUGH_APP" >&2
  exit 1
fi
osascript -l JavaScript "$ENOUGH_ROOT/Scripts/quit-running.js"
ENOUGH_INSTALLED="$ENOUGH_INSTALL_DIR/Enough.app"
rm -rf "$ENOUGH_INSTALLED"
ditto "$ENOUGH_APP" "$ENOUGH_INSTALLED"
open -n "$ENOUGH_INSTALLED" --args --show
printf 'Installed: %s\n' "$ENOUGH_INSTALLED"
