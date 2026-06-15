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

build_pkg() {
  local variant="$1"
  local identifier="$2"
  local pkg_path="$3"
  local install_obsidian="$4"
  local install_antigravity="$5"
  local allow_existing_workspace="$6"
  local require_existing_workspace="$7"

  local pkg_root="$DIST_DIR/pkg-root-$variant"
  local pkg_payload="$pkg_root/usr/local/share/super-gemmi-macos-installer"
  local pkg_scripts="$DIST_DIR/pkg-scripts-$variant"

  mkdir -p "$pkg_payload" "$pkg_scripts"
  cp "$SCRIPT_DIR/install.sh" "$pkg_payload/install.sh"
  cp "$SCRIPT_DIR/README.md" "$pkg_payload/README.md"
  cp -R "$SCRIPT_DIR/template" "$pkg_payload/template"
  cp "$SCRIPT_DIR/pkg/scripts/postinstall" "$pkg_scripts/postinstall"
  cat > "$pkg_payload/pkg-defaults.env" <<EOF
SUPER_GEMMI_INSTALL_OBSIDIAN="$install_obsidian"
SUPER_GEMMI_INSTALL_CODEX_CLI="false"
SUPER_GEMMI_INSTALL_CODEX_APP="false"
SUPER_GEMMI_INSTALL_ANTIGRAVITY="$install_antigravity"
SUPER_GEMMI_ALLOW_EXISTING_WORKSPACE="$allow_existing_workspace"
SUPER_GEMMI_REQUIRE_EXISTING_WORKSPACE="$require_existing_workspace"
EOF
  chmod +x "$pkg_payload/install.sh" "$pkg_scripts/postinstall"

  pkgbuild \
    --root "$pkg_root" \
    --scripts "$pkg_scripts" \
    --identifier "$identifier" \
    --version "0.1.0" \
    --install-location "/" \
    "$pkg_path"
  echo "$pkg_path"
}

if command -v pkgbuild >/dev/null 2>&1; then
  build_pkg \
    "base" \
    "de.super-gemmi.workspace-installer.base" \
    "$DIST_DIR/Super-Gemmi-macOS-Base.pkg" \
    "false" \
    "false" \
    "false" \
    "false"
  build_pkg \
    "apps" \
    "de.super-gemmi.workspace-installer.apps" \
    "$DIST_DIR/Super-Gemmi-macOS-Apps.pkg" \
    "true" \
    "true" \
    "true" \
    "true"
else
  echo "pkgbuild nicht gefunden; .pkg wird nur auf macOS gebaut." >&2
fi
