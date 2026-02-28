extends Node

## Gère la logique de lecture en mode jeu standalone (sans éditeur).
## Version simplifiée de PlayController adaptée au contexte game-only.

var _game: Control
var _sequence_editor_ctrl: Control
var _story_play_ctrl: Node
var _foreground_transition: Node
var _sequence_fx_player: Node
var _visual_editor: Control
var _play_overlay: PanelContainer
var _play_character_label: Label
var _play_text_label: RichTextLabel
var _typewriter_timer: Timer
var _choice_overlay: PanelContainer
var _menu_button: Button

var _previous_play_foregrounds: Array = []
var _user_stopped: bool = false

signal play_finished_show_menu()


func setup(game: Control) -> void:
	_game = game
	_sequence_editor_ctrl = game._sequence_editor_ctrl
	_story_play_ctrl = game._story_play_ctrl
	_foreground_transition = game._foreground_transition
	_sequence_fx_player = game._sequence_fx_player
	_visual_editor = game._visual_editor
	_play_overlay = game._play_overlay
	_play_character_label = game._play_character_label
	_play_text_label = game._play_text_label
	_typewriter_timer = game._typewriter_timer
	_choice_overlay = game._choice_overlay
	_menu_button = game._menu_button


func start_story(story) -> void:
	_menu_button.visible = true
	_story_play_ctrl.start_play_story(story)


func stop_and_restart(story) -> void:
	_user_stopped = true
	_sequence_fx_player.stop_fx()
	if _sequence_editor_ctrl.is_playing():
		_sequence_editor_ctrl.stop_play()
	if _story_play_ctrl.is_playing():
		_story_play_ctrl.stop_play()
	_hide_choice_overlay()
	_cleanup_play()
	_user_stopped = false
	start_story(story)


func stop_current() -> void:
	_user_stopped = true
	_sequence_fx_player.stop_fx()
	if _sequence_editor_ctrl.is_playing():
		_sequence_editor_ctrl.stop_play()
	if _story_play_ctrl.is_playing():
		_story_play_ctrl.stop_play()
	_hide_choice_overlay()
	_cleanup_play()
	_user_stopped = false


# --- StoryPlayController signals ---

func on_sequence_play_requested(seq) -> void:
	_sequence_editor_ctrl.load_sequence(seq)
	_visual_editor.load_sequence(seq)
	_previous_play_foregrounds = []
	if seq.fx.size() > 0:
		_sequence_fx_player.fx_finished.connect(_on_fx_finished_start_sequence, CONNECT_ONE_SHOT)
		_sequence_fx_player.play_fx_list(seq.fx, _visual_editor)
	else:
		_start_sequence_play()


func _start_sequence_play() -> void:
	_sequence_editor_ctrl.start_play()
	if _sequence_editor_ctrl.is_playing():
		_play_overlay.visible = true
		_visual_editor._overlay_container.add_child(_play_overlay)
		_typewriter_timer.start()
	else:
		_story_play_ctrl.on_sequence_finished()


func _on_fx_finished_start_sequence() -> void:
	_start_sequence_play()


func on_choice_display_requested(choices) -> void:
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
		btn.pressed.connect(func(): _on_choice_selected(idx))
		vbox.add_child(btn)
	_choice_overlay.add_child(vbox)
	_choice_overlay.visible = true
	if not _choice_overlay.get_parent():
		_visual_editor._overlay_container.add_child(_choice_overlay)


func on_play_finished(reason: String) -> void:
	if _user_stopped:
		return
	_hide_choice_overlay()
	_cleanup_play()
	var messages = {
		"game_over": "Fin — Game Over",
		"to_be_continued": "Fin — À suivre...",
		"no_ending": "Fin (aucune terminaison configurée)",
		"error": "Erreur (cible introuvable ou contenu vide)",
		"stopped": "Lecture arrêtée",
	}
	var msg = messages.get(reason, "Fin de la lecture")
	var dialog = AcceptDialog.new()
	dialog.dialog_text = msg
	dialog.confirmed.connect(func(): play_finished_show_menu.emit())
	dialog.canceled.connect(func(): play_finished_show_menu.emit())
	_game.add_child(dialog)
	dialog.popup_centered()


# --- SequenceEditor signals ---

func on_play_dialogue_changed(index: int) -> void:
	var seq = _sequence_editor_ctrl.get_sequence()
	if seq == null or index < 0 or index >= seq.dialogues.size():
		return
	var dlg = seq.dialogues[index]
	_play_character_label.text = dlg.character
	_play_text_label.text = dlg.text
	_play_text_label.visible_characters = 0

	# Compute foreground transitions
	var new_fgs = _sequence_editor_ctrl.get_effective_foregrounds(index)
	var transitions = _foreground_transition.compute_transitions(_previous_play_foregrounds, new_fgs)
	_previous_play_foregrounds = new_fgs

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

	# Clone old nodes for fade_out before visual update
	var fade_out_clones: Array = []
	for t in transitions:
		if t["action"] == "fade_out":
			var old_node = _visual_editor.get_foreground_node(t["uuid"])
			if old_node and is_instance_valid(old_node):
				var clone = _create_fade_out_clone(old_node)
				if clone:
					fade_out_clones.append(clone)

	# Update visuals
	_update_preview(index)

	# Move clones above new nodes
	for clone in fade_out_clones:
		var p = clone.get_parent()
		if p:
			p.move_child(clone, p.get_child_count() - 1)

	# Apply transitions
	for t in transitions:
		if t["action"] == "fade_in" or t["action"] == "crossfade":
			var target = _visual_editor.get_foreground_node(t["uuid"])
			if target == null:
				continue
			if is_replacement:
				target.modulate.a = 1.0
			else:
				var tween = _foreground_transition.apply_tween_fade_in(target, t["duration"])
				if tween:
					var uuid = t["uuid"]
					_visual_editor._transitioning_uuids.append(uuid)
					tween.finished.connect(func(): _visual_editor._transitioning_uuids.erase(uuid))

	# Apply fade_out on clones
	var fo_duration = fade_in_duration if is_replacement else 0.5
	for clone in fade_out_clones:
		_foreground_transition.apply_tween_fade_out(clone, fo_duration, true)


func on_play_stopped() -> void:
	_play_overlay.visible = false
	_typewriter_timer.stop()
	if _play_overlay.get_parent():
		_play_overlay.get_parent().remove_child(_play_overlay)
	if not _user_stopped:
		_story_play_ctrl.on_sequence_finished()


func on_typewriter_tick() -> void:
	if not _sequence_editor_ctrl.is_playing():
		_typewriter_timer.stop()
		return
	_sequence_editor_ctrl.advance_typewriter()
	_play_text_label.visible_characters = _sequence_editor_ctrl.get_visible_characters()


# --- Input ---

func _input(event: InputEvent) -> void:
	if not _sequence_editor_ctrl.is_playing():
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		if not _sequence_editor_ctrl.is_text_fully_displayed():
			_sequence_editor_ctrl.skip_typewriter()
			_play_text_label.visible_characters = _sequence_editor_ctrl.get_visible_characters()
		else:
			_sequence_editor_ctrl.advance_play()
		get_viewport().set_input_as_handled()


# --- Internal ---

func _update_preview(index: int) -> void:
	var fgs = _sequence_editor_ctrl.get_effective_foregrounds(index)
	var seq = _sequence_editor_ctrl.get_sequence()
	if seq:
		seq.foregrounds = fgs
		_visual_editor.load_sequence(seq)


func _create_fade_out_clone(source: Control) -> TextureRect:
	var fg_container = _visual_editor.get_node_or_null("Canvas/ForegroundContainer")
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


func _on_choice_selected(index: int) -> void:
	_hide_choice_overlay()
	_story_play_ctrl.on_choice_selected(index)


func _hide_choice_overlay() -> void:
	_choice_overlay.visible = false
	for child in _choice_overlay.get_children():
		child.queue_free()
	if _choice_overlay.get_parent():
		_choice_overlay.get_parent().remove_child(_choice_overlay)


func _cleanup_play() -> void:
	_menu_button.visible = false
	_play_overlay.visible = false
	_typewriter_timer.stop()
	if _play_overlay.get_parent():
		_play_overlay.get_parent().remove_child(_play_overlay)
	_previous_play_foregrounds = []
