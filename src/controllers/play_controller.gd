extends Node

## Gère toute la logique de lecture (play) : séquence, story play,
## mode plein écran, typewriter, transitions de foregrounds et choix.

var _main: Control

# État du play
var _previous_play_foregrounds: Array = []
var _is_play_fullscreen: bool = false
var _fullscreen_layer: ColorRect = null
var _is_story_play_mode: bool = false
var _story_play_return_level: String = ""


func setup(main: Control) -> void:
	_main = main


func is_story_play_mode() -> bool:
	return _is_story_play_mode


# --- Sequence Play ---

func on_play_pressed() -> void:
	_previous_play_foregrounds = []
	_enter_play_fullscreen()
	_main._sequence_editor_ctrl.start_play()
	if _main._sequence_editor_ctrl.is_playing():
		_main._play_button.visible = false
		_main._stop_button.visible = true
		_main._play_overlay.visible = true
		_main._visual_editor._overlay_container.add_child(_main._play_overlay)
		_main._typewriter_timer.start()
	else:
		_exit_play_fullscreen()


func on_stop_pressed() -> void:
	if _is_story_play_mode:
		_stop_story_play()
		return
	_main._sequence_editor_ctrl.stop_play()


func on_play_stopped() -> void:
	_main._play_button.visible = true
	_main._stop_button.visible = false
	_main._play_overlay.visible = false
	_main._typewriter_timer.stop()
	if _main._play_overlay.get_parent():
		_main._play_overlay.get_parent().remove_child(_main._play_overlay)
	if _is_story_play_mode:
		_main._story_play_ctrl.on_sequence_finished()
		return
	_exit_play_fullscreen()


func on_play_dialogue_changed(index: int) -> void:
	var seq = _main._sequence_editor_ctrl.get_sequence()
	if seq == null or index < 0 or index >= seq.dialogues.size():
		return
	var dlg = seq.dialogues[index]
	_main._play_character_label.text = dlg.character
	_main._play_text_label.text = dlg.text
	_main._play_text_label.visible_characters = 0
	# Compute foreground transitions
	var new_fgs = _main._sequence_editor_ctrl.get_effective_foregrounds(index)
	var transitions = _main._foreground_transition.compute_transitions(_previous_play_foregrounds, new_fgs)
	print("[TRANSITION] === Dialogue %d ===" % index)
	for t in transitions:
		print("[TRANSITION]   action=%s uuid=%s duration=%s" % [t["action"], t["uuid"], t.get("duration", "?")])
	_previous_play_foregrounds = new_fgs

	# Déterminer s'il y a un remplacement (fade_out + fade_in simultanés = crossfade)
	var has_fade_out := false
	var has_fade_in := false
	var fade_in_duration := 0.5
	for t in transitions:
		if t["action"] == "fade_out":
			has_fade_out = true
		if t["action"] == "fade_in" or t["action"] == "crossfade":
			has_fade_in = true
			fade_in_duration = maxf(fade_in_duration, t["duration"])
	var is_replacement := has_fade_out and has_fade_in
	print("[TRANSITION]   is_replacement=%s fade_in_duration=%s" % [is_replacement, fade_in_duration])

	# AVANT de mettre à jour les visuels :
	# Créer des clones des anciens noeuds pour les fade_out (car _update_preview va les détruire)
	var fade_out_clones: Array = []
	for t in transitions:
		if t["action"] == "fade_out":
			var old_node = _main._visual_editor.get_foreground_node(t["uuid"])
			if old_node and is_instance_valid(old_node):
				var clone = _create_fade_out_clone(old_node)
				if clone:
					fade_out_clones.append(clone)
					print("[TRANSITION]   clone created for fade_out uuid=%s" % t["uuid"])

	# Mettre à jour les visuels (détruit anciens noeuds, crée nouveaux)
	_main.update_preview_for_dialogue(index)

	# Replacer les clones AU-DESSUS des nouveaux noeuds (ils ont été créés avant)
	for clone in fade_out_clones:
		var p = clone.get_parent()
		if p:
			p.move_child(clone, p.get_child_count() - 1)
			print("[TRANSITION]   clone moved to top: %s index=%d" % [clone, clone.get_index()])

	# Appliquer les transitions sur les nouveaux noeuds
	for t in transitions:
		if t["action"] == "fade_in" or t["action"] == "crossfade":
			var target = _main._visual_editor.get_foreground_node(t["uuid"])
			if target == null:
				print("[TRANSITION]   target NULL for uuid=%s" % t["uuid"])
				continue
			if is_replacement:
				# Remplacement : nouvelle image à pleine opacité immédiatement,
				# le clone de l'ancienne par-dessus va fade out
				target.modulate.a = 1.0
				print("[TRANSITION]   replacement: new node at full opacity uuid=%s" % t["uuid"])
			else:
				# Pas de remplacement : fade_in normal
				var tween = _main._foreground_transition.apply_tween_fade_in(target, t["duration"])
				print("[TRANSITION]   fade_in STARTED uuid=%s duration=%s" % [t["uuid"], t["duration"]])
				if tween:
					var uuid = t["uuid"]
					_main._visual_editor._transitioning_uuids.append(uuid)
					tween.finished.connect(func(): print("[TRANSITION]   fade_in FINISHED uuid=%s" % uuid); _main._visual_editor._transitioning_uuids.erase(uuid))

	# Appliquer les fade_out sur les clones
	var fo_duration = fade_in_duration if is_replacement else 0.5
	for clone in fade_out_clones:
		print("[TRANSITION]   fade_out STARTED clone=%s duration=%s" % [clone, fo_duration])
		var fo_tween = _main._foreground_transition.apply_tween_fade_out(clone, fo_duration, true)
		if fo_tween:
			var c = clone
			fo_tween.finished.connect(func(): print("[TRANSITION]   fade_out FINISHED clone=%s" % c))

	# Highlight in list
	_main.highlight_dialogue_in_list(index)


## Crée un clone visuel d'un noeud foreground pour pouvoir l'animer en fade_out
## même après que l'original soit détruit par update_preview_for_dialogue.
func _create_fade_out_clone(source: Control) -> TextureRect:
	var fg_container = _main._visual_editor.get_node_or_null("Canvas/ForegroundContainer")
	if fg_container == null:
		return null
	var tex_node = source.get_node_or_null("Texture")
	if tex_node == null or not tex_node is TextureRect:
		return null
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
	_main._top_play_button.visible = false
	_main._top_stop_button.visible = true
	if level == "chapters":
		_main._story_play_ctrl.start_play_story(_main._editor_main._story)
	elif level == "scenes":
		_main._story_play_ctrl.start_play_chapter(_main._editor_main._story, _main._editor_main._current_chapter)
	elif level == "sequences":
		_main._story_play_ctrl.start_play_scene(_main._editor_main._story, _main._editor_main._current_chapter, _main._editor_main._current_scene)


func on_top_stop_pressed() -> void:
	_stop_story_play()


func _stop_story_play() -> void:
	if _main._sequence_editor_ctrl.is_playing():
		_is_story_play_mode = false
		_main._sequence_editor_ctrl.stop_play()
	else:
		_main._story_play_ctrl.stop_play()
	_hide_choice_overlay()
	_restore_after_story_play()


func on_story_play_sequence_requested(seq) -> void:
	# Ensure the editor_main navigation state matches the controller's current chapter/scene
	var ctrl_chapter = _main._story_play_ctrl.get_current_chapter()
	var ctrl_scene = _main._story_play_ctrl.get_current_scene()
	if ctrl_chapter and _main._editor_main._current_chapter != ctrl_chapter:
		_main._editor_main._current_chapter = ctrl_chapter
		_main._editor_main._current_level = "scenes"
	if ctrl_scene and _main._editor_main._current_scene != ctrl_scene:
		_main._editor_main._current_scene = ctrl_scene
		_main._editor_main._current_level = "sequences"
	_main._editor_main.navigate_to_sequence(seq.uuid)
	if _main._editor_main._current_sequence:
		_main.load_sequence_editors(_main._editor_main._current_sequence)
	_main.update_view()
	_main._sequence_editor_panel.visible = true
	# Hide graph views during story play
	_main._chapter_graph_view.visible = false
	_main._scene_graph_view.visible = false
	_main._sequence_graph_view.visible = false
	# Enter fullscreen for play
	_enter_play_fullscreen()
	# Start sequence play
	_previous_play_foregrounds = []
	_main._sequence_editor_ctrl.start_play()
	if _main._sequence_editor_ctrl.is_playing():
		_main._play_button.visible = false
		_main._stop_button.visible = true
		_main._play_overlay.visible = true
		_main._visual_editor._overlay_container.add_child(_main._play_overlay)
		_main._typewriter_timer.start()
	else:
		# Sequence has no dialogues — treat as immediate finish
		_exit_play_fullscreen()
		_main._story_play_ctrl.on_sequence_finished()


func on_story_play_choice_requested(choices) -> void:
	_hide_choice_overlay()
	var vbox = VBoxContainer.new()
	vbox.name = "ChoiceVBox"
	var title_label = Label.new()
	title_label.text = "Faites votre choix"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title_label)
	for i in range(choices.size()):
		var btn = Button.new()
		btn.text = choices[i].text
		var idx = i
		btn.pressed.connect(func(): _on_play_choice_selected(idx))
		vbox.add_child(btn)
	_main._choice_overlay.add_child(vbox)
	_main._choice_overlay.visible = true
	if not _main._choice_overlay.get_parent():
		_main._visual_editor._overlay_container.add_child(_main._choice_overlay)


func _on_play_choice_selected(index: int) -> void:
	_hide_choice_overlay()
	_main._story_play_ctrl.on_choice_selected(index)


func _hide_choice_overlay() -> void:
	_main._choice_overlay.visible = false
	for child in _main._choice_overlay.get_children():
		child.queue_free()
	if _main._choice_overlay.get_parent():
		_main._choice_overlay.get_parent().remove_child(_main._choice_overlay)


func on_story_play_finished(reason: String) -> void:
	_hide_choice_overlay()
	_restore_after_story_play()
	# Show end message
	var messages = {
		"game_over": "Fin de la lecture — Game Over",
		"to_be_continued": "Fin de la lecture — À suivre...",
		"no_ending": "Fin de la lecture (aucune terminaison configurée)",
		"error": "Fin de la lecture — Erreur (cible introuvable ou contenu vide)",
		"stopped": "Lecture arrêtée",
	}
	var msg = messages.get(reason, "Fin de la lecture")
	var dialog = AcceptDialog.new()
	dialog.dialog_text = msg
	_main.add_child(dialog)
	dialog.popup_centered()


func _restore_after_story_play() -> void:
	_is_story_play_mode = false
	_main._top_play_button.visible = false
	_main._top_stop_button.visible = false
	_exit_play_fullscreen()
	# Navigate back to the return level
	while _main._editor_main.get_current_level() != _story_play_return_level and _main._editor_main.get_current_level() != "none":
		_main._editor_main.navigate_back()
	_main.refresh_current_view()


# --- Fullscreen play layer ---

func _enter_play_fullscreen() -> void:
	if _is_play_fullscreen:
		return
	_is_play_fullscreen = true
	# Hide the entire editor UI
	_main._vbox.visible = false
	# Create fullscreen black layer
	_fullscreen_layer = ColorRect.new()
	_fullscreen_layer.name = "FullscreenPlayLayer"
	_fullscreen_layer.color = Color(0, 0, 0, 1)
	_fullscreen_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fullscreen_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_main.add_child(_fullscreen_layer)
	# Reparent visual editor into fullscreen layer — reset all layout
	_main._left_panel.remove_child(_main._visual_editor)
	_fullscreen_layer.add_child(_main._visual_editor)
	_main._visual_editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_main._visual_editor.size_flags_horizontal = Control.SIZE_FILL
	_main._visual_editor.size_flags_vertical = Control.SIZE_FILL
	# Add floating Stop button
	var fs_stop = Button.new()
	fs_stop.name = "FullscreenStopButton"
	fs_stop.text = "■ Stop"
	fs_stop.pressed.connect(on_stop_pressed)
	fs_stop.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	fs_stop.offset_left = -80
	fs_stop.offset_right = -10
	fs_stop.offset_top = 10
	fs_stop.offset_bottom = 40
	_fullscreen_layer.add_child(fs_stop)
	# Reset view deferred so the editor has time to resize
	call_deferred("_deferred_reset_view")


func _deferred_reset_view() -> void:
	if _main._visual_editor:
		_main._visual_editor.reset_view()


func _exit_play_fullscreen() -> void:
	if not _is_play_fullscreen:
		return
	_is_play_fullscreen = false
	# Reparent visual editor back to left_panel
	_fullscreen_layer.remove_child(_main._visual_editor)
	_main._left_panel.add_child(_main._visual_editor)
	_main._left_panel.move_child(_main._visual_editor, 0)
	# Restore VBoxContainer layout flags (anchors are ignored inside a VBoxContainer)
	_main._visual_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_main._visual_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Clean up fullscreen layer
	_fullscreen_layer.queue_free()
	_fullscreen_layer = null
	# Restore the editor UI
	_main._vbox.visible = true
	# Reset view deferred
	call_deferred("_deferred_reset_view")


# --- Typewriter ---

func on_typewriter_tick() -> void:
	if not _main._sequence_editor_ctrl.is_playing():
		_main._typewriter_timer.stop()
		return
	_main._sequence_editor_ctrl.advance_typewriter()
	_main._play_text_label.visible_characters = _main._sequence_editor_ctrl.get_visible_characters()


# --- Input handling for Play mode ---

func _input(event: InputEvent) -> void:
	if not _main._sequence_editor_ctrl.is_playing():
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		if not _main._sequence_editor_ctrl.is_text_fully_displayed():
			_main._sequence_editor_ctrl.skip_typewriter()
			_main._play_text_label.visible_characters = _main._sequence_editor_ctrl.get_visible_characters()
		else:
			_main._sequence_editor_ctrl.advance_play()
		get_viewport().set_input_as_handled()
