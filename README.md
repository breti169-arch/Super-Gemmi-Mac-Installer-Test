# Super-Gemmi macOS Installer Scaffold

Dieses Verzeichnis ist das erste macOS-Testgeruest fuer den Super-Gemmi-Installer.

Ziel der ersten Stufe:

- Workspace-Vorlage in einen Zielordner kopieren
- Platzhalter `{WORKSPACE}`, `{USER}` und `{AGENT}` ersetzen
- Wiki- und Memory-Basisstruktur pruefen
- Obsidian-Vault-Konfiguration fuer macOS vorbereiten
- alles non-interaktiv in GitHub Actions auf macOS testen

## Lokaler Smoke-Test

```bash
cd Installer_Mac
./test-install.sh
```

## Manuelle Installation

```bash
./install.sh \
  --target "$HOME/SuperGemmi_Workspace" \
  --user "Stefan" \
  --agent "Gemmi" \
  --no-app-installs
```

## Optionale App-Installationen

Der Installer unterscheidet bewusst zwischen Antigravity Haupt-App und Antigravity IDE:

- `--install-antigravity` installiert/prueft `/Applications/Antigravity.app`
- `--install-antigravity-ide` installiert/prueft `/Applications/Antigravity IDE.app`

Beispiele:

```bash
./install.sh \
  --target "$HOME/SuperGemmi_Workspace" \
  --user "Stefan" \
  --agent "Gemmi" \
  --install-obsidian \
  --install-codex-cli
```

DMG-basierte Desktop-Apps benoetigen explizite URLs:

```bash
./install.sh \
  --target "$HOME/SuperGemmi_Workspace" \
  --user "Stefan" \
  --agent "Gemmi" \
  --install-antigravity \
  --antigravity-dmg-url "https://example.invalid/Antigravity.dmg"
```

Verfuegbare Installationsoptionen:

- `--install-obsidian`: installiert Obsidian via Homebrew Cask.
- `--install-codex-cli`: installiert Codex CLI non-interaktiv.
- `--install-codex-app --codex-app-dmg-url URL`: installiert die Codex Desktop-App aus einer DMG.
- `--install-antigravity --antigravity-dmg-url URL`: installiert Google Antigravity Haupt-App aus einer DMG.
- `--install-antigravity-ide --antigravity-ide-dmg-url URL`: installiert Google Antigravity IDE aus einer DMG.

## Template-Auswahl

Ohne `--template-root` nutzt der Installer:

1. das uebergeordnete Super-Gemmi-Projekt, wenn dort `Agents.md` existiert
2. sonst das lokale `template/`-Verzeichnis

Fuer ein oeffentliches Test-Repo ist `template/` bewusst minimal gehalten.

## GitHub Actions

Das Verzeichnis enthaelt eine eigene Workflow-Datei unter `.github/workflows/macos-smoke.yml`.
Wenn `Installer_Mac` als eigenes Repo veroeffentlicht wird, laeuft der Smoke-Test direkt auf macOS.
