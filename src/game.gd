extends Control

## Scène principale du jeu standalone — lecture d'une story sans éditeur.
##
## Mode de fonctionnement :
## - Si `story_path` est défini (via l'inspecteur ou par code), charge directement cette story.
## - Sinon, affiche un sélecteur parmi les stories de `user://stories/`.
##
## Pour l'export : définir `story_path` vers le dossier de la story embarquée
## (ex: "res://story" ou "user://stories/mon_histoire").

const GameUIBuilder = preload("res://src/controllers/game_ui_builder.gd")
const GamePlayControllerScript = preload("res://src/controllers/game_play_controller.gd")
const StorySaver = preload("res://src/persistence/story_saver.gd")

## Chemin vers la story à charger automatiquement.
## Si vide, affiche le sélecteur. Peut pointer vers res:// ou user://.
@export var story_path: String = ""

# Contrôleurs
var _play_ctrl: Node
var _sequence_editor_ctrl: Control
var _story_play_ctrl: Node
var _foreground_transition: Node

# UI — Visual
var _visual_editor: Control

# UI — Play overlay
var _play_overlay: PanelContainer
var _play_character_label: Label
var _play_text_label: RichTextLabel
var _typewriter_timer: Timer
var _choice_overlay: PanelContainer
var _stop_button: Button

# UI — Story selector
var _story_selector: PanelContainer
var _story_list: VBoxContainer

# State
var _current_story = null


func _ready() -> void:
	GameUIBuilder.build(self)

	_play_ctrl = Node.new()
	_play_ctrl.set_script(GamePlayControllerScript)
	_play_ctrl.setup(self)
	add_child(_play_ctrl)

	# Connect signals
	_stop_button.pressed.connect(_play_ctrl.on_stop_pressed)
	_typewriter_timer.timeout.connect(_play_ctrl.on_typewriter_tick)
	_story_play_ctrl.sequence_play_requested.connect(_play_ctrl.on_sequence_play_requested)
	_story_play_ctrl.choice_display_requested.connect(_play_ctrl.on_choice_display_requested)
	_story_play_ctrl.play_finished.connect(_play_ctrl.on_play_finished)
	_sequence_editor_ctrl.play_dialogue_changed.connect(_play_ctrl.on_play_dialogue_changed)
	_sequence_editor_ctrl.play_stopped.connect(_play_ctrl.on_play_stopped)
	_play_ctrl.play_finished_show_selector.connect(_on_play_finished_return)

	if story_path != "":
		_load_and_play(story_path)
	else:
		_show_story_selector()


func _load_and_play(path: String) -> void:
	var story = StorySaver.load_story(path)
	if story == null:
		_show_error("Impossible de charger l'histoire depuis : " + path)
		return
	_current_story = story
	_story_selector.visible = false
	_play_ctrl.start_story(story)


func _on_play_finished_return() -> void:
	if story_path != "":
		# Story embarquée : relancer la même story
		_load_and_play(story_path)
	else:
		_show_story_selector()


func _show_story_selector() -> void:
	_visual_editor.load_sequence(null)
	_story_selector.visible = true
	_stop_button.visible = false
	_refresh_story_list()


func _refresh_story_list() -> void:
	for child in _story_list.get_children():
		child.queue_free()

	var stories_path = "user://stories"
	if not DirAccess.dir_exists_absolute(stories_path):
		DirAccess.make_dir_recursive_absolute(stories_path)
		_add_no_stories_label()
		return

	var dir = DirAccess.open(stories_path)
	if dir == null:
		_add_no_stories_label()
		return

	var found := false
	dir.list_dir_begin()
	var folder = dir.get_next()
	while folder != "":
		if dir.current_is_dir() and folder != "." and folder != "..":
			var story_yaml = stories_path + "/" + folder + "/story.yaml"
			if FileAccess.file_exists(story_yaml):
				found = true
				_add_story_button(folder, stories_path + "/" + folder)
		folder = dir.get_next()
	dir.list_dir_end()

	if not found:
		_add_no_stories_label()


func _add_story_button(story_name: String, story_path_arg: String) -> void:
	var btn = Button.new()
	btn.text = story_name
	btn.pressed.connect(_on_story_selected.bind(story_path_arg))
	_story_list.add_child(btn)


func _add_no_stories_label() -> void:
	var label = Label.new()
	label.text = "Aucune histoire trouvée dans user://stories/"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.modulate.a = 0.5
	_story_list.add_child(label)


func _on_story_selected(path: String) -> void:
	_load_and_play(path)


func _show_error(msg: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.dialog_text = msg
	add_child(dialog)
	dialog.popup_centered()
