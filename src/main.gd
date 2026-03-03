extends Control

## Scène principale — orchestre tous les composants de l'éditeur de visual novel.
## Délègue la construction UI, le play et la navigation à des contrôleurs dédiés.

const EditorMainScript = preload("res://src/ui/editors/editor_main.gd")
const SequenceEditorScript = preload("res://src/ui/sequence/sequence_editor.gd")
const ImagePickerDialogScript = preload("res://src/ui/dialogs/image_picker_dialog.gd")
const MainUIBuilder = preload("res://src/controllers/main_ui_builder.gd")
const PlayControllerScript = preload("res://src/controllers/play_controller.gd")
const NavigationControllerScript = preload("res://src/controllers/navigation_controller.gd")
const ExportDialogScript = preload("res://src/ui/dialogs/export_dialog.gd")
const GalleryDialogScript = preload("res://src/ui/dialogs/gallery_dialog.gd")
const NotificationDialogScript = preload("res://src/ui/dialogs/notification_dialog.gd")
const LanguageManagerDialogScript = preload("res://src/ui/dialogs/language_manager_dialog.gd")
const I18nDialogScript = preload("res://src/ui/dialogs/i18n_dialog.gd")
const StoryI18nService = preload("res://src/services/story_i18n_service.gd")
const UndoRedoService = preload("res://src/services/undo_redo_service.gd")
const ExportServiceScript = preload("res://src/services/export_service.gd")
const NotificationServiceScript = preload("res://src/services/notification_service.gd")
const AddDialogueCommand = preload("res://src/commands/add_dialogue_command.gd")
const RemoveDialogueCommand = preload("res://src/commands/remove_dialogue_command.gd")
const EditDialogueCommand = preload("res://src/commands/edit_dialogue_command.gd")
const EditorState = preload("res://src/controllers/editor_state.gd")

# Contrôleurs
var _editor_main: Control
var _sequence_editor_ctrl: Control
var _play_ctrl: Node
var _nav_ctrl: Node
var _undo_redo: RefCounted
var _export_service: RefCounted
var _notification_service: RefCounted

# UI — Top bar
var _vbox: VBoxContainer
var _top_bar: HBoxContainer
var _back_button: Button
var _undo_button: Button
var _redo_button: Button
var _breadcrumb: HBoxContainer
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
var _scene_graph_view: GraphEdit
var _sequence_graph_view: GraphEdit

# UI — Sequence editor
var _sequence_editor_panel: VBoxContainer
var _sequence_toolbar: HBoxContainer
var _import_bg_button: Button
var _add_fg_button: Button
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

# UI — Verifier
var _verifier_report_panel: VBoxContainer

# UI — Toast overlay (notifications)
var _toast_overlay: PanelContainer
var _toast_label: Label
var _toast_generation: int = 0

# UI — Play overlay
var _play_overlay: PanelContainer
var _play_character_label: Label
var _play_text_label: RichTextLabel
var _typewriter_timer: Timer
var _choice_overlay: PanelContainer

# Helpers
var _foreground_transition: Node
var _story_play_ctrl: Node
var _sequence_fx_player: Node

# FX Panel
var _fx_panel: VBoxContainer


func _ready() -> void:
	_editor_main = Control.new()
	_editor_main.set_script(EditorMainScript)

	_sequence_editor_ctrl = Control.new()
	_sequence_editor_ctrl.set_script(SequenceEditorScript)

	_undo_redo = UndoRedoService.new()
	_export_service = ExportServiceScript.new()
	_notification_service = NotificationServiceScript.new()

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

	# Undo / Redo buttons
	_undo_button.pressed.connect(_on_undo_pressed)
	_redo_button.pressed.connect(_on_redo_pressed)

	# Top bar → Navigation
	_back_button.pressed.connect(_nav_ctrl.on_back_pressed)
	_breadcrumb.level_clicked.connect(_nav_ctrl.on_breadcrumb_clicked)
	_breadcrumb.story_rename_requested.connect(_nav_ctrl.on_story_rename_requested)
	_breadcrumb.menu_config_requested.connect(_nav_ctrl.on_menu_config_requested)
	_create_button.pressed.connect(_nav_ctrl.on_create_pressed)
	_create_condition_button.pressed.connect(_nav_ctrl.on_create_condition_pressed)
	_histoire_menu.get_popup().id_pressed.connect(_on_histoire_menu_pressed)
	_parametres_menu.get_popup().id_pressed.connect(_on_parametres_menu_pressed)
	_variable_panel.variables_changed.connect(_nav_ctrl.on_variables_changed)
	_verifier_report_panel.close_requested.connect(_nav_ctrl.on_verifier_close)

	# Top bar → Play
	_top_play_button.pressed.connect(_play_ctrl.on_top_play_pressed)
	_top_stop_button.pressed.connect(_play_ctrl.on_top_stop_pressed)

	# Graph views → Navigation
	_chapter_graph_view.chapter_double_clicked.connect(_nav_ctrl.on_chapter_double_clicked)
	_chapter_graph_view.chapter_rename_requested.connect(_nav_ctrl.on_chapter_rename_requested)
	_chapter_graph_view.chapter_delete_requested.connect(_nav_ctrl.on_chapter_delete_requested)
	_scene_graph_view.scene_double_clicked.connect(_nav_ctrl.on_scene_double_clicked)
	_scene_graph_view.scene_rename_requested.connect(_nav_ctrl.on_scene_rename_requested)
	_scene_graph_view.scene_delete_requested.connect(_nav_ctrl.on_scene_delete_requested)
	_sequence_graph_view.sequence_double_clicked.connect(_nav_ctrl.on_sequence_double_clicked)
	_sequence_graph_view.sequence_rename_requested.connect(_nav_ctrl.on_sequence_rename_requested)
	_sequence_graph_view.sequence_delete_requested.connect(_nav_ctrl.on_sequence_delete_requested)
	_sequence_graph_view.condition_double_clicked.connect(_nav_ctrl.on_condition_double_clicked)
	_sequence_graph_view.condition_rename_requested.connect(_nav_ctrl.on_condition_rename_requested)
	_sequence_graph_view.condition_delete_requested.connect(_nav_ctrl.on_condition_delete_requested)

	# Sequence toolbar → Main
	_import_bg_button.pressed.connect(_on_import_bg_pressed)
	_add_fg_button.pressed.connect(_on_add_foreground_pressed)
	_grid_toggle.toggled.connect(_on_grid_toggled)
	_snap_toggle.toggled.connect(_on_snap_toggled)
	_add_dialogue_btn.pressed.connect(_on_add_dialogue_pressed)
	_dialogue_list_container.dialogue_delete_requested.connect(_on_delete_dialogue)

	# Sequence toolbar → Play
	_play_button.pressed.connect(_play_ctrl.on_play_pressed)
	_stop_button.pressed.connect(_play_ctrl.on_stop_pressed)

	# Editors → Navigation
	_ending_editor.ending_changed.connect(_nav_ctrl.on_ending_changed)
	_ending_editor.new_target_requested.connect(_nav_ctrl._on_new_target_requested)
	_condition_editor.condition_changed.connect(_nav_ctrl.on_condition_changed)
	_condition_editor.new_target_requested.connect(_nav_ctrl._on_new_target_requested)

	# Play signals → Play controller
	_typewriter_timer.timeout.connect(_play_ctrl.on_typewriter_tick)
	_story_play_ctrl.sequence_play_requested.connect(_play_ctrl.on_story_play_sequence_requested)
	_story_play_ctrl.choice_display_requested.connect(_play_ctrl.on_story_play_choice_requested)
	_story_play_ctrl.play_finished.connect(_play_ctrl.on_story_play_finished)
	_notification_service.message_requested.connect(_on_notification_triggered)
	EventBus.notification_requested.connect(_on_notification_triggered)
	EventBus.editor_mode_changed.connect(_on_editor_mode_changed)
	EventBus.play_started.connect(_on_play_started)
	EventBus.play_stopped.connect(_on_play_stopped)
	EventBus.play_dialogue_changed.connect(_on_play_dialogue_changed)
	EventBus.play_typewriter_tick.connect(_on_play_typewriter_tick)
	EventBus.play_choice_requested.connect(_on_play_choice_requested)
	EventBus.play_finished.connect(_on_play_finished)
	EventBus.story_modified.connect(_on_story_modified)
	_sequence_editor_ctrl.play_dialogue_changed.connect(_play_ctrl.on_play_dialogue_changed)
	_sequence_editor_ctrl.play_stopped.connect(_play_ctrl.on_play_stopped)

	# Sequence editor → Main
	_sequence_editor_ctrl.dialogue_selected.connect(_on_dialogue_selected)

	# Visual editor → Main
	_visual_editor.foreground_selected.connect(_on_foreground_selected)
	_visual_editor.foreground_deselected.connect(_on_foreground_deselected)

	# FX panel → Main
	_fx_panel.fx_changed.connect(_on_fx_changed)

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
	var story_base_path = _get_story_base_path()
	picker.setup(mode, story_base_path)
	picker.image_selected.connect(on_selected)
	# Pre-fill IA source image
	var source = _get_current_source_image(mode)
	if source != "":
		picker.set_source_image(source)
	picker.popup_centered()


func _get_story_base_path() -> String:
	return _nav_ctrl.get_save_path()


func _on_fg_file_selected(path: String) -> void:
	var idx = _sequence_editor_ctrl.get_selected_dialogue_index()
	if idx < 0:
		return
	_sequence_editor_ctrl.add_foreground_to_current("", path)
	update_preview_for_dialogue(idx)


func _get_current_source_image(mode: int) -> String:
	if mode == ImagePickerDialogScript.Mode.FOREGROUND:
		if _visual_editor._selected_fg_uuid != "":
			var idx = _sequence_editor_ctrl.get_selected_dialogue_index()
			if idx >= 0:
				var fgs = _sequence_editor_ctrl.get_effective_foregrounds(idx)
				for fg in fgs:
					if fg.uuid == _visual_editor._selected_fg_uuid:
						return fg.image
	elif mode == ImagePickerDialogScript.Mode.BACKGROUND:
		var seq = _sequence_editor_ctrl.get_sequence()
		if seq and seq.background != "":
			return seq.background
	return ""


func _on_add_dialogue_pressed() -> void:
	var seq = _sequence_editor_ctrl.get_sequence()
	if seq == null:
		return
	
	var index = _sequence_editor_ctrl.get_selected_dialogue_index()
	if index >= 0:
		index += 1
	else:
		index = seq.dialogues.size()
	
	var cmd = AddDialogueCommand.new(seq, "Nouveau", "Texte", index)
	_undo_redo.push_and_execute(cmd)
	_rebuild_dialogue_list()
	_on_dialogue_selected(index)


func _on_delete_dialogue(index: int) -> void:
	var seq = _sequence_editor_ctrl.get_sequence()
	if seq == null:
		return
		
	var confirm = ConfirmationDialog.new()
	confirm.dialog_text = "Supprimer ce dialogue ?"
	confirm.confirmed.connect(func():
		var cmd = RemoveDialogueCommand.new(seq, index)
		_undo_redo.push_and_execute(cmd)
		
		# Ajuster la sélection dans le contrôleur si nécessaire
		var current_sel = _sequence_editor_ctrl.get_selected_dialogue_index()
		if current_sel == index:
			_sequence_editor_ctrl.select_dialogue(-1)
		elif current_sel > index:
			_sequence_editor_ctrl.select_dialogue(current_sel - 1)
			
		_rebuild_dialogue_list()
		confirm.queue_free()
	)
	confirm.canceled.connect(func(): confirm.queue_free())
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


func _on_fx_changed() -> void:
	pass  # FX are stored directly on the sequence model; no extra action needed


# --- Preview & Dialogue list ---

func update_preview_for_dialogue(index: int) -> void:
	var fgs = _sequence_editor_ctrl.get_effective_foregrounds(index)
	var seq = _sequence_editor_ctrl.get_sequence()
	if seq:
		seq.foregrounds = fgs
		_visual_editor.load_sequence(seq)


func highlight_dialogue_in_list(index: int) -> void:
	_dialogue_list_container.highlight_item(index)


func _update_ending_tab_indicator() -> void:
	if _tab_container == null:
		return
	var seq = _sequence_editor_ctrl.get_sequence()
	if seq and seq.ending != null:
		_tab_container.set_tab_title(1, "Terminaison ●")
	else:
		_tab_container.set_tab_title(1, "Terminaison")


func _rebuild_dialogue_list() -> void:
	_dialogue_list_container.setup(_sequence_editor_ctrl)


# --- View management ---

func load_sequence_editors(seq) -> void:
	_visual_editor.load_sequence(seq)
	_dialogue_editor.load_sequence(seq)
	_nav_ctrl.notify_targets_changed()
	_ending_editor.load_sequence(seq)
	_fx_panel.load_sequence(seq)
	_sequence_editor_ctrl.load_sequence(seq)
	_update_ending_tab_indicator()
	_rebuild_dialogue_list()
	_tab_container.current_tab = 0
	
	var is_playing = _play_ctrl.is_story_play_mode()
	_play_button.visible = not is_playing
	_stop_button.visible = false
	_play_overlay.visible = is_playing
	
	if is_playing:
		if _play_overlay.get_parent():
			_play_overlay.get_parent().remove_child(_play_overlay)
		_visual_editor._overlay_container.add_child(_play_overlay)


# --- Play Event Handlers ---

func _on_play_started(mode: String) -> void:
	_enter_fullscreen()
	_play_button.visible = false
	_stop_button.visible = true
	_play_overlay.visible = true
	if _play_overlay.get_parent():
		_play_overlay.get_parent().remove_child(_play_overlay)
	_visual_editor._overlay_container.add_child(_play_overlay)
	_typewriter_timer.start()


func _on_play_stopped() -> void:
	_play_button.visible = true
	_stop_button.visible = false
	_play_overlay.visible = false
	_typewriter_timer.stop()
	if _play_overlay.get_parent():
		_play_overlay.get_parent().remove_child(_play_overlay)
	_exit_fullscreen()


func _on_play_dialogue_changed(character: String, text: String, index: int) -> void:
	_play_character_label.text = character
	_play_text_label.text = text
	_play_text_label.visible_characters = 0


func _on_play_typewriter_tick(visible_chars: int) -> void:
	_play_text_label.visible_characters = visible_chars


func _on_play_choice_requested(choices: Array) -> void:
	_hide_choice_overlay()
	var container = VBoxContainer.new()
	container.name = "ChoiceVBox"
	var title = Label.new()
	title.text = "Faites votre choix"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	container.add_child(title)
	for i in range(choices.size()):
		var btn = Button.new()
		btn.text = choices[i].text
		var idx = i
		btn.pressed.connect(func(): _on_play_choice_selected(idx))
		container.add_child(btn)
	_choice_overlay.add_child(container)
	_choice_overlay.visible = true
	if not _choice_overlay.get_parent():
		_visual_editor._overlay_container.add_child(_choice_overlay)


func _on_play_choice_selected(index: int) -> void:
	_hide_choice_overlay()
	_play_ctrl.on_choice_selected(index)


func _on_play_finished(reason: String) -> void:
	_hide_choice_overlay()
	var messages = {
		"game_over": "Fin de la lecture — Game Over",
		"to_be_continued": "Fin de la lecture — À suivre...",
		"no_ending": "Fin de la lecture (aucune terminaison configurée)",
		"error": "Fin de la lecture — Erreur (cible introuvable ou contenu vide)",
		"stopped": "Lecture arrêtée",
	}
	var dialog = AcceptDialog.new()
	dialog.dialog_text = messages.get(reason, "Fin de la lecture")
	dialog.confirmed.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()


func _on_story_modified() -> void:
	_update_ending_tab_indicator()


func _hide_choice_overlay() -> void:
	_choice_overlay.visible = false
	for child in _choice_overlay.get_children():
		child.queue_free()
	if _choice_overlay.get_parent():
		_choice_overlay.get_parent().remove_child(_choice_overlay)


var _fullscreen_layer: ColorRect = null

func _enter_fullscreen() -> void:
	if _fullscreen_layer:
		return
	_vbox.visible = false
	_fullscreen_layer = ColorRect.new()
	_fullscreen_layer.color = Color(0, 0, 0, 1)
	_fullscreen_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_fullscreen_layer)
	_left_panel.remove_child(_visual_editor)
	_fullscreen_layer.add_child(_visual_editor)
	_visual_editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fs_stop = Button.new()
	fs_stop.text = "■ Stop"
	fs_stop.pressed.connect(_play_ctrl.on_stop_pressed)
	fs_stop.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	fs_stop.offset_left = -80; fs_stop.offset_right = -10; fs_stop.offset_top = 10; fs_stop.offset_bottom = 40
	_fullscreen_layer.add_child(fs_stop)
	call_deferred("_reset_visual_editor")


func _exit_fullscreen() -> void:
	if not _fullscreen_layer:
		return
	_fullscreen_layer.remove_child(_visual_editor)
	_left_panel.add_child(_visual_editor)
	_left_panel.move_child(_visual_editor, 0)
	_visual_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_visual_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_fullscreen_layer.queue_free()
	_fullscreen_layer = null
	_vbox.visible = true
	call_deferred("_reset_visual_editor")


func _reset_visual_editor() -> void:
	_visual_editor.reset_view()


func update_editor_mode() -> void:
	_nav_ctrl.update_editor_mode()


func _on_editor_mode_changed(mode: int, context: Dictionary) -> void:
	# Si le panel de verification est visible, ne pas toucher aux vues (pour l'instant)
	if _verifier_report_panel.visible:
		return
		
	var level = context.get("level", "none")
	
	# Visibilité des panels principaux
	_chapter_graph_view.visible = (mode == EditorState.Mode.CHAPTER_VIEW)
	_scene_graph_view.visible = (mode == EditorState.Mode.SCENE_VIEW)
	_sequence_graph_view.visible = (mode == EditorState.Mode.SEQUENCE_VIEW)
	_sequence_editor_panel.visible = (mode == EditorState.Mode.SEQUENCE_EDIT or mode == EditorState.Mode.PLAY_MODE)
	_condition_editor_panel.visible = (mode == EditorState.Mode.CONDITION_EDIT)
	
	# Barre d'outils et navigation
	_back_button.visible = (mode != EditorState.Mode.CHAPTER_VIEW and mode != EditorState.Mode.NONE)
	_create_button.visible = _editor_main.is_create_button_visible()
	if _create_button.visible:
		_create_button.text = _editor_main.get_create_button_label()
	
	_create_condition_button.visible = (mode == EditorState.Mode.SEQUENCE_VIEW)
	_parametres_menu.visible = (mode in [EditorState.Mode.CHAPTER_VIEW, EditorState.Mode.SCENE_VIEW, EditorState.Mode.SEQUENCE_VIEW])
	
	_breadcrumb.set_current_level(level)
	_breadcrumb.set_path(_editor_main.get_breadcrumb_path())
	
	_top_play_button.visible = (mode in [EditorState.Mode.CHAPTER_VIEW, EditorState.Mode.SCENE_VIEW, EditorState.Mode.SEQUENCE_VIEW])
	_top_stop_button.visible = (mode == EditorState.Mode.PLAY_MODE)
	
	var story_open = (mode != EditorState.Mode.NONE)
	_undo_button.visible = story_open
	_redo_button.visible = story_open
	_refresh_undo_redo_buttons()


func refresh_current_view() -> void:
	var level = _editor_main.get_current_level()
	if level == "chapters":
		_chapter_graph_view.load_story(_editor_main._story)
	elif level == "scenes":
		_scene_graph_view.load_chapter(_editor_main._current_chapter)
	elif level == "sequences":
		_sequence_graph_view.load_scene(_editor_main._current_scene)
	update_editor_mode()


func update_view() -> void:
	update_editor_mode()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.ctrl_pressed and event.keycode == KEY_Z and not event.shift_pressed:
			_on_undo_pressed()
			get_viewport().set_input_as_handled()
		elif event.ctrl_pressed and (event.keycode == KEY_Y or (event.keycode == KEY_Z and event.shift_pressed)):
			_on_redo_pressed()
			get_viewport().set_input_as_handled()


func _on_undo_pressed() -> void:
	_undo_redo.undo()
	refresh_current_view()
	_refresh_undo_redo_buttons()


func _on_redo_pressed() -> void:
	_undo_redo.redo()
	refresh_current_view()
	_refresh_undo_redo_buttons()


func _refresh_undo_redo_buttons() -> void:
	_undo_button.disabled = not _undo_redo.can_undo()
	_redo_button.disabled = not _undo_redo.can_redo()
	if _undo_redo.can_undo():
		_undo_button.tooltip_text = "Annuler : " + _undo_redo.get_undo_label()
	else:
		_undo_button.tooltip_text = ""
	if _undo_redo.can_redo():
		_redo_button.tooltip_text = "Rétablir : " + _undo_redo.get_redo_label()
	else:
		_redo_button.tooltip_text = ""


func _on_histoire_menu_pressed(id: int) -> void:
	match id:
		0: _nav_ctrl.on_new_story_pressed()
		1: _nav_ctrl.on_load_pressed()
		2: _nav_ctrl.on_save_pressed()
		3: _nav_ctrl.on_save_as_pressed()
		4: _on_export_pressed()
		5: _nav_ctrl.on_verify_pressed()
		6: _on_i18n_regenerate_pressed()
		7: _on_i18n_check_pressed()


func _on_languages_pressed() -> void:
	if _editor_main._story == null:
		return
	var base_path = _get_story_base_path()
	if base_path == "":
		var warn = AcceptDialog.new()
		warn.title = "Sauvegarde requise"
		warn.dialog_text = "Veuillez sauvegarder l'histoire avant de gérer les langues."
		warn.confirmed.connect(warn.queue_free)
		add_child(warn)
		warn.popup_centered()
		return
	var dialog = AcceptDialog.new()
	dialog.set_script(LanguageManagerDialogScript)
	dialog.confirmed.connect(dialog.queue_free)
	add_child(dialog)
	dialog.setup(base_path)
	dialog.popup_centered()


func _on_i18n_regenerate_pressed() -> void:
	if _editor_main._story == null:
		return
	var base_path = _get_story_base_path()
	if base_path == "":
		return
	var added = StoryI18nService.regenerate_missing_keys(_editor_main._story, base_path)
	var dialog = AcceptDialog.new()
	dialog.set_script(I18nDialogScript)
	dialog.confirmed.connect(dialog.queue_free)
	add_child(dialog)
	dialog.show_regenerate_result(added)
	dialog.popup_centered()


func _on_i18n_check_pressed() -> void:
	if _editor_main._story == null:
		return
	var base_path = _get_story_base_path()
	if base_path == "":
		return
	var check = StoryI18nService.check_translations(_editor_main._story, base_path)
	var dialog = AcceptDialog.new()
	dialog.set_script(I18nDialogScript)
	dialog.confirmed.connect(dialog.queue_free)
	add_child(dialog)
	dialog.show_check_result(check)
	dialog.popup_centered()


func _on_parametres_menu_pressed(id: int) -> void:
	match id:
		0: _nav_ctrl.on_variables_pressed()
		1: _nav_ctrl.on_menu_config_requested()
		2: _on_gallery_pressed()
		3: _on_notifications_pressed()
		4: _on_languages_pressed()


func _on_notifications_pressed() -> void:
	if _editor_main._story == null:
		return
	var dialog = AcceptDialog.new()
	dialog.set_script(NotificationDialogScript)
	dialog.confirmed.connect(dialog.queue_free)
	add_child(dialog)
	dialog.setup(_editor_main._story)
	dialog.popup_centered()


func _on_notification_triggered(message: String) -> void:
	_toast_label.text = message
	_toast_overlay.visible = true
	_toast_generation += 1
	var gen := _toast_generation
	get_tree().create_timer(3.0).timeout.connect(func():
		if _toast_generation == gen:
			_toast_overlay.visible = false
	)


func _on_gallery_pressed() -> void:
	if _editor_main._story == null:
		return
	var dialog = Window.new()
	dialog.set_script(GalleryDialogScript)
	dialog.close_requested.connect(dialog.queue_free)
	add_child(dialog)
	dialog.setup(_editor_main._story, _get_story_base_path())
	dialog.popup_centered()


func _on_export_pressed() -> void:
	var dialog = ConfirmationDialog.new()
	dialog.set_script(ExportDialogScript)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.setup(_editor_main._story)
	dialog.export_requested.connect(_on_export_requested)
	dialog.popup_centered()


func _on_export_requested(platform: String, output_path: String) -> void:
	if _editor_main._story == null:
		return
	
	var story_path = _get_story_base_path()
	var result = _export_service.export_story(_editor_main._story, platform, output_path, story_path)
	
	if result.success:
		_show_export_result(result.output_path, result.log_path)
	else:
		_show_export_error(result.log_path, result.error_message)


func _show_export_result(output_path: String, log_path: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.title = "Export terminé"
	dialog.dialog_text = "Le jeu a été exporté dans :\n%s\n\nLog : %s" % [output_path, log_path]
	dialog.confirmed.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()


func _show_export_error(log_path: String, reason: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.title = "Erreur d'export"
	dialog.dialog_text = reason + "\n\nLog : " + log_path
	dialog.confirmed.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()
