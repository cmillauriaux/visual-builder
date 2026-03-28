extends Node

## Gère toute la logique de lecture (play) : séquence, story play,
## mode plein écran, typewriter, transitions de foregrounds et choix.

const GameTheme = preload("res://src/ui/themes/game_theme.gd")

# Services et contrôleurs requis
var _main: Control
var _sequence_editor_ctrl: Control
var _story_play_ctrl: Node
var _foreground_transition: Node
var _sequence_fx_player: Node
var _visual_editor: Control
var _music_player: Node = null
var _voice_player: AudioStreamPlayer = null

# État du play
var _previous_play_foregrounds: Array = []
var _seen_fg_uuids: Dictionary = {}
var _is_story_play_mode: bool = false
var _story_play_return_level: String = ""
var _current_playing_sequence = null
var _is_showing_title: bool = false
var _original_seq_foregrounds: Array = []

# Plein écran
var _fullscreen_layer: ColorRect = null


func setup(main: Control) -> void:
	_main = main
	_sequence_editor_ctrl = main._sequence_editor_ctrl
	_story_play_ctrl = main._story_play_ctrl
	_foreground_transition = main._foreground_transition
	_sequence_fx_player = main._sequence_fx_player
	_visual_editor = main._visual_editor
	# Voice player for dialogue voice files
	_voice_player = AudioStreamPlayer.new()
	_voice_player.bus = "Master"
	add_child(_voice_player)


func is_story_play_mode() -> bool:
	return _is_story_play_mode


# --- Sequence Play ---

func on_play_pressed() -> void:
	var _play_ui_path = ""
	var _play_story = _main._editor_main.get_current_story() if _main._editor_main.has_method("get_current_story") else null
	if _play_story != null and _play_story.get("ui_theme_mode") == "custom":
		_play_ui_path = _main._get_story_base_path() + "/assets/ui"
	_apply_play_ui_theme(_main._play_overlay, _main._choice_overlay, _play_ui_path)
	_previous_play_foregrounds = []
	_seen_fg_uuids = {}
	EventBus.play_started.emit("sequence")

	var seq = _sequence_editor_ctrl.get_sequence()
	_current_playing_sequence = seq
	_original_seq_foregrounds = seq.foregrounds.duplicate() if seq else []

	# Nettoyer les transitions précédentes (ex: reste de pixelisation ou fondu)
	_sequence_fx_player.stop_fx()

	# Préparer l'affichage du premier dialogue avant l'animation d'ouverture
	_prepare_opening_visuals()

	# Appliquer les FX persistants immédiatement (visibles dès le début, y compris pendant la transition)
	if seq:
		_sequence_fx_player.apply_persistent_fx(seq.fx, _visual_editor._fx_container)

	if seq and seq.transition_in_type != "none":
		_sequence_fx_player.fx_finished.connect(_on_trans_in_finished_play_fx, CONNECT_ONE_SHOT)
		_sequence_fx_player.play_transition(seq.transition_in_type, seq.transition_in_duration, true, _visual_editor._fx_container)
	else:
		_on_trans_in_finished_play_fx()


func _on_trans_in_finished_play_fx() -> void:
	var seq = _current_playing_sequence
	# play_fx_list filtre automatiquement les FX persistants déjà appliqués
	if seq and seq.fx.size() > 0:
		_sequence_fx_player.fx_finished.connect(_on_play_fx_finished, CONNECT_ONE_SHOT)
		_sequence_fx_player.play_fx_list(seq.fx, _visual_editor._fx_container, _visual_editor._canvas)
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
	_clear_play_ui_theme(_main._play_overlay, _main._choice_overlay)
	_sequence_fx_player.stop_fx()
	_stop_dialogue_voice()
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
	# Ne pas jouer la transition de sortie si l'ending est un choix :
	# le background/foreground doit rester visible derrière les boutons de choix.
	var has_choices_ending = seq != null and seq.ending != null and seq.ending.type == "choices"
	if seq and seq.transition_out_type != "none" and not has_choices_ending:
		_sequence_fx_player.fx_finished.connect(_on_trans_out_finished, CONNECT_ONE_SHOT)
		_sequence_fx_player.play_transition(seq.transition_out_type, seq.transition_out_duration, false, _visual_editor._fx_container)
	else:
		_on_trans_out_finished()


func _on_trans_out_finished() -> void:
	if _is_story_play_mode:
		_story_play_ctrl.on_sequence_finished()
		return
	if _music_player:
		_music_player.stop_music()
	_stop_dialogue_voice()
	_sequence_fx_player.stop_fx()
	_restore_sequence_foregrounds()
	EventBus.play_stopped.emit()


func on_play_dialogue_changed(index: int) -> void:
	var seq = _sequence_editor_ctrl.get_sequence()
	if seq == null or index < 0 or index >= seq.dialogues.size():
		return

	var dlg = seq.dialogues[index]
	EventBus.play_dialogue_changed.emit(dlg.character, dlg.text, index)

	# Play dialogue voice if available
	_play_dialogue_voice(dlg)

	# Foreground transitions logic
	var new_fgs = _sequence_editor_ctrl.get_effective_foregrounds(index)
	var transitions = _foreground_transition.compute_transitions(_previous_play_foregrounds, new_fgs, _seen_fg_uuids)
	for fg in new_fgs:
		_seen_fg_uuids[fg.uuid] = true
	_previous_play_foregrounds = new_fgs

	_apply_visual_transitions(index, transitions)


func _apply_visual_transitions(index: int, transitions: Array) -> void:
	# Phase 1 : Cloner les anciens nœuds AVANT la mise à jour visuelle
	var clones: Array = []  # {clone, action, duration, uuid}
	var morph_data: Array = []  # {old_state, clone_or_null, uuid, duration}
	for t in transitions:
		var action = t["action"]
		if action in ["fade_out", "replace_fade", "replace_instant"]:
			var old_node = _visual_editor.get_foreground_node(t["uuid"])
			if old_node and is_instance_valid(old_node):
				var clone = _create_fade_out_clone(old_node, t.get("z_order", 0))
				if clone:
					clones.append({
						"clone": clone,
						"action": action,
						"duration": t["duration"],
						"uuid": t["uuid"]
					})
		elif action == "morph":
			var old_node = _visual_editor.get_foreground_node(t["old_uuid"])
			if old_node and is_instance_valid(old_node):
				var old_state = {
					"position": old_node.position,
					"size": old_node.size,
					"modulate_a": old_node.modulate.a,
					"flip_h": t.get("old_flip_h", false),
					"flip_v": t.get("old_flip_v", false),
				}
				var clone = null
				if t.get("image_changed", false):
					clone = _create_fade_out_clone(old_node, t.get("old_z_order", 0))
				morph_data.append({
					"old_state": old_state,
					"clone": clone,
					"uuid": t["uuid"],
					"duration": t["duration"],
					"z_order": t["z_order"],
				})

	# Phase 2 : Tuer les tweens précédents puis mettre à jour les visuels
	_visual_editor.kill_all_fg_tweens()
	_main.update_preview_for_dialogue(index)

	# Phase 3 : Positionner les clones et appliquer les transitions
	for entry in clones:
		var clone = entry["clone"]
		var action = entry["action"]
		var duration = entry["duration"]
		var uuid = entry["uuid"]
		var target = _visual_editor.get_foreground_node(uuid)

		if action == "fade_out":
			_foreground_transition.apply_tween_fade_out(clone, duration, true)

		elif action == "replace_fade":
			if target and is_instance_valid(target):
				var parent = clone.get_parent()
				if parent:
					parent.move_child(clone, target.get_index())
				var tween = _foreground_transition.apply_tween_fade_in(target, duration)
				if tween:
					_visual_editor._transitioning_uuids.append(uuid)
					_visual_editor.register_fg_tween(uuid, tween)
					tween.finished.connect(func(): _visual_editor._transitioning_uuids.erase(uuid); _visual_editor._fg_tweens.erase(uuid))
			_foreground_transition.apply_tween_fade_out(clone, duration, true)

		elif action == "replace_instant":
			if target and is_instance_valid(target):
				target.modulate.a = 1.0
			_foreground_transition.apply_tween_fade_out(clone, duration, true)

	# Phase 3b : Appliquer les morphs
	for entry in morph_data:
		var target = _visual_editor.get_foreground_node(entry["uuid"])
		if target == null or not is_instance_valid(target):
			if entry["clone"]:
				entry["clone"].queue_free()
			continue
		target.z_index = entry["z_order"]
		var tween = _foreground_transition.apply_morph(target, entry["old_state"], entry["duration"], entry["clone"])
		if tween:
			var uuid = entry["uuid"]
			_visual_editor._transitioning_uuids.append(uuid)
			_visual_editor.register_fg_tween(uuid, tween)
			tween.finished.connect(func(): _visual_editor._transitioning_uuids.erase(uuid); _visual_editor._fg_tweens.erase(uuid))

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
				_visual_editor.register_fg_tween(uuid, tween)
				tween.finished.connect(func(): _visual_editor._transitioning_uuids.erase(uuid); _visual_editor._fg_tweens.erase(uuid))

	_main.highlight_dialogue_in_list(index)


func _create_fade_out_clone(source: Control, z_order: int = 0) -> TextureRect:
	var fg_container = _visual_editor.get_node_or_null("Canvas/ForegroundContainer")
	if fg_container == null: return null
	var tex_node = source.get_node_or_null("Texture")
	if not tex_node is TextureRect: return null

	var clone = TextureRect.new()
	clone.name = "FadeOutClone"
	clone.texture = tex_node.texture
	clone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	clone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	clone.flip_h = tex_node.flip_h
	clone.flip_v = tex_node.flip_v
	clone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clone.position = source.position
	clone.size = source.size
	clone.modulate = source.modulate
	clone.z_index = z_order
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


func _restore_sequence_foregrounds() -> void:
	var seq = _current_playing_sequence
	if seq:
		seq.foregrounds = _original_seq_foregrounds
		_visual_editor.load_sequence(seq)
		var idx = _sequence_editor_ctrl.get_selected_dialogue_index()
		if idx >= 0:
			_main.update_preview_for_dialogue(idx)


func _stop_dialogue_voice() -> void:
	if _voice_player and _voice_player.playing:
		_voice_player.stop()


func _play_dialogue_voice(dlg) -> void:
	_stop_dialogue_voice()
	if _voice_player == null:
		return
	var voice_path := _get_dialogue_voice_path(dlg)
	if voice_path == "":
		return
	var abs_path := _resolve_voice_path(voice_path)
	if not FileAccess.file_exists(abs_path):
		return
	var bytes := FileAccess.get_file_as_bytes(abs_path)
	if bytes.is_empty():
		return
	var stream := AudioStreamMP3.new()
	stream.data = bytes
	stream.loop = false
	_voice_player.stream = stream
	_voice_player.play()


func _get_dialogue_voice_path(dlg) -> String:
	# Try voice_files dict (new multilang format)
	var voice_files = dlg.get("voice_files")
	if voice_files != null and voice_files is Dictionary and not voice_files.is_empty():
		# Load preferred language from config
		var ELConfig = load("res://plugins/voice_studio/elevenlabs_config.gd")
		if ELConfig:
			var cfg = ELConfig.new()
			cfg.load_from()
			var lang: String = cfg.get_language_code()
			if lang != "" and voice_files.has(lang):
				return voice_files[lang]
		# Fallback: first available language
		for key in voice_files:
			return voice_files[key]
	# Rétro-compat: old voice_file string
	var old_vf = dlg.get("voice_file")
	if old_vf != null and old_vf is String and old_vf != "":
		return old_vf
	return ""


func _resolve_voice_path(rel_path: String) -> String:
	if rel_path.begins_with("/") or rel_path.begins_with("res://") or rel_path.begins_with("user://"):
		return rel_path
	var base_path: String = _main._get_story_base_path() if _main.has_method("_get_story_base_path") else ""
	if base_path != "":
		return base_path + "/" + rel_path
	return rel_path


func _apply_sequence_audio() -> void:
	if _music_player == null or _current_playing_sequence == null:
		return
	_music_player.apply_sequence(_current_playing_sequence, _main._get_story_base_path())


# --- Story Play ---

func on_top_play_pressed() -> void:
	var _play_ui_path = ""
	var _play_story = _main._editor_main.get_current_story() if _main._editor_main.has_method("get_current_story") else null
	if _play_story != null and _play_story.get("ui_theme_mode") == "custom":
		_play_ui_path = _main._get_story_base_path() + "/assets/ui"
	_apply_play_ui_theme(_main._play_overlay, _main._choice_overlay, _play_ui_path)
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
	_restore_sequence_foregrounds()
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
	_seen_fg_uuids = {}
	_current_playing_sequence = seq
	_original_seq_foregrounds = seq.foregrounds.duplicate() if seq else []

	# Nettoyer les transitions précédentes (ex: reste de pixelisation ou fondu)
	_sequence_fx_player.stop_fx()

	# Préparer l'affichage du premier dialogue avant l'animation d'ouverture
	_prepare_opening_visuals()

	# Appliquer les FX persistants immédiatement
	_sequence_fx_player.apply_persistent_fx(seq.fx, _visual_editor._fx_container)

	if seq.transition_in_type != "none":
		_sequence_fx_player.fx_finished.connect(_on_trans_in_finished_play_fx, CONNECT_ONE_SHOT)
		_sequence_fx_player.play_transition(seq.transition_in_type, seq.transition_in_duration, true, _visual_editor._fx_container)
	else:
		_on_trans_in_finished_play_fx()


func on_story_play_choice_requested(choices: Array) -> void:
	EventBus.play_choice_requested.emit(choices)


func on_choice_selected(index: int) -> void:
	_story_play_ctrl.on_choice_selected(index)


func on_story_play_finished(reason: String) -> void:
	if _music_player:
		_music_player.stop_music()
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
	stop_btn.text = tr("Stop")
	stop_btn.visible = true
	_fullscreen_layer.add_child(stop_btn)

	_main._vbox.visible = false


func _exit_play_fullscreen() -> void:
	if _fullscreen_layer == null:
		return
	_main._visual_editor.reparent(_main._sequence_content)
	_main._sequence_content.move_child(_main._visual_editor, 0)
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


# --- UI Theme helpers ---

func _apply_play_ui_theme(play_overlay: PanelContainer, choice_overlay: CenterContainer, story_ui_path: String) -> void:
	var theme = GameTheme.create_theme(story_ui_path)
	play_overlay.theme = theme
	choice_overlay.theme = theme


func _clear_play_ui_theme(play_overlay: PanelContainer, choice_overlay: CenterContainer) -> void:
	play_overlay.theme = null
	choice_overlay.theme = null
