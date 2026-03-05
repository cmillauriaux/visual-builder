extends Node

## Gère toute la logique de lecture (play) : séquence, story play,
## mode plein écran, typewriter, transitions de foregrounds et choix.

# Services et contrôleurs requis
var _main: Control
var _sequence_editor_ctrl: Control
var _story_play_ctrl: Node
var _foreground_transition: Node
var _sequence_fx_player: Node
var _visual_editor: Control
var _music_player: Node = null

# État du play
var _previous_play_foregrounds: Array = []
var _is_story_play_mode: bool = false
var _story_play_return_level: String = ""
var _current_playing_sequence = null
var _is_showing_title: bool = false

# Plein écran
var _fullscreen_layer: ColorRect = null


func setup(main: Control) -> void:
	_main = main
	_sequence_editor_ctrl = main._sequence_editor_ctrl
	_story_play_ctrl = main._story_play_ctrl
	_foreground_transition = main._foreground_transition
	_sequence_fx_player = main._sequence_fx_player
	_visual_editor = main._visual_editor


func is_story_play_mode() -> bool:
	return _is_story_play_mode


# --- Sequence Play ---

func on_play_pressed() -> void:
	_previous_play_foregrounds = []
	EventBus.play_started.emit("sequence")

	var seq = _sequence_editor_ctrl.get_sequence()
	_current_playing_sequence = seq

	# Nettoyer les transitions précédentes (ex: reste de pixelisation ou fondu)
	_sequence_fx_player.stop_fx()

	# Préparer l'affichage du premier dialogue avant l'animation d'ouverture
	_prepare_opening_visuals()

	if seq and seq.transition_in_type != "none":
		_sequence_fx_player.fx_finished.connect(_on_trans_in_finished_play_fx, CONNECT_ONE_SHOT)
		_sequence_fx_player.play_transition(seq.transition_in_type, seq.transition_in_duration, true, _visual_editor)
	else:
		_on_trans_in_finished_play_fx()


func _on_trans_in_finished_play_fx() -> void:
	var seq = _current_playing_sequence
	if seq and seq.fx.size() > 0:
		_sequence_fx_player.fx_finished.connect(_on_play_fx_finished, CONNECT_ONE_SHOT)
		_sequence_fx_player.play_fx_list(seq.fx, _visual_editor)
	else:
		_apply_sequence_audio()
		_start_play_after_fx()


func _start_play_after_fx() -> void:
	var seq = _current_playing_sequence
	if seq and (seq.title != "" or seq.subtitle != ""):
		_show_title_screen(seq)
	else:
		_start_sequence_actually()


func _start_sequence_actually() -> void:
	_sequence_editor_ctrl.start_play()
	if not _sequence_editor_ctrl.is_playing():
		_handle_play_stopped()


func _show_title_screen(seq) -> void:
	_is_showing_title = true
	_main._play_title_label.text = seq.title
	_main._play_subtitle_label.text = seq.subtitle
	_main._play_title_overlay.visible = true
	_main._play_overlay.visible = false # Cacher le container de dialogue
	if not _main._play_title_overlay.get_parent():
		_visual_editor._overlay_container.add_child(_main._play_title_overlay)


func _hide_title_screen() -> void:
	_is_showing_title = false
	_main._play_title_overlay.visible = false
	_main._play_overlay.visible = true # Réafficher le container de dialogue
	if _main._play_title_overlay.get_parent():
		_main._play_title_overlay.get_parent().remove_child(_main._play_title_overlay)
	_start_sequence_actually()


func _on_play_fx_finished() -> void:
	_apply_sequence_audio()
	_start_play_after_fx()


func on_stop_pressed() -> void:
	_sequence_fx_player.stop_fx()
	if _music_player:
		_music_player.stop_music()
	if _is_story_play_mode:
		_stop_story_play()
		return
	_sequence_editor_ctrl.stop_play()


func on_play_stopped() -> void:
	_handle_play_stopped()


func _handle_play_stopped() -> void:
	var seq = _current_playing_sequence
	if seq and seq.transition_out_type != "none":
		_sequence_fx_player.fx_finished.connect(_on_trans_out_finished, CONNECT_ONE_SHOT)
		_sequence_fx_player.play_transition(seq.transition_out_type, seq.transition_out_duration, false, _visual_editor)
	else:
		_on_trans_out_finished()


func _on_trans_out_finished() -> void:
	if _is_story_play_mode:
		_story_play_ctrl.on_sequence_finished()
		return
	EventBus.play_stopped.emit()


func on_play_dialogue_changed(index: int) -> void:
	var seq = _sequence_editor_ctrl.get_sequence()
	if seq == null or index < 0 or index >= seq.dialogues.size():
		return
	
	var dlg = seq.dialogues[index]
	EventBus.play_dialogue_changed.emit(dlg.character, dlg.text, index)
	
	# Foreground transitions logic
	var new_fgs = _sequence_editor_ctrl.get_effective_foregrounds(index)
	var transitions = _foreground_transition.compute_transitions(_previous_play_foregrounds, new_fgs)
	_previous_play_foregrounds = new_fgs

	# On notifie le visuel pour qu'il gère ses tweens/clones
	# Note: On pourrait aussi émettre un signal "play_transitions_requested"
	# Mais pour l'instant on garde l'appel direct au visual_editor car c'est de l'UI pure
	_apply_visual_transitions(index, transitions)


func _apply_visual_transitions(index: int, transitions: Array) -> void:
	# Phase 1 : Cloner les anciens nœuds AVANT la mise à jour visuelle
	var clones: Array = []  # {clone, action, duration, uuid}
	for t in transitions:
		var action = t["action"]
		if action in ["fade_out", "replace_fade", "replace_instant"]:
			var old_node = _visual_editor.get_foreground_node(t["uuid"])
			if old_node and is_instance_valid(old_node):
				var clone = _create_fade_out_clone(old_node)
				if clone:
					clones.append({
						"clone": clone,
						"action": action,
						"duration": t["duration"],
						"uuid": t["uuid"]
					})

	# Phase 2 : Mettre à jour les visuels (nouvel état)
	_main.update_preview_for_dialogue(index)

	# Phase 3 : Positionner les clones et appliquer les transitions
	for entry in clones:
		var clone = entry["clone"]
		var action = entry["action"]
		var duration = entry["duration"]
		var uuid = entry["uuid"]
		var target = _visual_editor.get_foreground_node(uuid)

		if action == "fade_out":
			# Disparition pure : clone en haut, fade out
			if clone.get_parent():
				clone.get_parent().move_child(clone, clone.get_parent().get_child_count() - 1)
			_foreground_transition.apply_tween_fade_out(clone, duration, true)

		elif action == "replace_fade":
			# Nouveau par-dessus : clone sous le target, nouveau fade in
			if target and is_instance_valid(target):
				var parent = clone.get_parent()
				if parent:
					parent.move_child(clone, target.get_index())
				var tween = _foreground_transition.apply_tween_fade_in(target, duration)
				if tween:
					_visual_editor._transitioning_uuids.append(uuid)
					tween.finished.connect(func(): _visual_editor._transitioning_uuids.erase(uuid))
			_foreground_transition.apply_tween_fade_out(clone, duration, true)

		elif action == "replace_instant":
			# Ancien par-dessus : clone au-dessus du target, nouveau instantané
			if target and is_instance_valid(target):
				target.modulate.a = 1.0
				var parent = clone.get_parent()
				if parent:
					parent.move_child(clone, parent.get_child_count() - 1)
			_foreground_transition.apply_tween_fade_out(clone, duration, true)

	# Phase 4 : fade_in pur (nouveau FG sans prédécesseur)
	for t in transitions:
		if t["action"] == "fade_in":
			var target = _visual_editor.get_foreground_node(t["uuid"])
			if target == null:
				continue
			var tween = _foreground_transition.apply_tween_fade_in(target, t["duration"])
			if tween:
				var uuid = t["uuid"]
				_visual_editor._transitioning_uuids.append(uuid)
				tween.finished.connect(func(): _visual_editor._transitioning_uuids.erase(uuid))

	_main.highlight_dialogue_in_list(index)


func _create_fade_out_clone(source: Control) -> TextureRect:
	var fg_container = _visual_editor.get_node_or_null("Canvas/ForegroundContainer")
	if fg_container == null: return null
	var tex_node = source.get_node_or_null("Texture")
	if not tex_node is TextureRect: return null
	
	var clone = TextureRect.new()
	clone.name = "FadeOutClone"
	clone.texture = tex_node.texture
	clone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	clone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	clone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clone.position = source.position
	clone.size = source.size
	clone.modulate = source.modulate
	fg_container.add_child(clone)
	return clone


func _prepare_opening_visuals() -> void:
	# Pendant l'animation d'ouverture, afficher uniquement le background et
	# les foregrounds du premier dialogue qui n'ont pas d'animation propre.
	var seq = _sequence_editor_ctrl.get_sequence()
	if seq == null or seq.dialogues.is_empty():
		return
	var fgs = _sequence_editor_ctrl.get_effective_foregrounds(0)
	var static_fgs: Array = []
	for fg in fgs:
		if fg.transition_type == "none":
			static_fgs.append(fg)
	seq.foregrounds = static_fgs
	_visual_editor.load_sequence(seq)
	_previous_play_foregrounds = static_fgs


func _apply_sequence_audio() -> void:
	if _music_player == null or _current_playing_sequence == null:
		return
	_music_player.apply_sequence(_current_playing_sequence, _main._get_story_base_path())


# --- Story Play ---

func on_top_play_pressed() -> void:
	var level = _main._editor_main.get_current_level()
	_story_play_return_level = level
	_is_story_play_mode = true
	EventBus.play_started.emit("story")
	
	if level == "chapters":
		_story_play_ctrl.start_play_story(_main._editor_main._story)
	elif level == "scenes":
		_story_play_ctrl.start_play_chapter(_main._editor_main._story, _main._editor_main._current_chapter)
	elif level == "sequences":
		_story_play_ctrl.start_play_scene(_main._editor_main._story, _main._editor_main._current_chapter, _main._editor_main._current_scene)


func on_top_stop_pressed() -> void:
	_stop_story_play()


func _stop_story_play() -> void:
	if _music_player:
		_music_player.stop_music()
	_is_showing_title = false
	_main._play_title_overlay.visible = false
	if _main._play_title_overlay.get_parent():
		_main._play_title_overlay.get_parent().remove_child(_main._play_title_overlay)

	_sequence_fx_player.stop_fx()
	if _sequence_editor_ctrl.is_playing():
		_is_story_play_mode = false
		_sequence_editor_ctrl.stop_play()
	else:
		_story_play_ctrl.stop_play()
	EventBus.play_stopped.emit()
	_restore_after_story_play()


func on_story_play_sequence_requested(seq) -> void:
	var ctrl_chapter = _story_play_ctrl.get_current_chapter()
	var ctrl_scene = _story_play_ctrl.get_current_scene()
	if ctrl_chapter and _main._editor_main._current_chapter != ctrl_chapter:
		_main._editor_main._current_chapter = ctrl_chapter
		_main._editor_main._current_level = "scenes"
	if ctrl_scene and _main._editor_main._current_scene != ctrl_scene:
		_main._editor_main._current_scene = ctrl_scene
		_main._editor_main._current_level = "sequences"
	
	_main._editor_main.navigate_to_sequence(seq.uuid)
	if _main._editor_main._current_sequence:
		_main.load_sequence_editors(_main._editor_main._current_sequence)
	
	_main.update_editor_mode()
	_previous_play_foregrounds = []
	_current_playing_sequence = seq

	# Nettoyer les transitions précédentes (ex: reste de pixelisation ou fondu)
	_sequence_fx_player.stop_fx()

	# Préparer l'affichage du premier dialogue avant l'animation d'ouverture
	_prepare_opening_visuals()

	if seq.transition_in_type != "none":
		_sequence_fx_player.fx_finished.connect(_on_trans_in_finished_play_fx, CONNECT_ONE_SHOT)
		_sequence_fx_player.play_transition(seq.transition_in_type, seq.transition_in_duration, true, _visual_editor)
	else:
		_on_trans_in_finished_play_fx()


func on_story_play_choice_requested(choices: Array) -> void:
	EventBus.play_choice_requested.emit(choices)


func on_choice_selected(index: int) -> void:
	_story_play_ctrl.on_choice_selected(index)


func on_story_play_finished(reason: String) -> void:
	EventBus.play_finished.emit(reason)
	_restore_after_story_play()


func _restore_after_story_play() -> void:
	_is_story_play_mode = false
	while _main._editor_main.get_current_level() != _story_play_return_level and _main._editor_main.get_current_level() != "none":
		_main._editor_main.navigate_back()
	_main.refresh_current_view()


# --- Plein écran ---

func _enter_play_fullscreen() -> void:
	_fullscreen_layer = ColorRect.new()
	_fullscreen_layer.color = Color(0, 0, 0, 1)
	_fullscreen_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_main.get_viewport().add_child(_fullscreen_layer)

	_main._visual_editor.reparent(_fullscreen_layer)

	var stop_btn = Button.new()
	stop_btn.name = "FullscreenStopButton"
	stop_btn.text = "Stop"
	stop_btn.visible = true
	_fullscreen_layer.add_child(stop_btn)

	_main._vbox.visible = false


func _exit_play_fullscreen() -> void:
	if _fullscreen_layer == null:
		return
	_main._visual_editor.reparent(_main._left_panel)
	_main._vbox.visible = true
	_fullscreen_layer.queue_free()
	_fullscreen_layer = null


# --- Typewriter & Input ---

func on_typewriter_tick() -> void:
	if not _sequence_editor_ctrl.is_playing():
		return
	_sequence_editor_ctrl.advance_typewriter()
	EventBus.play_typewriter_tick.emit(_sequence_editor_ctrl.get_visible_characters())


func _input(event: InputEvent) -> void:
	if _is_showing_title:
		if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
			_hide_title_screen()
			get_viewport().set_input_as_handled()
		return

	if not _sequence_editor_ctrl.is_playing():
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		if not _sequence_editor_ctrl.is_text_fully_displayed():
			_sequence_editor_ctrl.skip_typewriter()
		else:
			_sequence_editor_ctrl.advance_play()
		get_viewport().set_input_as_handled()
