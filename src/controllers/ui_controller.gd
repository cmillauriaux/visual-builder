extends Node

## Gère l'état de l'interface utilisateur (UI) globale : visibilité des panels,
## mise à jour du fil d'Ariane, et rafraîchissement des boutons Undo/Redo.

const EditorState = preload("res://src/controllers/editor_state.gd")

var _main: Control
var _previous_fullscreen_layer: ColorRect = null


func setup(main: Control) -> void:
	_main = main
	EventBus.editor_mode_changed.connect(_on_editor_mode_changed)
	EventBus.play_started.connect(_on_play_started)
	EventBus.play_stopped.connect(_on_play_stopped)
	EventBus.notification_requested.connect(_on_notification_triggered)
	_main._notification_service.message_requested.connect(_on_notification_triggered)


func _on_notification_triggered(message: String) -> void:
	_main._toast_label.text = message
	_main._toast_overlay.visible = true
	_main._toast_generation += 1
	var gen: int = _main._toast_generation
	_main.get_tree().create_timer(3.0).timeout.connect(func():
		if _main._toast_generation == gen:
			_main._toast_overlay.visible = false
	)


func handle_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var cmd_ctrl = event.is_command_or_control_pressed()
		if cmd_ctrl and event.keycode == KEY_Z and not event.shift_pressed:
			_main._on_undo_pressed()
			_main.get_viewport().set_input_as_handled()
		elif cmd_ctrl and (event.keycode == KEY_Y or (event.keycode == KEY_Z and event.shift_pressed)):
			_main._on_redo_pressed()
			_main.get_viewport().set_input_as_handled()
		elif cmd_ctrl and event.keycode == KEY_S and not event.shift_pressed:
			_main._nav_ctrl.on_save_pressed()
			_main.get_viewport().set_input_as_handled()


func _on_editor_mode_changed(mode: int, context: Dictionary) -> void:
	if _main._verifier_report_panel.visible:
		return
		
	var level = context.get("level", "none")
	
	# Visibilité des panels principaux
	_main._chapter_graph_view.visible = (mode == EditorState.Mode.CHAPTER_VIEW)
	_main._scene_graph_view.visible = (mode == EditorState.Mode.SCENE_VIEW)
	_main._sequence_graph_view.visible = (mode == EditorState.Mode.SEQUENCE_VIEW)
	_main._sequence_editor_panel.visible = (mode == EditorState.Mode.SEQUENCE_EDIT or mode == EditorState.Mode.PLAY_MODE)
	_main._condition_editor_panel.visible = (mode == EditorState.Mode.CONDITION_EDIT)
	_main._map_view.visible = (mode == EditorState.Mode.MAP_VIEW)
	_main._welcome_screen.visible = (mode == EditorState.Mode.NONE)
	_main._top_bar_panel.visible = (mode != EditorState.Mode.NONE)
	
	# Barre d'outils et navigation
	_main._back_button.visible = (mode != EditorState.Mode.CHAPTER_VIEW and mode != EditorState.Mode.NONE)
	_main._create_button.visible = _main._editor_main.is_create_button_visible()
	if _main._create_button.visible:
		_main._create_button.text = _main._editor_main.get_create_button_label()
	
	_main._create_condition_button.visible = (mode == EditorState.Mode.SEQUENCE_VIEW)
	_main._parametres_menu.visible = (mode in [EditorState.Mode.CHAPTER_VIEW, EditorState.Mode.SCENE_VIEW, EditorState.Mode.SEQUENCE_VIEW])
	_main._histoire_menu.visible = (mode != EditorState.Mode.NONE)
	
	_main._breadcrumb.set_current_level(level)
	_main._breadcrumb.set_path(_main._editor_main.get_breadcrumb_path())
	_main._breadcrumb.visible = (mode != EditorState.Mode.NONE)
	
	_main._map_button.visible = (mode != EditorState.Mode.NONE)
	_main._map_button.button_pressed = (mode == EditorState.Mode.MAP_VIEW)
	var show_play := mode in [EditorState.Mode.CHAPTER_VIEW, EditorState.Mode.SCENE_VIEW, EditorState.Mode.SEQUENCE_VIEW]
	_main._top_play_button.visible = show_play
	_main._play_lang_selector.visible = show_play or (mode == EditorState.Mode.PLAY_MODE)
	_main._top_stop_button.visible = (mode == EditorState.Mode.PLAY_MODE)
	
	var story_open = (mode != EditorState.Mode.NONE)
	_main._undo_button.visible = story_open
	_main._redo_button.visible = story_open
	refresh_undo_redo_buttons()


func refresh_undo_redo_buttons() -> void:
	if _main._undo_redo == null:
		return
	_main._undo_button.disabled = not _main._undo_redo.can_undo()
	_main._redo_button.disabled = not _main._undo_redo.can_redo()
	
	var cmd_ctrl = "Cmd" if OS.get_name() == "macOS" else "Ctrl"
	
	if _main._undo_redo.can_undo():
		_main._undo_button.tooltip_text = tr("Annuler : %s (%s+Z)") % [_main._undo_redo.get_undo_label(), cmd_ctrl]
	else:
		_main._undo_button.tooltip_text = ""
		
	if _main._undo_redo.can_redo():
		_main._redo_button.tooltip_text = tr("Rétablir : %s (%s+Y / %s+Maj+Z)") % [_main._undo_redo.get_redo_label(), cmd_ctrl, cmd_ctrl]
	else:
		_main._redo_button.tooltip_text = ""


func _on_play_started(_mode: String) -> void:
	enter_fullscreen()


func _on_play_stopped() -> void:
	exit_fullscreen()


func enter_fullscreen() -> void:
	if _previous_fullscreen_layer:
		return
	_main._vbox.visible = false
	_previous_fullscreen_layer = ColorRect.new()
	_previous_fullscreen_layer.color = Color(0, 0, 0, 1)
	_previous_fullscreen_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_main.add_child(_previous_fullscreen_layer)

	_main._sequence_content.remove_child(_main._visual_editor)
	_previous_fullscreen_layer.add_child(_main._visual_editor)
	_main._visual_editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Ajouter le play overlay au conteneur de superposition du visual editor
	if _main._play_overlay.get_parent():
		_main._play_overlay.get_parent().remove_child(_main._play_overlay)
	_main._visual_editor._overlay_container.add_child(_main._play_overlay)
	_main._play_overlay.visible = true

	var fs_stop = Button.new()
	fs_stop.text = tr("■ Stop")
	fs_stop.pressed.connect(_main._play_ctrl.on_stop_pressed)
	fs_stop.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	fs_stop.offset_left = -80; fs_stop.offset_right = -10; fs_stop.offset_top = 10; fs_stop.offset_bottom = 40
	_previous_fullscreen_layer.add_child(fs_stop)
	_main.call_deferred("_reset_visual_editor")


func exit_fullscreen() -> void:
	if not _previous_fullscreen_layer:
		return
	# Retirer le play overlay du visual editor
	_main._play_overlay.visible = false
	if _main._play_overlay.get_parent():
		_main._play_overlay.get_parent().remove_child(_main._play_overlay)

	_previous_fullscreen_layer.remove_child(_main._visual_editor)
	_main._sequence_content.add_child(_main._visual_editor)
	_main._sequence_content.move_child(_main._visual_editor, 0)
	_main._visual_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_main._visual_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_previous_fullscreen_layer.queue_free()
	_previous_fullscreen_layer = null
	_main._vbox.visible = true
	_main.call_deferred("_reset_visual_editor")
