#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$(mktemp -d "${TMPDIR:-/tmp}/super-gemmi-workspace.XXXXXX")"

cleanup() {
  rm -rf "$TARGET"
}
trap cleanup EXIT

"$SCRIPT_DIR/install.sh" \
  --target "$TARGET" \
  --user "Test User" \
  --agent "Gemmi" \
  --no-app-installs

test -d "$TARGET"
test -f "$TARGET/AGENTS.md"
test -f "$TARGET/Gemini.md"
test -f "$TARGET/soul_bundle.md"
test -f "$TARGET/User.md"
test -f "$TARGET/Identity.md"
test -d "$TARGET/Wiki"
test -d "$TARGET/Memory"

if grep -R "{WORKSPACE}\|{USER}\|{AGENT}" "$TARGET"; then
  echo "Nicht ersetzte Platzhalter gefunden." >&2
  exit 1
fi

test -f "$HOME/Library/Application Support/obsidian/obsidian.json"
grep -F "System-Kerne geladen" "$TARGET/AGENTS.md" >/dev/null
grep -F "System-Kerne geladen" "$TARGET/Gemini.md" >/dev/null
grep -F "$TARGET/AGENTS.md" "$TARGET/Gemini.md" >/dev/null
grep -F "START_FILE: Identity.md" "$TARGET/soul_bundle.md" >/dev/null

echo "macOS smoke test ok: $TARGET"
