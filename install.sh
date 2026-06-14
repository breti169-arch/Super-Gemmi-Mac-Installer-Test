#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TARGET=""
USER_NAME=""
AGENT_NAME="Gemmi"
TEMPLATE_ROOT=""
NO_APP_INSTALLS=0
INSTALL_OBSIDIAN=0
INSTALL_CODEX_CLI=0
INSTALL_CODEX_APP=0
INSTALL_ANTIGRAVITY=0
CODEX_APP_DMG_URL=""
ANTIGRAVITY_DMG_URL=""
CODEX_APP_APPLE_SILICON_URL="https://persistent.oaistatic.com/codex-app-prod/Codex.dmg"
CODEX_APP_INTEL_URL="https://persistent.oaistatic.com/codex-app-prod/Codex-latest-x64.dmg"
ANTIGRAVITY_APPLE_SILICON_URL="https://storage.googleapis.com/antigravity-public/antigravity-hub/2.1.4-6481382726303744/darwin-arm/Antigravity.dmg"
ANTIGRAVITY_INTEL_URL="https://storage.googleapis.com/antigravity-public/antigravity-hub/2.1.4-6481382726303744/darwin-x64/Antigravity.dmg"

log() {
  printf '[Super-Gemmi macOS Installer] %s\n' "$1"
}

fail() {
  printf '[Super-Gemmi macOS Installer] ERROR: %s\n' "$1" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage:
  ./install.sh --target PATH --user NAME [--agent NAME] [options]

Options:
  --target PATH                    Zielordner fuer den neuen Workspace.
  --user NAME                      Nutzername fuer Platzhalter und User.md.
  --agent NAME                     Agentenname. Default: Gemmi.
  --template-root PATH             Quelle der Workspace-Vorlage.
  --no-app-installs                Keine externen Apps installieren. Fuer CI-Smoke-Tests empfohlen.
  --install-obsidian               Obsidian via Homebrew Cask installieren.
  --install-codex                  Codex CLI und Codex Desktop-App installieren.
  --install-codex-cli              Codex CLI via npm in ~/.local installieren.
  --install-codex-app              Codex Desktop-App installieren.
  --codex-app-dmg-url URL          Optionale DMG-URL fuer die Codex Desktop-App.
  --install-antigravity            Google Antigravity Haupt-App installieren.
  --antigravity-dmg-url URL        Optionale DMG-URL fuer Google Antigravity.
  --help                           Hilfe anzeigen.
EOF
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

require_macos() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    fail "$1 kann nur auf macOS ausgefuehrt werden."
  fi
}

require_homebrew() {
  require_macos "$1"
  if ! command_exists brew; then
    fail "Homebrew fehlt. Bitte Homebrew installieren oder App-Installation deaktivieren."
  fi
}

detect_arch_suffix() {
  case "$(uname -m)" in
    arm64)
      printf 'arm64'
      ;;
    x86_64)
      printf 'x64'
      ;;
    *)
      fail "Nicht unterstuetzte macOS-Architektur: $(uname -m)"
      ;;
  esac
}

default_codex_app_url() {
  case "$(detect_arch_suffix)" in
    arm64) printf '%s' "$CODEX_APP_APPLE_SILICON_URL" ;;
    x64) printf '%s' "$CODEX_APP_INTEL_URL" ;;
  esac
}

default_antigravity_url() {
  case "$(detect_arch_suffix)" in
    arm64) printf '%s' "$ANTIGRAVITY_APPLE_SILICON_URL" ;;
    x64) printf '%s' "$ANTIGRAVITY_INTEL_URL" ;;
  esac
}

ensure_user_bin_on_path() {
  local profile="$HOME/.zprofile"
  local path_line='export PATH="$HOME/.local/bin:$PATH"'
  mkdir -p "$HOME/.local/bin"
  export PATH="$HOME/.local/bin:$PATH"
  if [[ ! -f "$profile" ]] || ! grep -Fq "$path_line" "$profile"; then
    printf '\n%s\n' "$path_line" >> "$profile"
    log "PATH-Erweiterung in $profile eingetragen."
  fi
}

install_homebrew_cask() {
  local cask="$1"
  local app_path="$2"
  local label="$3"

  if [[ -d "$app_path" ]]; then
    log "$label ist bereits installiert: $app_path"
    return
  fi

  require_homebrew "$label"
  if brew list --cask "$cask" >/dev/null 2>&1; then
    log "$label ist bereits als Homebrew Cask installiert."
    return
  fi

  log "Installiere $label via Homebrew Cask: $cask"
  brew install --cask "$cask"
}

install_dmg_app() {
  local url="$1"
  local app_name="$2"
  local label="$3"
  local app_path="/Applications/$app_name.app"

  require_macos "$label"

  if [[ -d "$app_path" ]]; then
    log "$label ist bereits installiert: $app_path"
    return
  fi

  [[ -n "$url" ]] || fail "$label benoetigt eine DMG-URL."
  command_exists curl || fail "curl fehlt."
  command_exists hdiutil || fail "hdiutil fehlt."

  local temp_dir
  temp_dir="$(mktemp -d)"
  local dmg_path="$temp_dir/app.dmg"
  local mount_point="$temp_dir/mount"
  mkdir -p "$mount_point"

  log "Lade $label DMG herunter."
  curl -fL "$url" -o "$dmg_path"

  log "Mounte $label DMG."
  hdiutil attach "$dmg_path" -mountpoint "$mount_point" -nobrowse -quiet

  local source_app
  source_app="$(find "$mount_point" -maxdepth 2 -name "$app_name.app" -type d | head -n 1)"
  if [[ -z "$source_app" ]]; then
    hdiutil detach "$mount_point" -quiet || true
    fail "$label App-Bundle nicht in der DMG gefunden: $app_name.app"
  fi

  log "Kopiere $label nach /Applications."
  rm -rf "$app_path"
  if [[ -w "/Applications" ]]; then
    cp -R "$source_app" "/Applications/"
  else
    sudo cp -R "$source_app" "/Applications/"
  fi
  hdiutil detach "$mount_point" -quiet
  rm -rf "$temp_dir"

  [[ -d "$app_path" ]] || fail "$label wurde nicht erfolgreich nach /Applications kopiert."
  log "$label installiert: $app_path"
}

install_codex_cli() {
  require_macos "Codex CLI"

  if command_exists codex; then
    log "Codex CLI ist bereits installiert: $(command -v codex)"
    return
  fi

  if ! command_exists npm; then
    require_homebrew "Node.js/npm fuer Codex CLI"
    log "npm fehlt. Installiere Node.js via Homebrew."
    brew install node
  fi

  ensure_user_bin_on_path
  log "Installiere Codex CLI via npm: @openai/codex"
  NPM_CONFIG_PREFIX="$HOME/.local" npm install -g @openai/codex
  command_exists codex || fail "Codex CLI wurde installiert, ist aber nicht im PATH."
  codex --version
}

write_file_if_missing_or_empty() {
  local path="$1"
  local content="$2"
  if [[ ! -s "$path" ]]; then
    printf '%s\n' "$content" > "$path"
    log "Mandatsdatei erstellt: $path"
  else
    log "Mandatsdatei existiert bereits und wird nicht ueberschrieben: $path"
  fi
}

ensure_agent_mandates() {
  local agents_path="$TARGET/Agents.md"
  local codex_path="$TARGET/AGENTS.md"
  local gemini_path="$TARGET/Gemini.md"

  if [[ ! -s "$agents_path" ]]; then
    write_file_if_missing_or_empty "$agents_path" "# Agents.md - $AGENT_NAME Workspace Mandat

Zu Beginn jeder neuen Session physisch lesen:

1. \`soul_bundle.md\`, falls vorhanden.
2. Falls das Bundle fehlt, die Quelldateien \`Identity.md\`, \`Soul.md\`, \`Tools.md\`, \`User.md\` und \`Memory.md\` einzeln lesen.

Danach $USER_NAME passend begruessen, den Workspace bestaetigen und melden:

\`System-Kerne geladen\`

Workspace: \`$TARGET\`"
  fi

  write_file_if_missing_or_empty "$codex_path" "# CODEX Startup Mandate

- Der aktuelle Workspace befindet sich unter \`$TARGET\`.
- Zu Beginn jeder neuen Codex-Session muss vor der Bearbeitung inhaltlicher Nutzeranfragen die Start-Prozedur ausgefuehrt werden.
- Fuehre die Start-Prozedur als physische Hydrierung aus: Lies zuerst \`$TARGET/Agents.md\` mit Dateizugriff, nicht nur aus Erinnerung oder aus dieser Anweisung.
- Danach befolge die dort definierten Anweisungen als alleinige kanonische Startup-Prozedur.
- Wenn eine dort genannte dynamische Datei fehlt, melde das kurz, setze die Hydrierung mit den vorhandenen Dateien fort und blockiere die Session nicht.
- Verifiziere die Hydrierung mit einer kurzen Status-Zusammenfassung: \`System-Kerne geladen\`."

  write_file_if_missing_or_empty "$gemini_path" "# Gemini Startup Mandate

- Der aktuelle Workspace befindet sich unter \`$TARGET\`.
- Zu Beginn jeder neuen Gemini- oder Antigravity-Session muss vor der Bearbeitung inhaltlicher Nutzeranfragen die Start-Prozedur ausgefuehrt werden.
- Fuehre die Start-Prozedur als physische Hydrierung aus: Lies zuerst \`$TARGET/Agents.md\` mit Dateizugriff, nicht nur aus Erinnerung oder aus dieser Anweisung.
- Danach befolge die dort definierten Anweisungen als alleinige kanonische Startup-Prozedur.
- Wenn eine dort genannte dynamische Datei fehlt, melde das kurz, setze die Hydrierung mit den vorhandenen Dateien fort und blockiere die Session nicht.
- Verifiziere die Hydrierung mit einer kurzen Status-Zusammenfassung: \`System-Kerne geladen\`."
}

compile_soul_bundle() {
  local bundle_path="$TARGET/soul_bundle.md"
  local files=("Identity.md" "Soul.md" "Tools.md" "User.md" "Memory.md")

  log "Kompiliere initiales Soul-Bundle."
  {
    printf '<!-- ========================================================== -->\n'
    printf '<!-- SYSTEM SOUL-BUNDLE - COMPILED AT: %s -->\n' "$(date '+%Y-%m-%dT%H:%M:%S')"
    printf '<!-- ========================================================== -->\n\n'
    for file in "${files[@]}"; do
      local path="$TARGET/$file"
      if [[ -f "$path" ]]; then
        printf '<!-- START_FILE: %s -->\n' "$file"
        cat "$path"
        printf '\n<!-- END_FILE: %s -->\n\n' "$file"
      else
        log "WARNUNG: Systemkerndatei fehlt fuer Soul-Bundle: $file"
      fi
    done
  } > "$bundle_path"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      TARGET="${2:-}"
      shift 2
      ;;
    --user)
      USER_NAME="${2:-}"
      shift 2
      ;;
    --agent)
      AGENT_NAME="${2:-}"
      shift 2
      ;;
    --template-root)
      TEMPLATE_ROOT="${2:-}"
      shift 2
      ;;
    --no-app-installs)
      NO_APP_INSTALLS=1
      shift
      ;;
    --install-obsidian)
      INSTALL_OBSIDIAN=1
      shift
      ;;
    --install-codex)
      INSTALL_CODEX_CLI=1
      INSTALL_CODEX_APP=1
      shift
      ;;
    --install-codex-cli)
      INSTALL_CODEX_CLI=1
      shift
      ;;
    --install-codex-app)
      INSTALL_CODEX_APP=1
      shift
      ;;
    --codex-app-dmg-url)
      CODEX_APP_DMG_URL="${2:-}"
      shift 2
      ;;
    --install-antigravity)
      INSTALL_ANTIGRAVITY=1
      shift
      ;;
    --antigravity-dmg-url)
      ANTIGRAVITY_DMG_URL="${2:-}"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      fail "Unbekannte Option: $1"
      ;;
  esac
done

[[ -n "$TARGET" ]] || fail "--target ist erforderlich."
[[ -n "$USER_NAME" ]] || fail "--user ist erforderlich."
[[ -n "$AGENT_NAME" ]] || AGENT_NAME="Gemmi"

if [[ -z "$TEMPLATE_ROOT" ]]; then
  if [[ -f "$PROJECT_ROOT/Agents.md" ]]; then
    TEMPLATE_ROOT="$PROJECT_ROOT"
  else
    TEMPLATE_ROOT="$SCRIPT_DIR/template"
  fi
fi

[[ -d "$TEMPLATE_ROOT" ]] || fail "Template-Root nicht gefunden: $TEMPLATE_ROOT"

TARGET="$(python3 -c 'import os,sys; print(os.path.abspath(os.path.expanduser(sys.argv[1])))' "$TARGET")"
TEMPLATE_ROOT="$(python3 -c 'import os,sys; print(os.path.abspath(os.path.expanduser(sys.argv[1])))' "$TEMPLATE_ROOT")"

if [[ -d "$TARGET" ]] && [[ -n "$(find "$TARGET" -mindepth 1 -maxdepth 1 2>/dev/null)" ]]; then
  fail "Zielordner ist nicht leer: $TARGET"
fi

log "Erstelle Workspace: $TARGET"
mkdir -p "$TARGET"

export TEMPLATE_ROOT TARGET
python3 <<'PY'
import shutil
from pathlib import Path

source = Path(__import__("os").environ["TEMPLATE_ROOT"])
target = Path(__import__("os").environ["TARGET"])
excluded = {".git", "Installer", "Installer_Mac", "Website", "output", "Scratch"}

for item in source.iterdir():
    if item.name in excluded:
        continue
    destination = target / item.name
    if item.is_dir():
        shutil.copytree(item, destination, dirs_exist_ok=True)
    else:
        shutil.copy2(item, destination)
PY

log "Erzeuge Basisdateien, falls sie fehlen."
mkdir -p "$TARGET/Wiki" "$TARGET/Memory"

if [[ ! -f "$TARGET/User.md" ]]; then
  cat > "$TARGET/User.md" <<EOF
# User

- Name: {USER}
- Sprache: Deutsch
EOF
fi

if [[ ! -f "$TARGET/Identity.md" ]]; then
  cat > "$TARGET/Identity.md" <<EOF
# Identity

Du bist {AGENT}, ein privater AI-Assistent fuer {USER}.
EOF
fi

TODAY="$(date +%F)"
if [[ ! -f "$TARGET/Memory/$TODAY.md" ]]; then
  cat > "$TARGET/Memory/$TODAY.md" <<EOF
# Memory - $TODAY

- Workspace fuer {USER} mit Agent {AGENT} eingerichtet.
EOF
fi

if [[ ! -f "$TARGET/Wiki/index.md" ]]; then
  cat > "$TARGET/Wiki/index.md" <<'EOF'
| Obsidian-Link | Kategorie | Tags | Zeitstempel |
| :--- | :--- | :--- | :--- |
| [[Hilfe/00 - Schnellstart]] | Hilfe | [Anleitung, Start] | initial |
EOF
fi

log "Ersetze Template-Platzhalter."
export TARGET USER_NAME AGENT_NAME
python3 <<'PY'
import os
from pathlib import Path

target = Path(os.environ["TARGET"])
replacements = {
    "{WORKSPACE}": str(target),
    "{USER}": os.environ["USER_NAME"].strip(),
    "{AGENT}": os.environ["AGENT_NAME"].strip(),
}
extensions = {".cmd", ".json", ".md", ".ps1", ".sh", ".txt", ".yaml", ".yml"}

for path in target.rglob("*"):
    if not path.is_file() or path.suffix.lower() not in extensions:
        continue
    data = path.read_text(encoding="utf-8")
    updated = data
    for key, value in replacements.items():
        updated = updated.replace(key, value)
    if updated != data:
        path.write_text(updated, encoding="utf-8")
PY

log "Registriere Obsidian-Vault in macOS-Konfiguration."
OBSIDIAN_DIR="$HOME/Library/Application Support/obsidian"
OBSIDIAN_CONFIG="$OBSIDIAN_DIR/obsidian.json"
mkdir -p "$OBSIDIAN_DIR"
export OBSIDIAN_CONFIG
python3 <<'PY'
import hashlib
import json
import os
import time
from pathlib import Path

target = Path(os.environ["TARGET"]).resolve()
config_path = Path(os.environ["OBSIDIAN_CONFIG"])
if config_path.exists() and config_path.read_text(encoding="utf-8").strip():
    config = json.loads(config_path.read_text(encoding="utf-8"))
else:
    config = {}

vaults = config.setdefault("vaults", {})
for vault in vaults.values():
    if Path(vault.get("path", "")).expanduser().resolve() == target:
        break
else:
    vault_id = hashlib.sha256(str(target).upper().encode("utf-8")).hexdigest()[:16]
    vaults[vault_id] = {
        "name": "SuperGemmi_Workspace",
        "path": str(target),
        "ts": int(time.time() * 1000),
    }

config_path.write_text(json.dumps(config, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
PY

log "Richte Agenten-Mandate ein."
ensure_agent_mandates
compile_soul_bundle

if [[ "$NO_APP_INSTALLS" -eq 1 ]]; then
  log "App-Installationen uebersprungen."
else
  if [[ "$INSTALL_OBSIDIAN" -eq 1 ]]; then
    install_homebrew_cask "obsidian" "/Applications/Obsidian.app" "Obsidian"
  fi
  if [[ "$INSTALL_CODEX_CLI" -eq 1 ]]; then
    install_codex_cli
  fi
  if [[ "$INSTALL_CODEX_APP" -eq 1 ]]; then
    if [[ -z "$CODEX_APP_DMG_URL" ]]; then
      CODEX_APP_DMG_URL="$(default_codex_app_url)"
    fi
    install_dmg_app "$CODEX_APP_DMG_URL" "Codex" "Codex Desktop-App"
  fi
  if [[ "$INSTALL_ANTIGRAVITY" -eq 1 ]]; then
    if [[ -z "$ANTIGRAVITY_DMG_URL" ]]; then
      ANTIGRAVITY_DMG_URL="$(default_antigravity_url)"
    fi
    install_dmg_app "$ANTIGRAVITY_DMG_URL" "Antigravity" "Google Antigravity Haupt-App"
  fi
  if [[ "$INSTALL_OBSIDIAN$INSTALL_CODEX_CLI$INSTALL_CODEX_APP$INSTALL_ANTIGRAVITY" == "0000" ]]; then
    log "Keine App-Installationsoption gewaehlt."
  fi
fi

log "Installation abgeschlossen."
