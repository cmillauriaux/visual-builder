# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Godot 4.4 project ("visual-builder") using GL Compatibility renderer (supports web/HTML5 export).

## Environnement Godot

Le binaire Godot est installé automatiquement via le hook SessionStart (`.claude/hooks/install-godot.sh`) sur les environnements distants/Linux.

- **Priorité** : La variable d'environnement `GODOT_PATH` est utilisée en priorité si elle est définie.
- **Local (macOS)** : `/Applications/Godot.app/Contents/MacOS/Godot` par défaut.
- **Remote (Linux / Claude Code web)** : `godot` (installé dans `/usr/local/bin/godot`).
- **Windows** : Définir `GODOT_PATH` dans un fichier `.env` ou via `$env:GODOT_PATH = "C:\chemin\vers\godot.exe"`.

Pour déterminer quel binaire utiliser dans les scripts (bash) :

```bash
# Détection automatique (Bash)
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot.app/Contents/MacOS/Godot")}
```

Pour PowerShell (Windows) :

```powershell
# Détection automatique (PowerShell)
$GODOT = if ($env:GODOT_PATH) { $env:GODOT_PATH } else { (Get-Command godot -ErrorAction SilentlyContinue).Source ?? "C:\Path\To\Godot.exe" }
```

## Running the Project

```bash
# Open in Godot editor (local macOS)
/Applications/Godot.app/Contents/MacOS/Godot --editor --path .

# Run the project directly
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot.app/Contents/MacOS/Godot")}
$GODOT --path .
```

## Exécution des tests GUT

GUT est configuré avec `"should_exit": true` dans `.gutconfig.json`, ce qui fait quitter Godot automatiquement après les tests. Le `timeout` sert uniquement de filet de sécurité.

```bash
# Détection du binaire Godot
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot.app/Contents/MacOS/Godot")}

# Lancer tous les tests GUT
timeout 120 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd
```
# Lancer un fichier de test spécifique
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/test_example.gd
```

## Project Structure

- `project.godot` — Main engine configuration
- `specs/` — Test directory (GUT tests + Markdown specifications)
- `.godot/` — Engine cache (gitignored, auto-generated)
- `.claude/hooks/install-godot.sh` — Script d'installation automatique de Godot headless
- `.claude/settings.json` — Configuration des hooks Claude Code (SessionStart)

## Priorities

1. **Specs d'abord** — Chaque fonctionnalité doit être documentée dans `specs/` au format Markdown **avant** son implémentation. Aucun code ne doit être écrit sans spec correspondante.
2. **Couverture de tests à 100%** — Tous les tests (unitaires et d'intégration) utilisent le framework [GUT](https://github.com/bitwes/Gut) pour Godot. L'objectif est une couverture de 100%. Les tests se trouvent dans `specs/`.

## Validation obligatoire

**Avant d'annoncer à l'utilisateur que le travail est terminé**, tu DOIS lancer la commande `/check-global-acceptance` et vérifier que toutes les vérifications passent. Ne jamais déclarer une tâche terminée sans avoir exécuté cette validation.

## Key Decisions

- **Renderer**: GL Compatibility (OpenGL-based, required for HTML5/web export and older hardware)
- **Godot version**: 4.4 (config_version=5)
- **Line endings**: LF enforced via `.gitattributes`
