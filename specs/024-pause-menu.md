# 024 — Menu Pause In-Game

## Contexte

Le jeu standalone (`game.tscn`) dispose d'un bouton "Stop" en haut à droite qui ramène
directement au sélecteur de stories. Ce comportement est trop abrupt : l'utilisateur a besoin
d'un **menu pause** accessible pendant la partie, qui met le jeu en pause et propose
des actions classiques : reprendre, sauvegarder, charger, nouvelle partie, quitter.

## Objectif

Remplacer le bouton "Stop" par un bouton "☰ Menu" en haut à droite qui ouvre un **menu pause**
overlay. Ce menu met le jeu en pause (`get_tree().paused = true`) et propose :

1. **Reprendre** — Retourne au jeu (dépause)
2. **Sauvegarder** — Sauvegarde la partie (placeholder pour cette spec)
3. **Charger** — Charge une partie (placeholder pour cette spec)
4. **Nouvelle partie** — Relance une nouvelle partie depuis le début
5. **Quitter** — Retourne au menu principal

## Architecture

### Fichiers créés

| Fichier | Rôle |
|---------|------|
| `src/ui/menu/pause_menu.gd` | Composant UI du menu pause |
| `specs/ui/menu/test_pause_menu.gd` | Tests GUT du menu pause |

### Fichiers modifiés

| Fichier | Modification |
|---------|-------------|
| `src/controllers/game_ui_builder.gd` | Remplace `_build_stop_button` par `_build_menu_button` + `_build_pause_menu` |
| `src/game.gd` | Remplace `_stop_button` par `_menu_button` + `_pause_menu`, gère la pause |
| `src/controllers/game_play_controller.gd` | Remplace `_stop_button` par `_menu_button`, supprime `on_stop_pressed()` |
| `specs/game/test_game_play_controller.gd` | Adapte les tests (`_stop_button` → `_menu_button`) |
| `specs/game/test_game_ui_builder.gd` | Adapte les tests pour menu button + pause menu |
| `specs/game/test_game_scene.gd` | Adapte les tests pour les nouvelles connexions |

### Arborescence UI

```
Game (Control, plein écran)
├── VisualEditor
├── PlayOverlay
├── ChoiceOverlay
├── MenuButton (Button, "☰ Menu", haut-droite, process_mode=ALWAYS)
├── PauseMenu (Control, plein écran, caché, process_mode=ALWAYS)
│   ├── Overlay (ColorRect, Color(0, 0, 0, 0.6))
│   ├── CenterContainer
│   │   └── PanelContainer (custom_minimum_size=300x0)
│   │       └── VBoxContainer
│   │           ├── Label "Pause" (font_size=32, centré)
│   │           ├── Spacer (40px)
│   │           ├── Button "Reprendre" (300x50)
│   │           ├── Button "Sauvegarder" (300x50)
│   │           ├── Button "Charger" (300x50)
│   │           ├── Button "Nouvelle partie" (300x50)
│   │           └── Button "Quitter" (300x50)
├── TypewriterTimer
├── ForegroundTransition
├── StoryPlayController
├── StorySelector
└── MainMenu
```

### PauseMenu (`src/ui/menu/pause_menu.gd`)

**Extends** : `Control`

**Propriétés** :
- `process_mode = PROCESS_MODE_ALWAYS` — Reste actif pendant la pause

**Signaux** :
- `resume_pressed` — L'utilisateur veut reprendre la partie
- `save_pressed` — L'utilisateur veut sauvegarder
- `load_pressed` — L'utilisateur veut charger
- `new_game_pressed` — L'utilisateur veut relancer une nouvelle partie
- `quit_pressed` — L'utilisateur veut quitter vers le menu principal

**Méthodes** :
- `build_ui()` — Construit l'arborescence UI dynamiquement
- `show_menu()` — Affiche le menu pause
- `hide_menu()` — Masque le menu pause

**Comportement des boutons** :

| Bouton | Signal émis | Action dans game.gd |
|--------|------------|---------------------|
| Reprendre | `resume_pressed` | `hide_menu()` + `get_tree().paused = false` |
| Sauvegarder | `save_pressed` | Affiche "Fonctionnalité à venir" |
| Charger | `load_pressed` | Affiche "Fonctionnalité à venir" |
| Nouvelle partie | `new_game_pressed` | `hide_menu()` + `get_tree().paused = false` + relance `start_story` |
| Quitter | `quit_pressed` | `hide_menu()` + `get_tree().paused = false` + retour menu principal |

### MenuButton (dans game_ui_builder.gd)

- Bouton "☰ Menu" positionné en haut à droite
- `process_mode = PROCESS_MODE_ALWAYS` — Cliquable même pendant la pause
- Visible uniquement pendant une partie (comme l'ancien bouton Stop)

### Gestion de la pause

- Ouverture du menu : `get_tree().paused = true` → gèle le typewriter, les transitions, le StoryPlayController
- Fermeture (reprendre/nouvelle partie/quitter) : `get_tree().paused = false`
- Le PauseMenu et le MenuButton sont en `PROCESS_MODE_ALWAYS` pour rester interactifs

### Flux dans game.gd

```
# Ouverture du menu pause
func _on_menu_button_pressed():
    get_tree().paused = true
    _pause_menu.show_menu()

# Reprendre
func _on_pause_resume():
    _pause_menu.hide_menu()
    get_tree().paused = false

# Sauvegarder / Charger
func _on_pause_save() / _on_pause_load():
    _show_info("Fonctionnalité à venir")

# Nouvelle partie
func _on_pause_new_game():
    _pause_menu.hide_menu()
    get_tree().paused = false
    _play_ctrl.stop_and_restart(_current_story)

# Quitter → retour menu principal
func _on_pause_quit():
    _pause_menu.hide_menu()
    get_tree().paused = false
    _play_ctrl.stop_current()
    _show_main_menu(_current_story)
```

## Critères d'acceptation

### Menu pause
- [x] Un bouton "☰ Menu" est affiché en haut à droite pendant une partie
- [x] Le bouton n'est pas visible sur le menu principal ou le sélecteur de stories
- [x] Cliquer sur le bouton met le jeu en pause et affiche le menu pause
- [x] Le menu pause a un overlay semi-transparent sombre
- [x] Le menu pause affiche "Pause" en titre

### Boutons du menu pause
- [x] "Reprendre" ferme le menu et reprend le jeu
- [x] "Sauvegarder" affiche un message placeholder
- [x] "Charger" affiche un message placeholder
- [x] "Nouvelle partie" relance une nouvelle partie depuis le début
- [x] "Quitter" retourne au menu principal

### Pause technique
- [x] Le jeu est en pause pendant que le menu est affiché (typewriter gelé, pas de transitions)
- [x] Le menu pause et le bouton menu restent interactifs pendant la pause (process_mode=ALWAYS)
- [x] La pause est correctement levée dans tous les cas (reprendre, nouvelle partie, quitter)

### Intégration
- [x] L'ancien bouton "Stop" est supprimé
- [x] Aucune régression sur le mode play existant
- [x] Les tests GUT passent
