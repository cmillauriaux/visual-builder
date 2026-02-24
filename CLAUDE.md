# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Godot 4.4 project ("visual-builder") using GL Compatibility renderer (supports web/HTML5 export).

## Running the Project

```bash
# Open in Godot editor
/Applications/Godot.app/Contents/MacOS/Godot --editor --path /Users/cedric/projects/perso/visual-builder

# Run the project directly
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/cedric/projects/perso/visual-builder
```

## Exécution des tests GUT

**IMPORTANT** : Le mode headless de Godot ne rend jamais la main après l'exécution des tests. Il faut **systématiquement** utiliser `gtimeout` pour encapsuler toute commande Godot headless.

```bash
# Lancer tous les tests GUT (timeout de 120s)
gtimeout 120 /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/cedric/projects/perso/visual-builder -s addons/gut/gut_cmdln.gd

# Lancer un fichier de test spécifique
gtimeout 120 /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/cedric/projects/perso/visual-builder -s addons/gut/gut_cmdln.gd -gtest=res://specs/test_example.gd
```

## Project Structure

- `project.godot` — Main engine configuration
- `specs/` — Test directory (empty, framework TBD)
- `.godot/` — Engine cache (gitignored, auto-generated)

## Priorities

1. **Specs d'abord** — Chaque fonctionnalité doit être documentée dans `specs/` au format Markdown **avant** son implémentation. Aucun code ne doit être écrit sans spec correspondante.
2. **Couverture de tests à 100%** — Tous les tests (unitaires et d'intégration) utilisent le framework [GUT](https://github.com/bitwes/Gut) pour Godot. L'objectif est une couverture de 100%. Les tests se trouvent dans `specs/`.

## Validation obligatoire

**Avant d'annoncer à l'utilisateur que le travail est terminé**, tu DOIS lancer la commande `/check-global-acceptance` et vérifier que toutes les vérifications passent. Ne jamais déclarer une tâche terminée sans avoir exécuté cette validation.

## Key Decisions

- **Renderer**: GL Compatibility (OpenGL-based, required for HTML5/web export and older hardware)
- **Godot version**: 4.4 (config_version=5)
- **Line endings**: LF enforced via `.gitattributes`
