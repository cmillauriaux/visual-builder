# 020 — PlayContext Decoupling

## Contexte

`play_controller.gd` accédait 96 fois à `_main._*`, touchant 20+ propriétés de `main.gd`. Ce couplage fort rendait le code difficile à lire et empêchait les tests unitaires.

## Solution

`PlayContext` (RefCounted) encapsule toutes les références nécessaires avec des noms explicites :
- Contrôleurs : `sequence_editor_ctrl`, `story_play_ctrl`, `editor_main`, `foreground_transition`
- Visual : `visual_editor`
- UI play : `play_button`, `stop_button`, `play_overlay`, `play_character_label`, `play_text_label`, `typewriter_timer`, `choice_overlay`, `top_play_button`, `top_stop_button`
- Layout : `vbox`, `left_panel`, `sequence_editor_panel`, `chapter/scene/sequence_graph_view`
- Callbacks : `update_preview_for_dialogue`, `highlight_dialogue_in_list`, `load_sequence_editors`, `update_view`, `refresh_current_view`
- `main_node` (pour `add_child`)

`play_controller.gd` utilise `_ctx` au lieu de `_main`. La construction du contexte reste dans `setup()`.

## Fichiers

- `src/controllers/play_context.gd` (nouveau)
- `src/controllers/play_controller.gd` (modifié)
