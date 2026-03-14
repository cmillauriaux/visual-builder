# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Godot 4.6.1 project ("visual-builder") using GL Compatibility renderer (supports web/HTML5 export).

## Environnement Godot

Le binaire Godot est installé automatiquement via le hook SessionStart (`.claude/hooks/install-godot.sh`) sur les environnements distants/Linux.

- **Priorité** : La variable d'environnement `GODOT_PATH` est utilisée en priorité si elle est définie.
- **Local (macOS)** : `/Applications/Godot-4.6.1.app/Contents/MacOS/Godot` par défaut.
- **Remote (Linux / Claude Code web)** : `godot` (installé dans `/usr/local/bin/godot`).
- **Windows** : Définir `GODOT_PATH` dans un fichier `.env` ou via `$env:GODOT_PATH = "C:\chemin\vers\godot.exe"`.

Pour déterminer quel binaire utiliser dans les scripts (bash) :

```bash
# Détection automatique (Bash)
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
```

Pour PowerShell (Windows) :

```powershell
# Détection automatique (PowerShell)
$GODOT = if ($env:GODOT_PATH) { $env:GODOT_PATH } else { (Get-Command godot -ErrorAction SilentlyContinue).Source ?? "C:\Path\To\Godot.exe" }
```

## Running the Project

```bash
# Open in Godot editor (local macOS)
/Applications/Godot-4.6.1.app/Contents/MacOS/Godot --editor --path .

# Run the project directly
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
$GODOT --path .
```

## Exécution des tests GUT

GUT est configuré avec `"should_exit": true` dans `.gutconfig.json`, ce qui fait quitter Godot automatiquement après les tests. Le `timeout` sert uniquement de filet de sécurité.

Les tests incluent désormais un rapport de **couverture de code** via l'addon `godot-code-coverage` et des hooks dans `specs/`.

### Tests unitaires (headless)

```bash
# Détection du binaire Godot
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}

# Lancer tous les tests GUT (inclut le rapport de couverture à la fin)
timeout 120 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd

# Lancer un fichier de test spécifique (la couverture sera aussi affichée pour ce fichier)
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/models/test_story.gd
```

### Tests e2e (non-headless)

Les tests e2e (`specs/e2e/`) simulent de vraies interactions utilisateur (clics souris aux coordonnées réelles) et nécessitent une **fenêtre visible** pour que les contrôles aient un layout réel. Ils ne doivent **pas** être lancés avec `--headless`.

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}

# Lancer tous les tests e2e (non-headless, fenêtre visible requise)
timeout 120 $GODOT --path . -s addons/gut/gut_cmdln.gd -gdir=res://specs/e2e/

# Lancer un fichier e2e spécifique
timeout 60 $GODOT --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/e2e/test_e2e_editor_ui_clicks.gd

# CI Linux (framebuffer virtuel pour simuler une fenêtre)
xvfb-run -a $GODOT --path . -s addons/gut/gut_cmdln.gd -gdir=res://specs/e2e/
```

### Configuration de la couverture
- **Plugin** : `res://addons/coverage/`
- **Pre-run hook** : `res://specs/pre_run_hook.gd` (instrumente les scripts de `res://src/`)
- **Post-run hook** : `res://specs/post_run_hook.gd` (génère le rapport et vérifie les cibles)
- **Cibles actuelles** : 65% total, 0% par fichier (pour le monitoring).


## Debug visuel : lancer l'app et prendre des captures d'écran

Quand un bug visuel ne peut pas être diagnostiqué par les tests seuls, **tu DOIS lancer l'app, prendre un screenshot et le vérifier toi-même** avant d'annoncer un fix. Ne jamais proposer des corrections à l'aveugle sur des problèmes visuels.

### Prérequis macOS

L'app qui exécute tes commandes (VS Code / Terminal) doit avoir la permission **Enregistrement d'écran** :
Préférences Système → Confidentialité et sécurité → Enregistrement de l'écran → activer l'app.

### Lancer l'app avec navigation automatique

Pour ouvrir automatiquement une story et naviguer vers une séquence spécifique, ajouter temporairement dans `main.gd` à la fin de `_ready()` :

```gdscript
call_deferred("_debug_auto_load")

func _debug_auto_load() -> void:
    _nav_ctrl._on_load_dir_selected("/chemin/vers/story")
    await get_tree().process_frame
    await get_tree().process_frame
    _editor_main.navigate_to_chapter("CHAPTER_UUID")
    _editor_main.navigate_to_scene("SCENE_UUID")
    _editor_main.navigate_to_sequence("SEQUENCE_UUID")
    if _editor_main._current_sequence:
        load_sequence_editors(_editor_main._current_sequence)
    refresh_current_view()
```

Les UUIDs se trouvent dans les fichiers YAML de la story (`chapters/*/chapter.yaml`, `chapters/*/scenes/*.yaml`).

### Lancer et capturer

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}

# Lancer l'app en arrière-plan et capturer la sortie console
$GODOT --path . > /tmp/godot_debug.log 2>&1 &
GODOT_PID=$!

# Attendre le chargement puis prendre un screenshot
sleep 10
screencapture -x /tmp/godot_screenshot.png

# Lire le screenshot (Claude Code peut lire les images)
# → Utiliser l'outil Read sur /tmp/godot_screenshot.png

# Crop d'une zone spécifique (ex: timeline en bas de l'éditeur)
sips -c HAUTEUR LARGEUR --cropOffset Y X /tmp/godot_screenshot.png --out /tmp/crop.png

# Vérifier les logs debug
grep "MON_TAG" /tmp/godot_debug.log

# Tuer l'app quand c'est fini
kill $GODOT_PID
```

### Ajouter des indicateurs visuels temporaires

Pour vérifier qu'un élément est rendu au bon endroit, ajouter un `ColorRect` de couleur vive :

```gdscript
var debug_rect = ColorRect.new()
debug_rect.color = Color(1, 0, 0, 0.5)  # Rouge semi-transparent
debug_rect.position = ma_position
debug_rect.size = ma_taille
debug_rect.mouse_filter = MOUSE_FILTER_IGNORE
parent.add_child(debug_rect)
```

**Important** : toujours retirer le code debug (auto-load, print, ColorRect) après le diagnostic.

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
- **Godot version**: 4.6.1 (config_version=5)
- **Line endings**: LF enforced via `.gitattributes`
