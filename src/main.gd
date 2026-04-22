# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends Control

## Scène principale — orchestre tous les composants de l'éditeur de visual novel.
## Délègue la construction UI, le play, la navigation et les actions UI à des contrôleurs dédiés.

const EditorMainScript = preload("res://src/ui/editors/editor_main.gd")
const SequenceEditorScript = preload("res://src/ui/sequence/sequence_editor.gd")
const ImagePickerDialogScript = preload("res://src/ui/dialogs/image_picker_dialog.gd")
const MainUIBuilder = preload("res://src/controllers/main_ui_builder.gd")
const PlayControllerScript = preload("res://src/controllers/play_controller.gd")
const NavigationControllerScript = preload("res://src/controllers/navigation_controller.gd")
const ExportServiceScript = preload("res://src/services/export_service.gd")
const NotificationServiceScript = preload("res://src/services/notification_service.gd")
const UndoRedoService = preload("res://src/services/undo_redo_service.gd")
const UIControllerScript = preload("res://src/controllers/ui_controller.gd")
const MenuControllerScript = preload("res://src/controllers/menu_controller.gd")
const SequenceUIControllerScript = preload("res://src/controllers/sequence_ui_controller.gd")
const PlayUIControllerScript = preload("res://src/controllers/play_ui_controller.gd")
const EditorState = preload("res://src/controllers/editor_state.gd")
const PluginManagerScript = preload("res://src/plugins/plugin_manager.gd")
const PluginContext = preload("res://src/plugins/plugin_context.gd")

# Contrôleurs métier
var _editor_main: Control
var _sequence_editor_ctrl: Control
var _play_ctrl: Node
var _nav_ctrl: Node
var _undo_redo: RefCounted
var _export_service: RefCounted
var _notification_service: RefCounted

# Contrôleurs UI (Refactor)
var _ui_ctrl: Node
var _menu_ctrl: Node
var _seq_ui_ctrl: Node
var _play_ui_ctrl: Node

# Plugin system
var _plugin_manager: Node
var _dock_left: PanelContainer
var _dock_right: PanelContainer
var _dock_bottom: PanelContainer

# UI — Top bar
var _vbox: VBoxContainer
var _top_bar_panel: PanelContainer
var _top_bar: HBoxContainer
var _back_button: Button
var _undo_button: Button
var _redo_button: Button
var _breadcrumb: HBoxContainer
var _map_button: Button
var _top_play_button: Button
var _top_stop_button: Button
var _create_button: Button
var _create_condition_button: Button
var _histoire_menu: MenuButton
var _parametres_menu: MenuButton
var _variable_panel_popup: PopupPanel
var _variable_panel: VBoxContainer

# UI — Content area
var _content_area: Control
var _chapter_graph_view: GraphEdit
var _chapter_plugin_toolbar: HBoxContainer
var _scene_graph_view: GraphEdit
var _scene_plugin_toolbar: HBoxContainer
var _sequence_graph_view: GraphEdit
var _map_view: Control

# UI — Sequence editor
var _sequence_editor_panel: VBoxContainer
var _sequence_toolbar: HBoxContainer
var _import_bg_button: Button
var _add_fg_button: Button
var _grid_toggle: Button
var _snap_toggle: Button
var _normalize_fg_button: Button
var _play_lang_selector: OptionButton
var _play_button: Button
var _stop_button: Button
var _sequence_content: HSplitContainer
var _visual_editor: Control
var _right_panel: VBoxContainer
var _dialogue_edit_section: VBoxContainer
var _layer_panel: VBoxContainer
var _properties_panel: VBoxContainer
var _tab_container: TabContainer
var _sequence_tab_container: TabContainer  # Alias for plugin system access
var _dialogue_timeline: PanelContainer
var _dialogue_editor: Control
var _ending_editor: VBoxContainer

# UI — Condition editor
var _condition_editor_panel: VBoxContainer
var _condition_editor: VBoxContainer

# UI — Verifier
var _verifier_report_panel: VBoxContainer

# UI — Welcome Screen
var _welcome_screen: VBoxContainer
var _new_story_button: Button
var _load_story_button: Button

# UI — Toast overlay (notifications)
var _toast_overlay: PanelContainer
var _toast_label: Label
var _toast_generation: int = 0

# UI — Play overlay
var _play_overlay: Control
var _play_dialogue_panel: PanelContainer
var _play_character_box: PanelContainer
var _play_character_label: Label
var _play_text_label: RichTextLabel
var _typewriter_timer: Timer
var _choice_overlay: CenterContainer
var _choice_panel: PanelContainer
var _play_title_overlay: CenterContainer
var _play_title_label: Label
var _play_subtitle_label: Label

# Helpers
var _foreground_transition: Node
var _story_play_ctrl: Node
var _sequence_fx_player: Node

# UI — Variables display (play)
var _variable_sidebar: VBoxContainer
var _variable_details_overlay: CenterContainer

# FX Panel
var _fx_panel: VBoxContainer

# Audio Panel (Musique + FX audio)
var _audio_panel: VBoxContainer

# Sequence Transitions UI
var _sequence_transition_panel: VBoxContainer
var _seq_title_edit: LineEdit
var _seq_subtitle_edit: LineEdit
var _seq_bg_color_picker: ColorPickerButton
var _seq_trans_in_type: OptionButton
var _seq_trans_in_dur: SpinBox
var _seq_trans_out_type: OptionButton
var _seq_trans_out_dur: SpinBox

func _ready() -> void:
	_editor_main = Control.new()
	_editor_main.set_script(EditorMainScript)

	_sequence_editor_ctrl = Control.new()
	_sequence_editor_ctrl.set_script(SequenceEditorScript)

	_undo_redo = UndoRedoService.new()
	_export_service = ExportServiceScript.new()
	_notification_service = NotificationServiceScript.new()

	# Construire l'arborescence UI via le builder
	MainUIBuilder.build(self)

	# Initialiser les contrôleurs
	_setup_controllers()

	# Connexion des signaux
	_connect_signals()

	# Charger les plugins
	_setup_plugins()

	update_view()


func _setup_controllers() -> void:
	_play_ctrl = Node.new()
	_play_ctrl.set_script(PlayControllerScript)
	_play_ctrl.setup(self)
	add_child(_play_ctrl)

	var music_player = MusicPlayer.new()
	add_child(music_player)
	_play_ctrl._music_player = music_player

	_nav_ctrl = Node.new()
	_nav_ctrl.set_script(NavigationControllerScript)
	_nav_ctrl.setup(self)
	add_child(_nav_ctrl)

	_ui_ctrl = Node.new()
	_ui_ctrl.set_script(UIControllerScript)
	_ui_ctrl.setup(self)
	add_child(_ui_ctrl)

	_menu_ctrl = Node.new()
	_menu_ctrl.set_script(MenuControllerScript)
	_menu_ctrl.setup(self)
	add_child(_menu_ctrl)

	_seq_ui_ctrl = Node.new()
	_seq_ui_ctrl.set_script(SequenceUIControllerScript)
	_seq_ui_ctrl.setup(self)
	add_child(_seq_ui_ctrl)

	_play_ui_ctrl = Node.new()
	_play_ui_ctrl.set_script(PlayUIControllerScript)
	_play_ui_ctrl.setup(self)
	add_child(_play_ui_ctrl)


func _setup_plugins() -> void:
	_plugin_manager = Node.new()
	_plugin_manager.set_script(PluginManagerScript)
	add_child(_plugin_manager)
	_plugin_manager.scan_and_load_plugins()
	_plugin_manager.apply_contributions(self)


func get_current_context() -> RefCounted:
	var ctx := PluginContext.new()
	ctx.main_node = self
	ctx.story = _editor_main._story
	ctx.story_base_path = _get_story_base_path()
	ctx.current_chapter = _editor_main._current_chapter
	ctx.current_scene = _editor_main._current_scene
	ctx.current_sequence = _editor_main._current_sequence
	return ctx


func _connect_signals() -> void:
	# Undo / Redo
	_undo_button.pressed.connect(_on_undo_pressed)
	_redo_button.pressed.connect(_on_redo_pressed)

	# Top bar
	_back_button.pressed.connect(_nav_ctrl.on_back_pressed)
	_breadcrumb.level_clicked.connect(_nav_ctrl.on_breadcrumb_clicked)
	_breadcrumb.story_rename_requested.connect(_nav_ctrl.on_story_rename_requested)
	_breadcrumb.menu_config_requested.connect(_nav_ctrl.on_menu_config_requested)
	_create_button.pressed.connect(_nav_ctrl.on_create_pressed)
	_create_condition_button.pressed.connect(_nav_ctrl.on_create_condition_pressed)
	_histoire_menu.get_popup().id_pressed.connect(_menu_ctrl.on_histoire_menu_pressed)
	_parametres_menu.get_popup().id_pressed.connect(_menu_ctrl.on_parametres_menu_pressed)
	_variable_panel.variables_changed.connect(_nav_ctrl.on_variables_changed)
	_verifier_report_panel.close_requested.connect(_nav_ctrl.on_verifier_close)

	# Welcome Screen
	_new_story_button.pressed.connect(_nav_ctrl.on_new_story_pressed)
	_load_story_button.pressed.connect(_nav_ctrl.on_load_pressed)

	# Top bar Map
	_map_button.pressed.connect(_nav_ctrl.on_map_pressed)
	_map_view.sequence_clicked.connect(_on_map_sequence_clicked)
	_map_view.condition_clicked.connect(_on_map_condition_clicked)
	_map_view.scene_clicked.connect(_on_map_scene_clicked)
	_map_view.chapter_clicked.connect(_on_map_chapter_clicked)

	# Top bar Play
	_top_play_button.pressed.connect(_play_ctrl.on_top_play_pressed)
	_top_stop_button.pressed.connect(_play_ctrl.on_top_stop_pressed)

	# Graph views
	_chapter_graph_view.chapter_double_clicked.connect(_nav_ctrl.on_chapter_double_clicked)
	_chapter_graph_view.chapter_rename_requested.connect(_nav_ctrl.on_chapter_rename_requested)
	_chapter_graph_view.chapter_delete_requested.connect(_nav_ctrl.on_chapter_delete_requested)
	_scene_graph_view.scene_double_clicked.connect(_nav_ctrl.on_scene_double_clicked)
	_scene_graph_view.scene_rename_requested.connect(_nav_ctrl.on_scene_rename_requested)
	_scene_graph_view.scene_delete_requested.connect(_nav_ctrl.on_scene_delete_requested)
	_sequence_graph_view.sequence_double_clicked.connect(_nav_ctrl.on_sequence_double_clicked)
	_sequence_graph_view.sequence_rename_requested.connect(_nav_ctrl.on_sequence_rename_requested)
	_sequence_graph_view.sequence_delete_requested.connect(_nav_ctrl.on_sequence_delete_requested)
	_sequence_graph_view.sequences_transition_requested.connect(_nav_ctrl.on_sequences_transition_requested)
	_sequence_graph_view.sequence_foregrounds_paste_requested.connect(_nav_ctrl.on_sequence_foregrounds_paste)
	_sequence_graph_view.condition_double_clicked.connect(_nav_ctrl.on_condition_double_clicked)
	_sequence_graph_view.condition_rename_requested.connect(_nav_ctrl.on_condition_rename_requested)
	_sequence_graph_view.condition_delete_requested.connect(_nav_ctrl.on_condition_delete_requested)

	# Sequence toolbar
	_import_bg_button.pressed.connect(_seq_ui_ctrl.on_import_bg_pressed)
	_add_fg_button.pressed.connect(_seq_ui_ctrl.on_add_foreground_pressed)
	_grid_toggle.toggled.connect(_seq_ui_ctrl.on_grid_toggled)
	_snap_toggle.toggled.connect(_seq_ui_ctrl.on_snap_toggled)
	_normalize_fg_button.pressed.connect(_seq_ui_ctrl.on_normalize_foregrounds_pressed)
	_play_button.pressed.connect(_play_ctrl.on_play_pressed)
	_stop_button.pressed.connect(_play_ctrl.on_stop_pressed)

	# Timeline
	_dialogue_timeline.dialogue_clicked.connect(_on_timeline_dialogue_clicked)
	_dialogue_timeline.add_dialogue_requested.connect(_seq_ui_ctrl.on_add_dialogue_pressed)
	_dialogue_timeline.dialogue_duplicate_requested.connect(_seq_ui_ctrl.on_duplicate_dialogue)
	_dialogue_timeline.dialogue_insert_before_requested.connect(_seq_ui_ctrl.on_insert_dialogue_before)
	_dialogue_timeline.dialogue_insert_after_requested.connect(_seq_ui_ctrl.on_insert_dialogue_after)
	_dialogue_timeline.dialogue_delete_requested.connect(_seq_ui_ctrl.on_delete_dialogue)
	_dialogue_timeline.foreground_dropped_on_dialogue.connect(_on_foreground_dropped_on_dialogue)

	# Dialogue edit section
	_dialogue_edit_section.dialogue_character_changed.connect(_on_dialogue_character_changed)
	_dialogue_edit_section.dialogue_text_changed.connect(_on_dialogue_text_changed)
	_dialogue_edit_section.dialogue_delete_requested.connect(_seq_ui_ctrl.on_delete_dialogue)

	# Layer panel
	_layer_panel.foreground_clicked.connect(_on_layer_foreground_clicked)
	_layer_panel.foreground_visibility_toggled.connect(_on_layer_visibility_toggled)
	_layer_panel.add_foreground_requested.connect(_seq_ui_ctrl.on_add_foreground_pressed)

	# Properties panel
	_properties_panel.properties_changed.connect(_on_foreground_properties_changed)

	# Editors
	_ending_editor.ending_changed.connect(_nav_ctrl.on_ending_changed)
	_ending_editor.new_target_requested.connect(_nav_ctrl._on_new_target_requested)
	_condition_editor.condition_changed.connect(_nav_ctrl.on_condition_changed)
	_condition_editor.new_target_requested.connect(_nav_ctrl._on_new_target_requested)

	# Play signals
	_typewriter_timer.timeout.connect(_play_ctrl.on_typewriter_tick)
	_story_play_ctrl.sequence_play_requested.connect(_play_ctrl.on_story_play_sequence_requested)
	_story_play_ctrl.choice_display_requested.connect(_play_ctrl.on_story_play_choice_requested)
	_story_play_ctrl.play_finished.connect(_play_ctrl.on_story_play_finished)
	_story_play_ctrl.variables_display_changed.connect(_on_variables_display_changed)
	_variable_sidebar.details_requested.connect(_on_variable_details_requested)
	_variable_details_overlay.close_requested.connect(_on_variable_details_close)
	EventBus.editor_mode_changed.connect(_on_editor_mode_changed)
	EventBus.play_started.connect(_on_play_started)
	EventBus.play_stopped.connect(_on_play_stopped)
	EventBus.story_modified.connect(_on_story_modified)
	_sequence_editor_ctrl.play_dialogue_changed.connect(_play_ctrl.on_play_dialogue_changed)
	_sequence_editor_ctrl.play_stopped.connect(_play_ctrl.on_play_stopped)

	# UI Glue (Selection)
	_sequence_editor_ctrl.dialogue_selected.connect(_on_dialogue_selected)
	_visual_editor.foreground_selected.connect(_on_foreground_selected)
	_visual_editor.foreground_deselected.connect(_on_foreground_deselected)
	_visual_editor.foreground_replace_requested.connect(_seq_ui_ctrl.on_foreground_replace_requested)
	_visual_editor.foreground_replace_with_new_requested.connect(_seq_ui_ctrl.on_foreground_replace_with_new_requested)
	_visual_editor.inherited_foreground_edit_confirmed.connect(_on_inherited_fg_edit_confirmed)
	_visual_editor.foreground_modified.connect(_seq_ui_ctrl.on_foreground_modified)
	_visual_editor.foreground_modified.connect(func(_uuid: String = ""): _rebuild_dialogue_list())
	_fx_panel.fx_changed.connect(_on_fx_changed)
	_audio_panel.audio_changed.connect(_on_audio_changed)

	# Sequence Transitions
	_seq_title_edit.text_changed.connect(_on_sequence_transition_changed)
	_seq_subtitle_edit.text_changed.connect(_on_sequence_transition_changed)
	_seq_bg_color_picker.color_changed.connect(_on_sequence_transition_changed)
	_seq_trans_in_type.item_selected.connect(_on_sequence_transition_changed)
	_seq_trans_in_dur.value_changed.connect(_on_sequence_transition_changed)
	_seq_trans_out_type.item_selected.connect(_on_sequence_transition_changed)
	_seq_trans_out_dur.value_changed.connect(_on_sequence_transition_changed)


# --- Public API / Helpers used by controllers ---

func _get_story_base_path() -> String:
	return _nav_ctrl.get_save_path()


func update_preview_for_dialogue(index: int) -> void:
	var fgs = _sequence_editor_ctrl.get_effective_foregrounds(index)
	_visual_editor.set_display_foregrounds(fgs)


func highlight_dialogue_in_list(index: int) -> void:
	_dialogue_timeline.highlight_item(index)


func _rebuild_dialogue_list() -> void:
	_dialogue_timeline.setup(_sequence_editor_ctrl)


func _update_ending_tab_indicator() -> void:
	if _tab_container == null: return
	var seq = _sequence_editor_ctrl.get_sequence()
	# Terminaison est l'onglet index 2 (après Texte et Calques)
	var terminaison_idx := 2
	if seq and seq.ending != null:
		_tab_container.set_tab_title(terminaison_idx, "Terminaison ●")
	else:
		_tab_container.set_tab_title(terminaison_idx, "Terminaison")


# --- Selection handlers ---

func _on_dialogue_selected(index: int) -> void:
	update_preview_for_dialogue(index)
	highlight_dialogue_in_list(index)
	_update_dialogue_edit_section(index)
	_update_layer_panel(index)
	_update_visual_editor_inherited_mode(index)
	_properties_panel.hide_panel()


func _update_dialogue_edit_section(index: int) -> void:
	var seq = _sequence_editor_ctrl.get_sequence()
	if seq == null or index < 0 or index >= seq.dialogues.size():
		_dialogue_edit_section.clear()
		return
	_dialogue_edit_section.load_dialogue(index, seq.dialogues[index])


func _update_layer_panel(index: int) -> void:
	var seq = _sequence_editor_ctrl.get_sequence()
	if seq == null or index < 0 or index >= seq.dialogues.size():
		_layer_panel.update_layers([], false)
		return
	var dlg = seq.dialogues[index]
	var has_own_fg = dlg.foregrounds.size() > 0
	var fgs = _sequence_editor_ctrl.get_effective_foregrounds(index)
	var is_inherited = not has_own_fg and fgs.size() > 0
	var inherited_from = _sequence_editor_ctrl.get_inheritance_source_index(index) if is_inherited else -1
	_layer_panel.update_layers(fgs, is_inherited, inherited_from)


func _on_foreground_selected(uuid: String) -> void:
	var idx = _sequence_editor_ctrl.get_selected_dialogue_index()
	if idx < 0:
		_properties_panel.hide_panel()
		return
	var fgs = _sequence_editor_ctrl.get_effective_foregrounds(idx)
	for fg in fgs:
		if fg.uuid == uuid:
			_properties_panel.show_for_foreground(fg)
			_layer_panel.select_foreground(uuid)
			_seq_ui_ctrl.on_foreground_selected(uuid)
			return
	_properties_panel.hide_panel()


func _on_foreground_deselected() -> void:
	_properties_panel.hide_panel()
	_layer_panel.deselect_all()
	_seq_ui_ctrl.on_foreground_deselected()


func _on_foreground_properties_changed() -> void:
	_visual_editor.refresh_foreground_z_order()
	_visual_editor.refresh_foreground_flip()
	_visual_editor.update_foregrounds()
	var idx = _sequence_editor_ctrl.get_selected_dialogue_index()
	if idx >= 0:
		_dialogue_timeline.update_item(idx)
	else:
		_rebuild_dialogue_list()
	EventBus.story_modified.emit()
	_seq_ui_ctrl.on_foreground_modified()


# --- New handlers for timeline and layer panel ---

func _on_timeline_dialogue_clicked(index: int) -> void:
	_sequence_editor_ctrl.select_dialogue(index)


func _on_dialogue_character_changed(index: int, character: String) -> void:
	var seq = _sequence_editor_ctrl.get_sequence()
	if seq == null or index < 0 or index >= seq.dialogues.size():
		return
	seq.dialogues[index].character = character
	_dialogue_timeline.update_item_text(index, character, seq.dialogues[index].text)
	EventBus.story_modified.emit()


func _on_dialogue_text_changed(index: int, text: String) -> void:
	var seq = _sequence_editor_ctrl.get_sequence()
	if seq == null or index < 0 or index >= seq.dialogues.size():
		return
	seq.dialogues[index].text = text
	_dialogue_timeline.update_item_text(index, seq.dialogues[index].character, text)
	EventBus.story_modified.emit()


func _on_layer_foreground_clicked(uuid: String) -> void:
	_visual_editor.select_foreground_by_uuid(uuid)


func _on_layer_visibility_toggled(uuid: String, is_visible: bool) -> void:
	if is_visible:
		_visual_editor.show_foreground(uuid)
	else:
		_visual_editor.hide_foreground(uuid)


func _on_foreground_dropped_on_dialogue(fg_data, target_index: int) -> void:
	var seq = _sequence_editor_ctrl.get_sequence()
	if seq == null or target_index < 0 or target_index >= seq.dialogues.size():
		return
	# Ensure target dialogue has own foregrounds
	_sequence_editor_ctrl.ensure_own_foregrounds(target_index)
	# Copy the foreground with a new UUID
	var fg_copy = _sequence_editor_ctrl._copy_foreground(fg_data.foreground)
	fg_copy.uuid = _generate_uuid()
	seq.dialogues[target_index].foregrounds.append(fg_copy)
	_rebuild_dialogue_list()
	EventBus.story_modified.emit()


func _update_visual_editor_inherited_mode(index: int) -> void:
	var is_inherited = _sequence_editor_ctrl.is_dialogue_inheriting(index)
	var from_index = _sequence_editor_ctrl.get_inheritance_source_index(index) if is_inherited else -1
	_visual_editor.set_inherited_mode(is_inherited, from_index)


func _on_inherited_fg_edit_confirmed() -> void:
	var idx = _sequence_editor_ctrl.get_selected_dialogue_index()
	if idx < 0:
		return
	_sequence_editor_ctrl.ensure_own_foregrounds(idx)
	_update_layer_panel(idx)
	_visual_editor.set_inherited_mode(false)
	update_preview_for_dialogue(idx)
	EventBus.story_modified.emit()
	# Re-resolve foreground by UUID after ensure_own_foregrounds (new objects)
	var selected_uuid = _visual_editor._selected_fg_uuid
	if selected_uuid != "":
		var seq = _sequence_editor_ctrl.get_sequence()
		if seq and idx >= 0 and idx < seq.dialogues.size():
			for fg in seq.dialogues[idx].foregrounds:
				if fg.uuid == selected_uuid:
					_seq_ui_ctrl.on_foreground_selected(selected_uuid)
					break


func _generate_uuid() -> String:
	var chars = "0123456789abcdef"
	var uuid = ""
	for i in range(32):
		if i == 8 or i == 12 or i == 16 or i == 20:
			uuid += "-"
		uuid += chars[randi() % chars.length()]
	return uuid


func _on_fx_changed() -> void:
	EventBus.story_modified.emit()


func _on_audio_changed() -> void:
	EventBus.story_modified.emit()


func _on_sequence_transition_changed(_value = null) -> void:
	if _loading_sequence:
		return
	var seq = _sequence_editor_ctrl.get_sequence()
	if seq == null: return
	
	seq.title = _seq_title_edit.text
	seq.subtitle = _seq_subtitle_edit.text
	seq.background_color = _seq_bg_color_picker.color.to_html()
	
	var in_types = ["none", "fade", "pixelate"]
	var in_idx = _seq_trans_in_type.selected
	if in_idx >= 0 and in_idx < in_types.size():
		seq.transition_in_type = in_types[in_idx]
	
	seq.transition_in_duration = _seq_trans_in_dur.value
	
	var out_types = ["none", "fade", "pixelate"]
	var out_idx = _seq_trans_out_type.selected
	if out_idx >= 0 and out_idx < out_types.size():
		seq.transition_out_type = out_types[out_idx]
		
	seq.transition_out_duration = _seq_trans_out_dur.value
	
	_visual_editor._update_visual()
	EventBus.story_modified.emit()


# --- View management ---

var _loading_sequence: bool = false

func load_sequence_editors(seq) -> void:
	_loading_sequence = true
	_sequence_fx_player.stop_fx()
	_visual_editor.load_sequence(seq)
	_dialogue_editor.load_sequence(seq)
	_nav_ctrl.notify_targets_changed()
	_ending_editor.load_sequence(seq)
	_fx_panel.load_sequence(seq)
	_audio_panel.load_sequence(seq)
	_audio_panel.setup_story_path(_get_story_base_path(), self)

	# Load params (signals are blocked by _loading_sequence flag)
	_seq_title_edit.text = seq.title
	_seq_subtitle_edit.text = seq.subtitle
	if seq.background_color != "":
		_seq_bg_color_picker.color = Color.from_string(seq.background_color, Color(0,0,0,0))
	else:
		_seq_bg_color_picker.color = Color(0,0,0,0)

	# Load transitions
	var in_types = ["none", "fade", "pixelate"]
	var in_idx = in_types.find(seq.transition_in_type)
	_seq_trans_in_type.selected = in_idx if in_idx >= 0 else 0
	_seq_trans_in_dur.value = seq.transition_in_duration

	var out_types = ["none", "fade", "pixelate"]
	var out_idx = out_types.find(seq.transition_out_type)
	_seq_trans_out_type.selected = out_idx if out_idx >= 0 else 0
	_seq_trans_out_dur.value = seq.transition_out_duration

	_sequence_editor_ctrl.load_sequence(seq)
	_loading_sequence = false
	_plugin_manager.notify_sequence_tabs()
	_update_ending_tab_indicator()
	_rebuild_dialogue_list()
	if seq.dialogues.size() > 0:
		_sequence_editor_ctrl.select_dialogue(0)
	else:
		_dialogue_edit_section.clear()
		_layer_panel.update_layers([], false)
		_properties_panel.hide_panel()
	
	var is_playing = _play_ctrl.is_story_play_mode()
	_play_button.visible = not is_playing
	_stop_button.visible = false
	_play_overlay.visible = is_playing
	
	if is_playing:
		if _play_overlay.get_parent():
			_play_overlay.get_parent().remove_child(_play_overlay)
		_visual_editor._overlay_container.add_child(_play_overlay)


func refresh_current_view() -> void:
	var level = _editor_main.get_current_level()
	if level == "chapters":
		_chapter_graph_view.load_story(_editor_main._story)
	elif level == "scenes":
		_scene_graph_view.load_chapter(_editor_main._current_chapter)
	elif level == "sequences":
		_sequence_graph_view.load_scene(_editor_main._current_scene)
	elif level == "map":
		_map_view.load_story(_editor_main._story)
	_refresh_play_lang_selector()
	update_editor_mode()


func _refresh_play_lang_selector() -> void:
	if _play_lang_selector == null:
		return
	var previous: String = ""
	if _play_lang_selector.get_item_count() > 0 and not _play_lang_selector.disabled:
		previous = _play_lang_selector.get_item_text(_play_lang_selector.selected)
	_play_lang_selector.clear()
	var base_path := _get_story_base_path()
	if base_path == "":
		_play_lang_selector.add_item("--")
		_play_lang_selector.disabled = true
		return
	var StoryI18nSvc = load("res://src/services/story_i18n_service.gd")
	var lang_config: Dictionary = StoryI18nSvc.load_languages_config(base_path)
	var default_lang: String = lang_config.get("default", "fr")
	var languages: Array = lang_config.get("languages", [default_lang])
	if languages.is_empty():
		languages = [default_lang]
	_play_lang_selector.disabled = false
	var select_idx := 0
	for i in range(languages.size()):
		_play_lang_selector.add_item(languages[i])
		if languages[i] == previous:
			select_idx = i
		elif previous == "" and languages[i] == default_lang:
			select_idx = i
	_play_lang_selector.selected = select_idx


func get_play_language() -> String:
	if _play_lang_selector == null or _play_lang_selector.get_item_count() == 0 or _play_lang_selector.disabled:
		return ""
	return _play_lang_selector.get_item_text(_play_lang_selector.selected)


func update_view() -> void:
	update_editor_mode()


func update_editor_mode() -> void:
	_nav_ctrl.update_editor_mode()


func _on_editor_mode_changed(_mode: int, _context: Dictionary) -> void:
	_refresh_undo_redo_buttons()


# --- Map navigation ---

func _on_map_sequence_clicked(chapter_uuid: String, scene_uuid: String, seq_uuid: String) -> void:
	_editor_main.navigate_from_map(chapter_uuid, scene_uuid, seq_uuid, false)
	_nav_ctrl.update_editor_mode()
	if _editor_main._current_sequence:
		load_sequence_editors(_editor_main._current_sequence)
	refresh_current_view()


func _on_map_condition_clicked(chapter_uuid: String, scene_uuid: String, cond_uuid: String) -> void:
	_editor_main.navigate_from_map(chapter_uuid, scene_uuid, cond_uuid, true)
	_nav_ctrl.update_editor_mode()
	refresh_current_view()


func _on_map_scene_clicked(chapter_uuid: String, scene_uuid: String) -> void:
	_editor_main.navigate_to_chapter(chapter_uuid)
	_editor_main.navigate_to_scene(scene_uuid)
	_nav_ctrl.update_editor_mode()
	refresh_current_view()


func _on_map_chapter_clicked(chapter_uuid: String) -> void:
	_editor_main.navigate_to_chapter(chapter_uuid)
	_nav_ctrl.update_editor_mode()
	refresh_current_view()


func _on_play_started(_mode: String) -> void:
	_typewriter_timer.start()


func _on_play_stopped() -> void:
	_typewriter_timer.stop()
	# Masquer et retirer la sidebar/overlay des variables
	_variable_sidebar.visible = false
	if _variable_sidebar.get_parent():
		_variable_sidebar.get_parent().remove_child(_variable_sidebar)
	_variable_details_overlay.hide_details()
	if _variable_details_overlay.get_parent():
		_variable_details_overlay.get_parent().remove_child(_variable_details_overlay)


func _on_story_modified() -> void:
	_update_ending_tab_indicator()


func _reset_visual_editor() -> void:
	if _visual_editor._is_preview_mode:
		return
	_visual_editor.reset_view()


# --- Input / Undo / Redo ---

func _input(event: InputEvent) -> void:
	_ui_ctrl.handle_input(event)


func _on_undo_pressed() -> void:
	_undo_redo.undo()
	refresh_current_view()
	_refresh_undo_redo_buttons()


func _on_redo_pressed() -> void:
	_undo_redo.redo()
	refresh_current_view()
	_refresh_undo_redo_buttons()


func _refresh_undo_redo_buttons() -> void:
	_ui_ctrl.refresh_undo_redo_buttons()


# --- Variables display (play) ---

func _on_variables_display_changed(variables: Dictionary) -> void:
	var story = _editor_main._story if _editor_main else null
	_variable_sidebar.update_display(variables, story)
	# Ajouter la sidebar au visual editor overlay si pas déjà présente
	if _variable_sidebar.visible and _variable_sidebar.get_parent() != _visual_editor._overlay_container:
		if _variable_sidebar.get_parent():
			_variable_sidebar.get_parent().remove_child(_variable_sidebar)
		_visual_editor._overlay_container.add_child(_variable_sidebar)


func _on_variable_details_requested() -> void:
	var story = _editor_main._story if _editor_main else null
	var vars: Dictionary = {}
	if _story_play_ctrl.get("_variables") != null:
		vars = _story_play_ctrl._variables
	_variable_details_overlay.show_details(story, vars)
	if not _variable_details_overlay.get_parent():
		_visual_editor._overlay_container.add_child(_variable_details_overlay)


func _on_variable_details_close() -> void:
	_variable_details_overlay.hide_details()
	if _variable_details_overlay.get_parent():
		_variable_details_overlay.get_parent().remove_child(_variable_details_overlay)
