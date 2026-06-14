# Super-Gemmi macOS Installer Scaffold

Dieses Verzeichnis ist das erste macOS-Testgeruest fuer den Super-Gemmi-Installer.

Ziel der ersten Stufe:

- Workspace-Vorlage in einen Zielordner kopieren
- Platzhalter `{WORKSPACE}`, `{USER}` und `{AGENT}` ersetzen
- `AGENTS.md` und `Gemini.md` mit Hydrierungsmandaten erzeugen
- initiales `soul_bundle.md` kompilieren
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

`--install-antigravity` installiert/prueft die Google Antigravity Haupt-App unter
`/Applications/Antigravity.app`. Die separate Antigravity IDE ist nicht Teil dieses
Installers.

Beispiele:

```bash
./install.sh \
  --target "$HOME/SuperGemmi_Workspace" \
  --user "Stefan" \
  --agent "Gemmi" \
  --install-obsidian \
  --install-codex \
  --install-antigravity
```

DMG-basierte Desktop-Apps nutzen standardmaessig die offiziellen Download-URLs
fuer die aktuelle Architektur. Bei Bedarf koennen URLs ueberschrieben werden:

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
- `--install-codex`: installiert Codex CLI und Codex Desktop-App.
- `--install-codex-cli`: installiert Codex CLI via npm in `~/.local`.
- `--install-codex-app`: installiert die Codex Desktop-App aus der offiziellen DMG.
- `--codex-app-dmg-url URL`: ueberschreibt die Codex-App-DMG-URL.
- `--install-antigravity`: installiert Google Antigravity Haupt-App aus der offiziellen DMG.
- `--antigravity-dmg-url URL`: ueberschreibt die Antigravity-DMG-URL.

## Template-Auswahl

Ohne `--template-root` nutzt der Installer:

1. das uebergeordnete Super-Gemmi-Projekt, wenn dort `AGENTS.md` existiert
2. sonst das lokale `template/`-Verzeichnis

Fuer ein oeffentliches Test-Repo ist `template/` bewusst minimal gehalten.

Hinweis fuer Windows- und Standard-macOS-Arbeitsplaetze: `Agents.md` und
`AGENTS.md` unterscheiden sich nur in der Gross-/Kleinschreibung. Auf
case-insensitive Dateisystemen koennen diese Dateien nicht zuverlaessig
nebeneinander existieren. Deshalb ist `AGENTS.md` der kanonische Codex-Startup
Entry-Point; `Gemini.md` verweist auf diese Start-Prozedur. Der
GitHub-Action-Test prueft die Mandate direkt auf macOS und legt zusaetzlich
`manual-test-result/installed-workspace-files.txt` sowie
`manual-test-result/mandate-checksums.txt` im Artefakt ab.

## GitHub Actions

Das Verzeichnis enthaelt eine eigene Workflow-Datei unter `.github/workflows/manual-macos-test.yml`.
Wenn `Installer_Mac` als eigenes Repo veroeffentlicht wird, laeuft der manuelle Test direkt auf macOS.
