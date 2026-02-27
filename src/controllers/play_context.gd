extends RefCounted

## Contexte injecté dans PlayController pour découpler l'accès à main.gd.

# Contrôleurs
var sequence_editor_ctrl: Control
var story_play_ctrl: Node
var editor_main: Control
var foreground_transition: Node

# Visual
var visual_editor: Control

# UI play
var play_button: Button
var stop_button: Button
var play_overlay: PanelContainer
var play_character_label: Label
var play_text_label: RichTextLabel
var typewriter_timer: Timer
var choice_overlay: PanelContainer
var top_play_button: Button
var top_stop_button: Button

# Layout
var vbox: VBoxContainer
var left_panel: VBoxContainer
var sequence_editor_panel: VBoxContainer
var chapter_graph_view: GraphEdit
var scene_graph_view: GraphEdit
var sequence_graph_view: GraphEdit

# Callbacks
var update_preview_for_dialogue: Callable
var highlight_dialogue_in_list: Callable
var load_sequence_editors: Callable
var update_view: Callable
var refresh_current_view: Callable

# Pour add_child (dialogs, fullscreen layer)
var main_node: Control
