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

## Template-Auswahl

Ohne `--template-root` nutzt der Installer:

1. das uebergeordnete Super-Gemmi-Projekt, wenn dort `Agents.md` existiert
2. sonst das lokale `template/`-Verzeichnis

Fuer ein oeffentliches Test-Repo ist `template/` bewusst minimal gehalten.

## GitHub Actions

Das Verzeichnis enthaelt eine eigene Workflow-Datei unter `.github/workflows/macos-smoke.yml`.
Wenn `Installer_Mac` als eigenes Repo veroeffentlicht wird, laeuft der Smoke-Test direkt auf macOS.

