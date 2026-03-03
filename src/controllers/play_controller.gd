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

# État du play
var _previous_play_foregrounds: Array = []
var _is_story_play_mode: bool = false
var _story_play_return_level: String = ""
var _current_playing_sequence = null


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
	
	if seq and seq.transition_in_type != "none":
		_sequence_fx_player.fx_finished.connect(_on_trans_in_finished_play_fx, CONNECT_ONE_SHOT)
		_sequence_fx_player.play_transition(seq.transition_in_type, seq.transition_in_duration, true, _visual_editor)
	else:
		_on_trans_in_finished_play_fx()


func _on_trans_in_finished_play_fx() -> void:
	var seq = _current_playing_sequence
	if seq and seq.fx.size() > 0:
		_sequence_fx_player.fx_finished.connect(_on_fx_finished_start_play, CONNECT_ONE_SHOT)
		_sequence_fx_player.play_fx_list(seq.fx, _visual_editor)
	else:
		_start_play_after_fx()


func _start_play_after_fx() -> void:
	_sequence_editor_ctrl.start_play()
	if not _sequence_editor_ctrl.is_playing():
		_handle_play_stopped()


func _on_fx_finished_start_play() -> void:
	_start_play_after_fx()


func on_stop_pressed() -> void:
	_sequence_fx_player.stop_fx()
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
	# Déterminer s'il y a un remplacement
	var has_fade_out := false
	var has_fade_in := false
	var fade_in_duration := 0.5
	for t in transitions:
		if t["action"] == "fade_out": has_fade_out = true
		if t["action"] in ["fade_in", "crossfade"]:
			has_fade_in = true
			fade_in_duration = maxf(fade_in_duration, t["duration"])
	var is_replacement := has_fade_out and has_fade_in

	var fade_out_clones: Array = []
	for t in transitions:
		if t["action"] == "fade_out":
			var old_node = _visual_editor.get_foreground_node(t["uuid"])
			if old_node and is_instance_valid(old_node):
				var clone = _create_fade_out_clone(old_node)
				if clone: fade_out_clones.append(clone)

	_main.update_preview_for_dialogue(index)

	for clone in fade_out_clones:
		if clone.get_parent():
			clone.get_parent().move_child(clone, clone.get_parent().get_child_count() - 1)

	for t in transitions:
		if t["action"] in ["fade_in", "crossfade"]:
			var target = _visual_editor.get_foreground_node(t["uuid"])
			if target == null: continue
			if is_replacement:
				target.modulate.a = 1.0
			else:
				var tween = _foreground_transition.apply_tween_fade_in(target, t["duration"])
				if tween:
					var uuid = t["uuid"]
					_visual_editor._transitioning_uuids.append(uuid)
					tween.finished.connect(func(): _visual_editor._transitioning_uuids.erase(uuid))

	var fo_duration = fade_in_duration if is_replacement else 0.5
	for clone in fade_out_clones:
		_foreground_transition.apply_tween_fade_out(clone, fo_duration, true)

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
	
	if seq.transition_in_type != "none":
		_sequence_fx_player.fx_finished.connect(_on_story_trans_in_finished_play_fx, CONNECT_ONE_SHOT)
		_sequence_fx_player.play_transition(seq.transition_in_type, seq.transition_in_duration, true, _visual_editor)
	else:
		_on_story_trans_in_finished_play_fx()


func _on_story_trans_in_finished_play_fx() -> void:
	var seq = _current_playing_sequence
	if seq and seq.fx.size() > 0:
		_sequence_fx_player.fx_finished.connect(_on_story_fx_finished_start_play, CONNECT_ONE_SHOT)
		_sequence_fx_player.play_fx_list(seq.fx, _visual_editor)
	else:
		_start_story_sequence_play()


func _start_story_sequence_play() -> void:
	_sequence_editor_ctrl.start_play()
	if not _sequence_editor_ctrl.is_playing():
		_story_play_ctrl.on_sequence_finished()


func _on_story_fx_finished_start_play() -> void:
	_start_story_sequence_play()


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


# --- Typewriter & Input ---

func on_typewriter_tick() -> void:
	if not _sequence_editor_ctrl.is_playing():
		return
	_sequence_editor_ctrl.advance_typewriter()
	EventBus.play_typewriter_tick.emit(_sequence_editor_ctrl.get_visible_characters())


func _input(event: InputEvent) -> void:
	if not _sequence_editor_ctrl.is_playing():
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		if not _sequence_editor_ctrl.is_text_fully_displayed():
			_sequence_editor_ctrl.skip_typewriter()
		else:
			_sequence_editor_ctrl.advance_play()
		get_viewport().set_input_as_handled()
