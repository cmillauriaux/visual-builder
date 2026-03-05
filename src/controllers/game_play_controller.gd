extends Node

## Gère la logique de lecture en mode jeu standalone (sans éditeur).
## Version simplifiée de PlayController adaptée au contexte game-only.

const StoryI18nService = preload("res://src/services/story_i18n_service.gd")

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
var _choice_overlay: CenterContainer
var _choice_panel: PanelContainer
var _menu_button: Button

var _previous_play_foregrounds: Array = []
var _user_stopped: bool = false
var _i18n: Dictionary = {}
var _current_playing_sequence = null
var _is_showing_title: bool = false
var _restore_dialogue_index: int = -1
var _story_base_path: String = ""
var _music_player: Node = null

signal play_finished_show_menu()


func set_i18n(dict: Dictionary) -> void:
	_i18n = dict


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
	_choice_panel = game._choice_panel
	_menu_button = game._menu_button
	if game.get("_music_player") != null:
		_music_player = game._music_player


func start_story(story, base_path: String = "") -> void:
	_story_base_path = base_path
	if _music_player:
		_music_player.stop_music()
	_menu_button.visible = true
	_story_play_ctrl.start_play_story(story)


## Reprend une partie depuis une sauvegarde.
## Trouve chapter/scene/sequence par UUID et reprend au bon index de dialogue.
func start_from_save(story, save_data: Dictionary, base_path: String = "") -> void:
	stop_current()
	_story_base_path = base_path
	if _music_player:
		_music_player.stop_music()
	_menu_button.visible = true
	var chapter = story.find_chapter(save_data.get("chapter_uuid", ""))
	var scene = chapter.find_scene(save_data.get("scene_uuid", "")) if chapter else null
	var sequence = scene.find_sequence(save_data.get("sequence_uuid", "")) if scene else null
	if chapter == null or scene == null or sequence == null:
		return
	_restore_dialogue_index = save_data.get("dialogue_index", 0)
	var vars: Dictionary = save_data.get("variables", {})
	_story_play_ctrl.start_play_from_save(story, chapter, scene, sequence, vars)


func stop_and_restart(story, base_path: String = "") -> void:
	_user_stopped = true
	_sequence_fx_player.stop_fx()
	if _sequence_editor_ctrl.is_playing():
		_sequence_editor_ctrl.stop_play()
	if _story_play_ctrl.is_playing():
		_story_play_ctrl.stop_play()
	_hide_choice_overlay()
	_cleanup_play()
	_user_stopped = false
	start_story(story, base_path)


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
	_previous_play_foregrounds = []
	_current_playing_sequence = seq

	# Préparer les visuels d'ouverture : n'afficher que les foregrounds statiques
	# du premier dialogue pour éviter un flash des foregrounds animés pendant la transition.
	_prepare_opening_visuals()

	# Nettoyer les transitions précédentes (ex: reste de pixelisation ou fondu)
	_sequence_fx_player.stop_fx()

	if seq.transition_in_type != "none":
		_sequence_fx_player.fx_finished.connect(_on_trans_in_finished_play_fx, CONNECT_ONE_SHOT)
		_sequence_fx_player.play_transition(seq.transition_in_type, seq.transition_in_duration, true, _visual_editor)
	else:
		_on_trans_in_finished_play_fx()


func _on_trans_in_finished_play_fx() -> void:
	var seq = _current_playing_sequence
	if seq and seq.fx.size() > 0:
		_sequence_fx_player.fx_finished.connect(_on_fx_finished_start_sequence, CONNECT_ONE_SHOT)
		_sequence_fx_player.play_fx_list(seq.fx, _visual_editor)
	else:
		_apply_sequence_audio()
		_start_sequence_play()


func _apply_sequence_audio() -> void:
	if _music_player == null:
		return
	var seq = _current_playing_sequence
	if seq == null:
		return
	_music_player.apply_sequence(seq, _story_base_path)


func _start_sequence_play() -> void:
	var seq = _current_playing_sequence
	if seq and (seq.title != "" or seq.subtitle != ""):
		_show_title_screen(seq)
	else:
		_start_sequence_actually()


func _start_sequence_actually() -> void:
	if _restore_dialogue_index >= 0:
		var idx := _restore_dialogue_index
		_restore_dialogue_index = -1
		_sequence_editor_ctrl.start_play_at(idx)
	else:
		_sequence_editor_ctrl.start_play()
	if _sequence_editor_ctrl.is_playing():
		_play_overlay.visible = true
		_visual_editor._overlay_container.add_child(_play_overlay)
		_typewriter_timer.start()
	else:
		_handle_play_stopped()


func _show_title_screen(seq) -> void:
	_is_showing_title = true
	_game._play_title_label.text = seq.title
	_game._play_subtitle_label.text = seq.subtitle
	_game._play_title_overlay.visible = true
	if not _game._play_title_overlay.get_parent():
		_visual_editor._overlay_container.add_child(_game._play_title_overlay)


func _hide_title_screen() -> void:
	_is_showing_title = false
	_game._play_title_overlay.visible = false
	if _game._play_title_overlay.get_parent():
		_game._play_title_overlay.get_parent().remove_child(_game._play_title_overlay)
	_start_sequence_actually()


func _on_fx_finished_start_sequence() -> void:
	_apply_sequence_audio()
	_start_sequence_play()


func on_choice_display_requested(choices) -> void:
	_hide_choice_overlay()
	var vbox = VBoxContainer.new()
	vbox.name = "ChoiceVBox"
	var title_label = Label.new()
	title_label.text = StoryI18nService.get_ui_string("Faites votre choix", _i18n)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title_label)
	for i in range(choices.size()):
		var btn = Button.new()
		btn.text = choices[i].text
		var idx = i
		btn.pressed.connect(func(): _on_choice_selected(idx))
		vbox.add_child(btn)
	_choice_panel.add_child(vbox)
	_choice_overlay.visible = true
	if not _choice_overlay.get_parent():
		_game.add_child(_choice_overlay)
		_game.move_child(_game._menu_button, -1)


func on_play_finished(reason: String) -> void:
	if _user_stopped:
		return
	_hide_choice_overlay()
	_cleanup_play()
	var messages = {
		"game_over": StoryI18nService.get_ui_string("Fin — Game Over", _i18n),
		"to_be_continued": StoryI18nService.get_ui_string("Fin — À suivre...", _i18n),
		"no_ending": StoryI18nService.get_ui_string("Fin (aucune terminaison configurée)", _i18n),
		"error": StoryI18nService.get_ui_string("Erreur (cible introuvable ou contenu vide)", _i18n),
		"stopped": StoryI18nService.get_ui_string("Lecture arrêtée", _i18n),
	}
	var msg = messages.get(reason, StoryI18nService.get_ui_string("Fin de la lecture", _i18n))
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

	# Phase 1 : Cloner les anciens nœuds AVANT la mise à jour visuelle
	var clones: Array = []
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

	# Phase 2 : Mettre à jour les visuels
	_update_preview(index)

	# Phase 3 : Positionner les clones et appliquer les transitions
	for entry in clones:
		var clone = entry["clone"]
		var action = entry["action"]
		var duration = entry["duration"]
		var uuid = entry["uuid"]
		var target = _visual_editor.get_foreground_node(uuid)

		if action == "fade_out":
			if clone.get_parent():
				clone.get_parent().move_child(clone, clone.get_parent().get_child_count() - 1)
			_foreground_transition.apply_tween_fade_out(clone, duration, true)

		elif action == "replace_fade":
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


func on_play_stopped() -> void:
	_handle_play_stopped()


func _handle_play_stopped() -> void:
	_play_overlay.visible = false
	_typewriter_timer.stop()
	if _play_overlay.get_parent():
		_play_overlay.get_parent().remove_child(_play_overlay)
	
	var seq = _current_playing_sequence
	if seq and seq.transition_out_type != "none" and not _user_stopped:
		_sequence_fx_player.fx_finished.connect(_on_trans_out_finished, CONNECT_ONE_SHOT)
		_sequence_fx_player.play_transition(seq.transition_out_type, seq.transition_out_duration, false, _visual_editor)
	else:
		_on_trans_out_finished()


func _on_trans_out_finished() -> void:
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
			_play_text_label.visible_characters = _sequence_editor_ctrl.get_visible_characters()
		else:
			_sequence_editor_ctrl.advance_play()
		get_viewport().set_input_as_handled()


# --- Internal ---

func _prepare_opening_visuals() -> void:
	var seq = _sequence_editor_ctrl.get_sequence()
	if seq == null or seq.dialogues.is_empty():
		_visual_editor.load_sequence(seq)
		return
	var fgs = _sequence_editor_ctrl.get_effective_foregrounds(0)
	var static_fgs: Array = []
	for fg in fgs:
		if fg.transition_type == "none":
			static_fgs.append(fg)
	seq.foregrounds = static_fgs
	_visual_editor.load_sequence(seq)
	_previous_play_foregrounds = static_fgs


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
	for child in _choice_panel.get_children():
		child.queue_free()
	if _choice_overlay.get_parent():
		_choice_overlay.get_parent().remove_child(_choice_overlay)


func _cleanup_play() -> void:
	_is_showing_title = false
	_game._play_title_overlay.visible = false
	if _game._play_title_overlay.get_parent():
		_game._play_title_overlay.get_parent().remove_child(_game._play_title_overlay)
	if _music_player:
		_music_player.stop_music()
	_menu_button.visible = false
	_play_overlay.visible = false
	_typewriter_timer.stop()
	if _play_overlay.get_parent():
		_play_overlay.get_parent().remove_child(_play_overlay)
	_previous_play_foregrounds = []
	# Masquer l'affichage des variables
	if _game._variable_sidebar:
		_game._variable_sidebar.visible = false
	if _game._variable_sidebar_scroll:
		_game._variable_sidebar_scroll.visible = false
	if _game._variable_details_overlay:
		_game._variable_details_overlay.hide_details()
