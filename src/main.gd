extends Control

## Scène principale — orchestre tous les composants de l'éditeur de visual novel.
## Délègue la construction UI, le play et la navigation à des contrôleurs dédiés.

const EditorMainScript = preload("res://src/ui/editor_main.gd")
const SequenceEditorScript = preload("res://src/ui/sequence_editor.gd")
const ImagePickerDialogScript = preload("res://src/ui/image_picker_dialog.gd")
const AIGenerateDialogScript = preload("res://src/ui/ai_generate_dialog.gd")
const ComfyUIConfigScript = preload("res://src/services/comfyui_config.gd")
const MainUIBuilder = preload("res://src/controllers/main_ui_builder.gd")
const PlayControllerScript = preload("res://src/controllers/play_controller.gd")
const NavigationControllerScript = preload("res://src/controllers/navigation_controller.gd")

# Contrôleurs
var _editor_main: Control
var _sequence_editor_ctrl: Control
var _play_ctrl: Node
var _nav_ctrl: Node

# UI — Top bar
var _vbox: VBoxContainer
var _top_bar: HBoxContainer
var _back_button: Button
var _breadcrumb: HBoxContainer
var _top_play_button: Button
var _top_stop_button: Button
var _create_button: Button
var _create_condition_button: Button
var _variables_button: Button
var _variable_panel_popup: PopupPanel
var _variable_panel: VBoxContainer
var _save_button: Button
var _load_button: Button
var _new_story_button: Button

# UI — Content area
var _content_area: Control
var _chapter_graph_view: GraphEdit
var _scene_graph_view: GraphEdit
var _sequence_graph_view: GraphEdit

# UI — Sequence editor
var _sequence_editor_panel: VBoxContainer
var _sequence_toolbar: HBoxContainer
var _import_bg_button: Button
var _add_fg_button: Button
var _ai_generate_btn: Button
var _ai_generate_dialog: Window
var _grid_toggle: Button
var _snap_toggle: Button
var _play_button: Button
var _stop_button: Button
var _sequence_content: HSplitContainer
var _left_panel: VBoxContainer
var _visual_editor: Control
var _transition_panel: VBoxContainer
var _dialogue_panel: VBoxContainer
var _tab_container: TabContainer
var _dialogue_list_container: VBoxContainer
var _add_dialogue_btn: Button
var _dialogue_editor: Control
var _ending_editor: VBoxContainer

# UI — Condition editor
var _condition_editor_panel: VBoxContainer
var _condition_editor: VBoxContainer

# UI — Play overlay
var _play_overlay: PanelContainer
var _play_character_label: Label
var _play_text_label: RichTextLabel
var _typewriter_timer: Timer
var _choice_overlay: PanelContainer

# Helpers
var _foreground_transition: Node
var _story_play_ctrl: Node


func _ready() -> void:
	_editor_main = Control.new()
	_editor_main.set_script(EditorMainScript)

	_sequence_editor_ctrl = Control.new()
	_sequence_editor_ctrl.set_script(SequenceEditorScript)

	# Construire l'arborescence UI
	MainUIBuilder.build(self)

	# Créer les contrôleurs
	_play_ctrl = Node.new()
	_play_ctrl.set_script(PlayControllerScript)
	_play_ctrl.setup(self)
	add_child(_play_ctrl)

	_nav_ctrl = Node.new()
	_nav_ctrl.set_script(NavigationControllerScript)
	_nav_ctrl.setup(self)
	add_child(_nav_ctrl)

	# --- Connexion des signaux ---

	# Top bar → Navigation
	_back_button.pressed.connect(_nav_ctrl.on_back_pressed)
	_breadcrumb.level_clicked.connect(_nav_ctrl.on_breadcrumb_clicked)
	_breadcrumb.story_rename_requested.connect(_nav_ctrl.on_story_rename_requested)
	_create_button.pressed.connect(_nav_ctrl.on_create_pressed)
	_create_condition_button.pressed.connect(_nav_ctrl.on_create_condition_pressed)
	_variables_button.pressed.connect(_nav_ctrl.on_variables_pressed)
	_variable_panel.variables_changed.connect(_nav_ctrl.on_variables_changed)
	_save_button.pressed.connect(_nav_ctrl.on_save_pressed)
	_load_button.pressed.connect(_nav_ctrl.on_load_pressed)
	_new_story_button.pressed.connect(_nav_ctrl.on_new_story_pressed)

	# Top bar → Play
	_top_play_button.pressed.connect(_play_ctrl.on_top_play_pressed)
	_top_stop_button.pressed.connect(_play_ctrl.on_top_stop_pressed)

	# Graph views → Navigation
	_chapter_graph_view.chapter_double_clicked.connect(_nav_ctrl.on_chapter_double_clicked)
	_chapter_graph_view.chapter_rename_requested.connect(_nav_ctrl.on_chapter_rename_requested)
	_scene_graph_view.scene_double_clicked.connect(_nav_ctrl.on_scene_double_clicked)
	_scene_graph_view.scene_rename_requested.connect(_nav_ctrl.on_scene_rename_requested)
	_sequence_graph_view.sequence_double_clicked.connect(_nav_ctrl.on_sequence_double_clicked)
	_sequence_graph_view.sequence_rename_requested.connect(_nav_ctrl.on_sequence_rename_requested)
	_sequence_graph_view.condition_double_clicked.connect(_nav_ctrl.on_condition_double_clicked)
	_sequence_graph_view.condition_rename_requested.connect(_nav_ctrl.on_condition_rename_requested)

	# Sequence toolbar → Main
	_import_bg_button.pressed.connect(_on_import_bg_pressed)
	_add_fg_button.pressed.connect(_on_add_foreground_pressed)
	_ai_generate_btn.pressed.connect(_on_ai_generate_pressed)
	_grid_toggle.toggled.connect(_on_grid_toggled)
	_snap_toggle.toggled.connect(_on_snap_toggled)
	_add_dialogue_btn.pressed.connect(_on_add_dialogue_pressed)
	_dialogue_list_container.dialogue_delete_requested.connect(_on_delete_dialogue)

	# Sequence toolbar → Play
	_play_button.pressed.connect(_play_ctrl.on_play_pressed)
	_stop_button.pressed.connect(_play_ctrl.on_stop_pressed)

	# Editors → Navigation
	_ending_editor.ending_changed.connect(_nav_ctrl.on_ending_changed)
	_condition_editor.condition_changed.connect(_nav_ctrl.on_condition_changed)

	# Play signals → Play controller
	_typewriter_timer.timeout.connect(_play_ctrl.on_typewriter_tick)
	_story_play_ctrl.sequence_play_requested.connect(_play_ctrl.on_story_play_sequence_requested)
	_story_play_ctrl.choice_display_requested.connect(_play_ctrl.on_story_play_choice_requested)
	_story_play_ctrl.play_finished.connect(_play_ctrl.on_story_play_finished)
	_sequence_editor_ctrl.play_dialogue_changed.connect(_play_ctrl.on_play_dialogue_changed)
	_sequence_editor_ctrl.play_stopped.connect(_play_ctrl.on_play_stopped)

	# Sequence editor → Main
	_sequence_editor_ctrl.dialogue_selected.connect(_on_dialogue_selected)

	# Visual editor → Main
	_visual_editor.foreground_selected.connect(_on_foreground_selected)
	_visual_editor.foreground_deselected.connect(_on_foreground_deselected)

	update_view()


# --- Grid & Snap toggles ---

func _on_grid_toggled(toggled_on: bool) -> void:
	_visual_editor.set_grid_visible(toggled_on)


func _on_snap_toggled(toggled_on: bool) -> void:
	_visual_editor.set_snap_enabled(toggled_on)


# --- Sequence Editor Actions ---

func _on_import_bg_pressed() -> void:
	_open_image_picker(ImagePickerDialogScript.Mode.BACKGROUND, _on_bg_file_selected)


func _on_bg_file_selected(path: String) -> void:
	_sequence_editor_ctrl.set_background(path)
	_visual_editor.set_background(path)


func _on_add_foreground_pressed() -> void:
	if _sequence_editor_ctrl.get_selected_dialogue_index() < 0:
		var seq = _sequence_editor_ctrl.get_sequence()
		if seq and seq.dialogues.size() > 0:
			_sequence_editor_ctrl.select_dialogue(0)
		else:
			return
	_open_image_picker(ImagePickerDialogScript.Mode.FOREGROUND, _on_fg_file_selected)


func _open_image_picker(mode: int, on_selected: Callable) -> void:
	var picker = Window.new()
	picker.set_script(ImagePickerDialogScript)
	add_child(picker)
	var story_name = _get_story_name()
	picker.setup(mode, story_name)
	picker.image_selected.connect(on_selected)
	picker.popup_centered()


func _get_story_name() -> String:
	if _editor_main._story == null:
		return ""
	return _editor_main._story.title.to_lower().replace(" ", "_")


func _on_fg_file_selected(path: String) -> void:
	var idx = _sequence_editor_ctrl.get_selected_dialogue_index()
	if idx < 0:
		return
	_sequence_editor_ctrl.add_foreground_to_current("", path)
	update_preview_for_dialogue(idx)


func _on_ai_generate_pressed() -> void:
	if _sequence_editor_ctrl.get_selected_dialogue_index() < 0:
		var seq = _sequence_editor_ctrl.get_sequence()
		if seq and seq.dialogues.size() > 0:
			_sequence_editor_ctrl.select_dialogue(0)
		else:
			return

	if _ai_generate_dialog == null:
		_ai_generate_dialog = Window.new()
		_ai_generate_dialog.set_script(AIGenerateDialogScript)
		_ai_generate_dialog.foreground_accepted.connect(_on_ai_fg_accepted)
		add_child(_ai_generate_dialog)

	var config = ComfyUIConfigScript.new()
	config.load_from()

	# Pre-fill source image if a foreground is selected
	var source_path = ""
	if _visual_editor._selected_fg_uuid != "":
		var idx = _sequence_editor_ctrl.get_selected_dialogue_index()
		if idx >= 0:
			var fgs = _sequence_editor_ctrl.get_effective_foregrounds(idx)
			for fg in fgs:
				if fg.uuid == _visual_editor._selected_fg_uuid:
					source_path = fg.image
					break

	_ai_generate_dialog.setup(config, source_path)
	if _editor_main._story:
		_ai_generate_dialog.set_story_name(_editor_main._story.title.to_lower().replace(" ", "_"))
	_ai_generate_dialog.popup_centered()


func _on_ai_fg_accepted(image_path: String) -> void:
	var idx = _sequence_editor_ctrl.get_selected_dialogue_index()
	if idx < 0:
		return
	_sequence_editor_ctrl.add_foreground_to_current("", image_path)
	update_preview_for_dialogue(idx)


func _on_add_dialogue_pressed() -> void:
	_sequence_editor_ctrl.add_dialogue("", "")
	_rebuild_dialogue_list()


func _on_delete_dialogue(index: int) -> void:
	var confirm = ConfirmationDialog.new()
	confirm.dialog_text = "Supprimer ce dialogue ?"
	confirm.confirmed.connect(func():
		_sequence_editor_ctrl.remove_dialogue(index)
		_rebuild_dialogue_list()
	)
	add_child(confirm)
	confirm.popup_centered()


# --- Dialogue & Foreground selection ---

func _on_dialogue_selected(index: int) -> void:
	update_preview_for_dialogue(index)
	highlight_dialogue_in_list(index)


func _on_foreground_selected(uuid: String) -> void:
	var idx = _sequence_editor_ctrl.get_selected_dialogue_index()
	if idx < 0:
		_transition_panel.hide_panel()
		return
	var fgs = _sequence_editor_ctrl.get_effective_foregrounds(idx)
	for fg in fgs:
		if fg.uuid == uuid:
			_transition_panel.show_for_foreground(fg)
			return
	_transition_panel.hide_panel()


func _on_foreground_deselected() -> void:
	_transition_panel.hide_panel()


# --- Preview & Dialogue list ---

func update_preview_for_dialogue(index: int) -> void:
	var fgs = _sequence_editor_ctrl.get_effective_foregrounds(index)
	var seq = _sequence_editor_ctrl.get_sequence()
	if seq:
		seq.foregrounds = fgs
		_visual_editor.load_sequence(seq)


func highlight_dialogue_in_list(index: int) -> void:
	_dialogue_list_container.highlight_item(index)


func _rebuild_dialogue_list() -> void:
	_dialogue_list_container.setup(_sequence_editor_ctrl)


# --- View management ---

func load_sequence_editors(seq) -> void:
	_visual_editor.load_sequence(seq)
	_dialogue_editor.load_sequence(seq)
	_nav_ctrl.update_ending_targets()
	if _editor_main._story:
		_ending_editor.set_variable_names(_editor_main._story.get_variable_names())
	_ending_editor.load_sequence(seq)
	_sequence_editor_ctrl.load_sequence(seq)
	_rebuild_dialogue_list()
	_tab_container.current_tab = 0
	_nav_ctrl._update_ending_tab_indicator()
	_play_button.visible = true
	_stop_button.visible = false
	_play_overlay.visible = false


func refresh_current_view() -> void:
	var level = _editor_main.get_current_level()
	if level == "chapters":
		_chapter_graph_view.load_story(_editor_main._story)
	elif level == "scenes":
		_scene_graph_view.load_chapter(_editor_main._current_chapter)
	elif level == "sequences":
		_sequence_graph_view.load_scene(_editor_main._current_scene)
	update_view()


func update_view() -> void:
	var level = _editor_main.get_current_level()
	_chapter_graph_view.visible = (level == "chapters")
	_scene_graph_view.visible = (level == "scenes")
	_sequence_graph_view.visible = (level == "sequences")
	_sequence_editor_panel.visible = (level == "sequence_edit")
	_condition_editor_panel.visible = (level == "condition_edit")
	_back_button.visible = (level != "chapters" and level != "none")
	_create_button.visible = _editor_main.is_create_button_visible()
	if _create_button.visible:
		_create_button.text = _editor_main.get_create_button_label()
	_create_condition_button.visible = (level == "sequences")
	_variables_button.visible = (level in ["chapters", "scenes", "sequences"])
	_breadcrumb.set_current_level(level)
	_breadcrumb.set_path(_editor_main.get_breadcrumb_path())
	_top_play_button.visible = (level in ["chapters", "scenes", "sequences"]) and not _play_ctrl.is_story_play_mode()


# --- Alias de compatibilité (utilisés par les tests existants) ---

func _update_view() -> void:
	update_view()


func _refresh_current_view() -> void:
	refresh_current_view()


func _load_sequence_editors(seq) -> void:
	load_sequence_editors(seq)


func _update_ending_tab_indicator() -> void:
	_nav_ctrl._update_ending_tab_indicator()
