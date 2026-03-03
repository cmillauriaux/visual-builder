extends Node

## Objet d'injection de dépendances pour PlayController.
## Permet de découpler le contrôleur de la structure UI de Main.

class_name PlayContext

# Contrôleurs
var sequence_editor_ctrl: Control
var story_play_ctrl: Node
var editor_main: Control

# Visual
var foreground_transition: Node
var visual_editor: Control

# Play UI
var play_button: Button
var stop_button: Button
var play_overlay: Control
var play_character_label: Label
var play_text_label: Control
var typewriter_timer: Timer
var choice_overlay: Control
var play_title_overlay: Control
var play_title_label: Label
var play_subtitle_label: Label

# Top Bar
var top_play_button: Button
var top_stop_button: Button

# Layout
var vbox: VBoxContainer
var left_panel: Control
var sequence_editor_panel: Control

# Graph Views
var chapter_graph_view: GraphEdit
var scene_graph_view: GraphEdit
var sequence_graph_view: GraphEdit

# Main
var main_node: Control

# Callables (Actions)
var update_preview_for_dialogue: Callable
var highlight_dialogue_in_list: Callable
var load_sequence_editors: Callable
var update_view: Callable
var refresh_current_view: Callable
