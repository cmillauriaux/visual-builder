extends Node

## Bus d'événements global (Autoload).
## Centralise les signaux transverses pour découpler les contrôleurs et les vues.

# --- Story Events ---
signal story_loaded(story: RefCounted)
signal story_modified()
signal story_saved(path: String)

# --- Navigation Events ---
## Émis pour demander un changement de vue (ex: de chapitre à scène).
signal navigation_requested(level: String, context_uuid: String)
## Émis quand le mode de l'éditeur change. new_mode est EditorState.Mode
signal editor_mode_changed(new_mode: int, context: Dictionary)
## Émis quand la vue a effectivement changé (optionnel, peut être redondant avec mode_changed).
signal view_changed(new_level: String, context: Dictionary)

# --- Undo/Redo Events ---
signal undo_redo_state_changed(can_undo: bool, can_redo: bool)

# --- Play Events ---
signal play_started(mode: String) # "sequence" or "story"
signal play_stopped()
signal play_dialogue_changed(character: String, text: String, index: int)
signal play_choice_requested(choices: Array) # Array[ChoiceModel]
signal play_finished(reason: String)

# --- UI Events ---
signal notification_requested(message: String)
