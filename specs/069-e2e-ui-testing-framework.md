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

## Tests éditeur — Navigation de base (`test_e2e_editor_ui_clicks.gd`)

- [x] `test_create_story_via_button_click` — Clic "Nouvelle histoire", vérifier vue chapitres
- [x] `test_full_navigation_via_double_clicks` — 4 niveaux de navigation + retour
- [x] `test_create_chapters_via_button` — Créer chapitres via bouton Créer
- [x] `test_add_dialogue_via_button_click` — Navigation + ajout dialogue
- [x] `test_undo_redo_via_button_clicks` — Annuler / Rétablir
- [x] `test_histoire_menu_new_story` — Menu Histoire → Nouvelle histoire

## Tests éditeur — Foreground visual editor (`test_e2e_foreground_visual_editor.gd`)

- [x] `test_select_foreground_on_canvas` — Clic sur foreground → sélection
- [x] `test_deselect_foreground_click_empty` — Clic zone vide → désélection
- [x] `test_foreground_z_order_child_ordering` — Z-order différents → ordre enfants correct
- [x] `test_delete_foreground_via_key` — Sélection + KEY_DELETE → suppression
- [x] `test_foreground_context_menu_delete` — Clic droit + menu → suppression
- [x] `test_foreground_copy_paste_params` — Copier params FG1 → coller sur FG2
- [x] `test_foreground_copy_paste_foreground` — Copier FG → coller → nouveau FG ajouté
- [x] `test_foreground_hide_via_context_menu` — Masquer FG → `_hidden_fg_uuids` mis à jour
- [x] `test_multi_select_with_shift` — Sélectionner 2 FGs avec shift

## Tests éditeur — Foreground properties (`test_e2e_foreground_properties.gd`)

- [x] `test_set_transition_type_fade` — Type de transition → "fade"
- [x] `test_set_transition_duration` — Durée de transition → 1.5
- [x] `test_set_z_order` — Z-order → 5, réordonnement enfants
- [x] `test_set_flip_horizontal` — Flip horizontal
- [x] `test_set_flip_both` — Flip horizontal + vertical
- [x] `test_panel_hidden_on_deselect` — Panel masqué après désélection

## Tests éditeur — Édition de dialogues (`test_e2e_dialogue_editing.gd`)

- [x] `test_add_dialogue` — Ajout dialogue → count +1
- [x] `test_add_multiple_dialogues` — 3 ajouts → count correct
- [x] `test_select_dialogue_from_list` — Sélection item → index mis à jour
- [x] `test_delete_dialogue` — Suppression → count -1
- [x] `test_selection_updates_visual_editor` — Sélection dialogue → visual editor mis à jour
- [x] `test_add_preserves_existing` — Ajout → textes existants préservés
- [x] `test_list_rebuild_after_deletion` — Suppression au milieu → liste reconstruite
- [x] `test_first_dialogue_auto_selected` — Entrée en sequence_edit → dialogue 0 sélectionné

## Tests éditeur — Ending editor (`test_e2e_ending_editor.gd`)

- [x] `test_ending_mode_none_by_default` — Mode none par défaut
- [x] `test_set_mode_redirect` — Mode redirect → type auto_redirect
- [x] `test_set_mode_choices` — Mode choices → type choices
- [x] `test_add_choice` — Mode choices + ajout → 1 choix
- [x] `test_add_choices_up_to_limit` — 8 choix max → bouton désactivé
- [x] `test_redirect_type_game_over` — Redirect game_over
- [x] `test_redirect_type_to_be_continued` — Redirect to_be_continued
- [x] `test_switch_modes_clears_previous` — Changement mode → nettoyage

## Tests éditeur — Paramètres de séquence (`test_e2e_sequence_params.gd`)

- [x] `test_set_title` — Titre de séquence
- [x] `test_set_subtitle` — Sous-titre de séquence
- [x] `test_set_background_color` — Couleur de fond
- [x] `test_set_transition_in_fade` — Transition in fade
- [x] `test_set_transition_in_pixelate` — Transition in pixelate
- [x] `test_set_transition_out` — Transition out
- [x] `test_set_transition_durations` — Durées de transition

## Tests éditeur — Variable panel (`test_e2e_variable_panel.gd`)

- [x] `test_open_variable_panel` — Ouverture du panel
- [x] `test_add_variable` — Ajout variable
- [x] `test_edit_variable_name` — Renommage variable
- [x] `test_edit_variable_value` — Modification valeur
- [x] `test_delete_variable` — Suppression variable
- [x] `test_show_on_main_toggle` — Toggle show_on_main

## Tests éditeur — Renommage (`test_e2e_rename_operations.gd`)

- [x] `test_rename_chapter_via_menu` — Renommage chapitre
- [x] `test_rename_scene_via_menu` — Renommage scène
- [x] `test_rename_sequence_via_menu` — Renommage séquence
- [x] `test_rename_story_via_breadcrumb` — Renommage story via breadcrumb
- [x] `test_rename_with_subtitle` — Renommage avec sous-titre
- [x] `test_delete_chapter_via_menu` — Suppression chapitre via menu

## Tests éditeur — Opérations graphe (`test_e2e_graph_operations.gd`)

- [x] `test_set_transition_in_via_graph` — Transition in via nœud graphe
- [x] `test_set_transition_out_via_graph` — Transition out via nœud graphe
- [x] `test_copy_paste_foregrounds_between_sequences` — Copier/coller FGs entre séquences
- [x] `test_toggle_entry_point` — Toggle entry point
- [x] `test_create_condition_node` — Création nœud condition

## Tests jeu — Navigation de base (`test_e2e_game_ui_clicks.gd`)

- [x] `test_new_game_from_main_menu` — Clic Nouvelle partie, vérifier play
- [x] `test_choice_selection_via_button_click` — Sélection de choix avec clic
- [x] `test_pause_menu_resume_via_button_click` — Menu pause → Reprendre
- [x] `test_full_playthrough_to_be_continued_via_clicks` — Parcours complet

## Tests jeu — Save/Load (`test_e2e_game_save_load.gd`)

- [x] `test_pause_save_shows_menu` — Pause + save → menu visible, mode SAVE
- [x] `test_pause_load_shows_menu` — Pause + load → mode LOAD
- [x] `test_save_load_menu_close` — Ouvrir + fermer → masqué
- [x] `test_quicksave_button` — Bouton quicksave visible et fonctionnel
- [x] `test_save_menu_has_slots` — Grille de slots présente
- [x] `test_load_menu_tabs` — 3 onglets en mode load
- [x] `test_save_slot_signal` — Signal save_slot_pressed émis

## Tests jeu — Écrans de fin (`test_e2e_game_endings.gd`)

- [x] `test_game_over_screen_displayed` — Écran game over visible
- [x] `test_game_over_back_to_menu` — Retour au menu depuis game over
- [x] `test_to_be_continued_screen` — Écran to_be_continued visible
- [x] `test_to_be_continued_back_to_menu` — Retour au menu depuis to_be_continued
- [x] `test_ending_screen_title` — Écrans de fin ont les contrôles nécessaires

## Tests jeu — Historique & Skip (`test_e2e_game_history_skip.gd`)

- [x] `test_history_records_dialogues` — Avancer dialogues → historique enregistré
- [x] `test_history_close` — Ouvrir + fermer historique
- [x] `test_history_toggle_via_button` — Toggle historique via bouton
- [x] `test_skip_advances_to_end` — Skip → séquence terminée
- [x] `test_auto_play_button_toggle` — Toggle auto-play on/off

## Factories (`e2e_story_builder.gd`)

| Factory | Contenu |
|---|---|
| `make_minimal_story()` | 1 ch, 1 sc, 1 seq, 1 dialogue |
| `make_branching_story()` | Chemin A → to_be_continued, chemin B → game_over, variable "score" |
| `make_story_with_foregrounds()` | 1 dialogue avec 2 foregrounds (z_order 0 et 5) |
| `make_story_with_two_sequences()` | 2 séquences + variable "score", ending redirect |
| `make_story_with_multiple_sequences()` | 3 séquences, seq1 avec 2 foregrounds |
| `make_story_with_multiple_dialogues()` | 3 dialogues (Alice/Bob/Charlie) |
| `make_multi_dialogue_story()` | 4 dialogues + ending to_be_continued |

## Stratégie PopupMenu

Les `PopupMenu` sont des fenêtres séparées dans Godot dont le positionnement dynamique rend le clic par coordonnées peu fiable. On utilise `emit_signal("id_pressed", id)` comme fallback pragmatique. Le reste (boutons, graph nodes, choice buttons) utilise de vrais clics aux coordonnées.
