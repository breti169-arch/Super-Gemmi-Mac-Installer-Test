#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST_DIR="$SCRIPT_DIR/dist"
PACKAGE_ROOT="$DIST_DIR/Super-Gemmi-macOS-Installer"

rm -rf "$DIST_DIR"
mkdir -p "$PACKAGE_ROOT"

cp "$SCRIPT_DIR/install.sh" "$PACKAGE_ROOT/install.sh"
cp "$SCRIPT_DIR/test-install.sh" "$PACKAGE_ROOT/test-install.sh"
cp "$SCRIPT_DIR/README.md" "$PACKAGE_ROOT/README.md"
cp -R "$SCRIPT_DIR/template" "$PACKAGE_ROOT/template"

chmod +x "$PACKAGE_ROOT/install.sh" "$PACKAGE_ROOT/test-install.sh"

export DIST_DIR PACKAGE_ROOT
python3 <<'PY'
import os
import zipfile
from pathlib import Path

dist = Path(os.environ["DIST_DIR"])
package_root = Path(os.environ["PACKAGE_ROOT"])
zip_path = dist / "Super-Gemmi-macOS-Installer.zip"

with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
    for path in package_root.rglob("*"):
        archive.write(path, path.relative_to(dist))
PY

echo "$DIST_DIR/Super-Gemmi-macOS-Installer.zip"
