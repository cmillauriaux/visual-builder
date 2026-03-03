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
const GameSettings = preload("res://src/ui/menu/game_settings.gd")
const StoryI18nService = preload("res://src/services/story_i18n_service.gd")

## Chemin vers la story à charger automatiquement.
## Si vide, affiche le sélecteur. Peut pointer vers res:// ou user://.
@export var story_path: String = ""

# Contrôleurs
var _play_ctrl: Node
var _sequence_editor_ctrl: Control
var _story_play_ctrl: Node
var _foreground_transition: Node
var _sequence_fx_player: Node

# UI — Visual
var _visual_editor: Control

# UI — Play overlay
var _play_overlay: PanelContainer
var _play_character_label: Label
var _play_text_label: RichTextLabel
var _typewriter_timer: Timer
var _choice_overlay: PanelContainer
var _play_title_overlay: CenterContainer
var _play_title_label: Label
var _play_subtitle_label: Label

# UI — Menu button & Pause menu
var _menu_button: Button
var _pause_menu: Control

# UI — Story selector
var _story_selector: PanelContainer
var _story_selector_title: Label
var _story_list: VBoxContainer

# UI — Menu principal
var _main_menu: Control

# State
var _current_story = null
var _current_story_path: String = ""
var _settings: RefCounted
var _i18n_dict: Dictionary = {}


func _ready() -> void:
	# Charger les réglages
	_settings = GameSettings.new()
	_settings.load_settings()
	_settings.apply_settings()

	GameUIBuilder.build(self)

	_play_ctrl = Node.new()
	_play_ctrl.set_script(GamePlayControllerScript)
	_play_ctrl.setup(self)
	add_child(_play_ctrl)

	# Connecter les signaux du play
	_menu_button.pressed.connect(_on_menu_button_pressed)
	_typewriter_timer.timeout.connect(_play_ctrl.on_typewriter_tick)
	_story_play_ctrl.sequence_play_requested.connect(_play_ctrl.on_sequence_play_requested)
	_story_play_ctrl.choice_display_requested.connect(_play_ctrl.on_choice_display_requested)
	_story_play_ctrl.play_finished.connect(_play_ctrl.on_play_finished)
	_sequence_editor_ctrl.play_dialogue_changed.connect(_play_ctrl.on_play_dialogue_changed)
	_sequence_editor_ctrl.play_stopped.connect(_play_ctrl.on_play_stopped)
	_play_ctrl.play_finished_show_menu.connect(_on_play_finished_return)

	# Connecter les signaux du menu principal
	_main_menu.new_game_pressed.connect(_on_new_game)
	_main_menu.load_game_pressed.connect(_on_load_game)
	_main_menu.quit_pressed.connect(_on_quit)
	_main_menu.options_applied.connect(_on_options_applied)
	_main_menu.set_settings(_settings)

	# Connecter les signaux du menu pause
	_pause_menu.resume_pressed.connect(_on_pause_resume)
	_pause_menu.save_pressed.connect(_on_pause_save)
	_pause_menu.load_pressed.connect(_on_pause_load)
	_pause_menu.new_game_pressed.connect(_on_pause_new_game)
	_pause_menu.quit_pressed.connect(_on_pause_quit)

	if story_path != "":
		_load_story_and_show_menu(story_path)
	else:
		_show_story_selector()


func _load_story_and_show_menu(path: String) -> void:
	var story = StorySaver.load_story(path)
	if story == null:
		_show_error("Impossible de charger l'histoire depuis : " + path)
		return
	_current_story = story
	_current_story_path = path
	_reload_i18n()
	_show_main_menu(story)


func _reload_i18n() -> void:
	if _current_story_path != "":
		_i18n_dict = StoryI18nService.load_i18n(_current_story_path, _settings.language)
	else:
		_i18n_dict = {}
	_apply_ui_lang()


func _apply_ui_lang() -> void:
	_menu_button.text = StoryI18nService.get_ui_string("☰ Menu", _i18n_dict)
	if _story_selector_title:
		_story_selector_title.text = StoryI18nService.get_ui_string("Sélectionnez une histoire", _i18n_dict)
	_main_menu.apply_ui_translations(_i18n_dict)
	_pause_menu.apply_ui_translations(_i18n_dict)
	_play_ctrl.set_i18n(_i18n_dict)


func _on_options_applied() -> void:
	_reload_i18n()


func _show_main_menu(story) -> void:
	_story_selector.visible = false
	_menu_button.visible = false
	_main_menu.setup(story, _current_story_path)
	_main_menu.show_menu()


func _on_new_game() -> void:
	_main_menu.hide_menu()
	_play_ctrl.start_story(_current_story)


func _on_load_game() -> void:
	_show_info(StoryI18nService.get_ui_string("Fonctionnalité à venir", _i18n_dict))


func _on_quit() -> void:
	get_tree().quit()


func _on_play_finished_return() -> void:
	if _current_story:
		_show_main_menu(_current_story)
	else:
		_show_story_selector()


# --- Menu pause ---

func _on_menu_button_pressed() -> void:
	get_tree().paused = true
	_pause_menu.show_menu()


func _on_pause_resume() -> void:
	_pause_menu.hide_menu()
	get_tree().paused = false


func _on_pause_save() -> void:
	_show_info(StoryI18nService.get_ui_string("Fonctionnalité à venir", _i18n_dict))


func _on_pause_load() -> void:
	_show_info(StoryI18nService.get_ui_string("Fonctionnalité à venir", _i18n_dict))


func _on_pause_new_game() -> void:
	_pause_menu.hide_menu()
	get_tree().paused = false
	_play_ctrl.stop_and_restart(_current_story)


func _on_pause_quit() -> void:
	_pause_menu.hide_menu()
	get_tree().paused = false
	_play_ctrl.stop_current()
	if _current_story:
		_show_main_menu(_current_story)
	else:
		_show_story_selector()


# --- Story selector ---

func _show_story_selector() -> void:
	_visual_editor.load_sequence(null)
	_main_menu.hide_menu()
	_story_selector.visible = true
	_menu_button.visible = false
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
	label.text = StoryI18nService.get_ui_string("Aucune histoire trouvée", _i18n_dict)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.modulate.a = 0.5
	_story_list.add_child(label)


func _on_story_selected(path: String) -> void:
	_load_story_and_show_menu(path)


func _show_error(msg: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.dialog_text = msg
	add_child(dialog)
	dialog.popup_centered()


func _show_info(msg: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.dialog_text = msg
	dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(dialog)
	dialog.popup_centered()
