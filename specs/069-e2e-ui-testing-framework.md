# 069 — Framework de tests E2E avec interactions UI réelles

## Contexte

Les tests e2e existants appellent les méthodes des contrôleurs directement (ex: `_main._nav_ctrl.on_new_story_pressed()`), ce qui bypass la couche UI. Ce framework ajoute des tests qui simulent les **vraies interactions utilisateur** via le pipeline d'input complet de Godot.

## Architecture

### E2eActionHelper (`specs/e2e/e2e_action_helper.gd`)

Classe `RefCounted` qui encapsule `GutInputSender(Input)` avec `auto_flush_input = true`.

**Méthodes principales :**

| Méthode | Mécanisme | Usage |
|---|---|---|
| `click_button(button)` | Position réelle via `get_global_rect().get_center()` → `Input.parse_input_event()` | Boutons |
| `double_click_graph_node(view, uuid)` | Position du nœud → `_gui_input(InputEventMouseButton{double_click})` | Navigation graphe |
| `select_menu_item(menu, id)` | `popup.emit_signal("id_pressed", id)` (fallback PopupMenu) | Menus |
| `click_choice(panel, index)` | Position réelle du bouton dans ChoiceVBox | Choix en jeu |
| `type_in_line_edit(edit, text)` | Clic focus + set text + `text_changed` | Saisie texte |
| `press_key(keycode, ctrl, shift)` | `Input.parse_input_event(InputEventKey)` | Raccourcis clavier |
| `click_to_advance()` | Clic au centre du viewport | Avancer dialogue |
| `take_screenshot(path)` | `viewport.get_texture().get_image().save_png()` | Debug |

### Classes de base

- `e2e_editor_base.gd` — Instancie `main.gd`, fixe le viewport à 1920×1080, crée le helper.
- `e2e_game_base.gd` — Instancie `game.gd`, idem.

### Exécution

Les tests e2e tournent en mode **non-headless** (avec fenêtre visible) pour que les contrôles aient un layout réel.

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}

# Tests e2e (non-headless)
timeout 120 $GODOT --path . -s addons/gut/gut_cmdln.gd -gdir=res://specs/e2e/

# Tests unitaires (headless, inchangé)
timeout 120 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd

# CI Linux (framebuffer virtuel)
xvfb-run -a $GODOT --path . -s addons/gut/gut_cmdln.gd -gdir=res://specs/e2e/
```

## Tests éditeur (`test_e2e_editor_ui_clicks.gd`)

- [x] `test_create_story_via_button_click` — Clic "Nouvelle histoire", vérifier vue chapitres
- [x] `test_full_navigation_via_double_clicks` — 4 niveaux de navigation + retour
- [x] `test_create_chapters_via_button` — Créer chapitres via bouton Créer
- [x] `test_add_dialogue_via_button_click` — Navigation + ajout dialogue
- [x] `test_undo_redo_via_button_clicks` — Annuler / Rétablir
- [x] `test_histoire_menu_new_story` — Menu Histoire → Nouvelle histoire

## Tests jeu (`test_e2e_game_ui_clicks.gd`)

- [x] `test_new_game_from_main_menu` — Clic Nouvelle partie, vérifier play
- [x] `test_choice_selection_via_button_click` — Sélection de choix avec clic
- [x] `test_pause_menu_resume_via_button_click` — Menu pause → Reprendre
- [x] `test_full_playthrough_to_be_continued_via_clicks` — Parcours complet

## Stratégie PopupMenu

Les `PopupMenu` sont des fenêtres séparées dans Godot dont le positionnement dynamique rend le clic par coordonnées peu fiable. On utilise `emit_signal("id_pressed", id)` comme fallback pragmatique. Le reste (boutons, graph nodes, choice buttons) utilise de vrais clics aux coordonnées.
