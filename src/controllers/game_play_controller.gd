# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends Node

## Gère la logique de lecture en mode jeu standalone (sans éditeur).
## Version simplifiée de PlayController adaptée au contexte game-only.

const StoryI18nService = preload("res://src/services/story_i18n_service.gd")
const AutoPlayManagerScript = preload("res://src/services/auto_play_manager.gd")
const UIScale = preload("res://src/ui/themes/ui_scale.gd")

var _game: Control
var _sequence_editor_ctrl: Control
var _story_play_ctrl: Node
var _foreground_transition: Node
var _sequence_fx_player: Node
var _visual_editor: Control
var _play_overlay: Control
var _play_dialogue_panel: PanelContainer
var _play_character_box: PanelContainer
var _play_character_label: Label
var _play_text_label: RichTextLabel
var _typewriter_timer: Timer
var _choice_overlay: CenterContainer
var _choice_panel: PanelContainer
var _menu_button: Button

var _previous_play_foregrounds: Array = []
var _seen_fg_uuids: Dictionary = {}
var _user_stopped: bool = false
var _i18n: Dictionary = {}
var _current_playing_sequence = null
var _is_showing_title: bool = false
var _restore_dialogue_index: int = -1
var _story_base_path: String = ""
var _music_player: Node = null
var _voice_player: AudioStreamPlayer = null
var _auto_play: RefCounted = null
var _auto_play_button: Button = null
var _skip_button: Button = null
var _play_buttons_bar: HBoxContainer = null
var _typewriter_speed: float = 0.03
var _dialogue_opacity: float = 0.8
var _voice_language: String = ""  # "" = same as text language
var _skip_max_chapter_index: int = -1
var _skip_max_scene_index: int = -1
var _toolbar_visible: bool = true
var _toolbar_toggle_button: Button = null
var _voice_auto_play_connected: bool = false

var _game_plugin_manager: Node = null
var _plugin_ctx: RefCounted = null

var _dialogue_history: Array[Dictionary] = []
var _history_button: Button = null
var _history_panel: Control = null
var _history_open: bool = false

signal play_finished_show_menu()
signal toolbar_toggled(visible: bool)


func set_i18n(dict: Dictionary) -> void:
	_i18n = dict


func set_auto_play_delay(delay: float) -> void:
	if _auto_play:
		_auto_play.delay = delay


func set_typewriter_speed(speed: float) -> void:
	_typewriter_speed = speed
	if speed > 0.0:
		_typewriter_timer.wait_time = speed


func set_dialogue_opacity(value: float) -> void:
	_dialogue_opacity = value
	if _play_dialogue_panel:
		_play_dialogue_panel.self_modulate.a = value


func set_auto_play_enabled(enabled: bool) -> void:
	if _auto_play and enabled != _auto_play.enabled:
		_auto_play.toggle()


func set_toolbar_visible(p_visible: bool) -> void:
	_toolbar_visible = p_visible
	if _toolbar_toggle_button:
		_toolbar_toggle_button.text = "▼" if _toolbar_visible else "▲"


func _on_toolbar_toggle_pressed() -> void:
	set_toolbar_visible(not _toolbar_visible)
	if _play_buttons_bar:
		_play_buttons_bar.visible = _toolbar_visible
	toolbar_toggled.emit(_toolbar_visible)


func set_voice_language(lang: String) -> void:
	_voice_language = lang


func get_auto_play_manager() -> RefCounted:
	return _auto_play


func setup(game: Control) -> void:
	_game = game
	_sequence_editor_ctrl = game._sequence_editor_ctrl
	_story_play_ctrl = game._story_play_ctrl
	_foreground_transition = game._foreground_transition
	_sequence_fx_player = game._sequence_fx_player
	_visual_editor = game._visual_editor
	_play_overlay = game._play_overlay
	_play_dialogue_panel = game._play_dialogue_panel
	_play_character_box = game._play_character_box
	_play_character_label = game._play_character_label
	_play_text_label = game._play_text_label
	_typewriter_timer = game._typewriter_timer
	_choice_overlay = game._choice_overlay
	_choice_panel = game._choice_panel
	_menu_button = game._menu_button
	if game.get("_music_player") != null:
		_music_player = game._music_player
	if game.get("_auto_play_button") != null:
		_auto_play_button = game._auto_play_button
	if game.get("_skip_button") != null:
		_skip_button = game._skip_button
	if game.get("_play_buttons_bar") != null:
		_play_buttons_bar = game._play_buttons_bar
	if game.get("_history_button") != null:
		_history_button = game._history_button
	if game.get("_toolbar_toggle_button") != null:
		_toolbar_toggle_button = game._toolbar_toggle_button
		_toolbar_toggle_button.pressed.connect(_on_toolbar_toggle_pressed)
	# Voice player for dialogue voice files
	_voice_player = AudioStreamPlayer.new()
	_voice_player.bus = "Voice"
	add_child(_voice_player)
	_auto_play = AutoPlayManagerScript.new()
	_auto_play.setup(game.get_tree())
	_auto_play.auto_advance_requested.connect(_on_auto_advance)
	_auto_play.auto_play_toggled.connect(_on_auto_play_toggled)


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
	_seen_fg_uuids = {}
	_current_playing_sequence = seq

	# Nettoyer les transitions précédentes AVANT de charger les visuels
	# (sinon stop_fx restaure le canvas de la séquence précédente par-dessus le nouvel auto-fit)
	_sequence_fx_player.stop_fx()

	# Préparer les visuels d'ouverture
	_prepare_opening_visuals()

	# Bloquer apply_auto_fit pendant le play pour que les FX zoom/pan ne soient pas écrasés
	_visual_editor._is_preview_mode = true

	# Appliquer les FX persistants immédiatement (visibles dès le début, y compris pendant la transition)
	_sequence_fx_player.apply_persistent_fx(seq.fx, _visual_editor._fx_container)
	# Pré-appliquer l'état initial des FX zoom/pan pour éviter un flash visuel au démarrage
	_sequence_fx_player.pre_apply_initial_transform(seq.fx, _visual_editor._canvas)

	if seq.transition_in_type != "none":
		_sequence_fx_player.fx_finished.connect(_on_trans_in_finished_play_fx, CONNECT_ONE_SHOT)
		_sequence_fx_player.play_transition(seq.transition_in_type, seq.transition_in_duration, true, _visual_editor._fx_container)
	else:
		_on_trans_in_finished_play_fx()


func _on_trans_in_finished_play_fx() -> void:
	var seq = _current_playing_sequence
	if seq and seq.fx.size() > 0:
		_sequence_fx_player.fx_finished.connect(_on_fx_finished_start_sequence, CONNECT_ONE_SHOT)
		_sequence_fx_player.play_fx_list(seq.fx, _visual_editor._fx_container, _visual_editor._canvas)
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
	_enable_history_button(true)
	if _restore_dialogue_index >= 0:
		var idx := _restore_dialogue_index
		_restore_dialogue_index = -1
		_sequence_editor_ctrl.start_play_at(idx)
	else:
		_sequence_editor_ctrl.start_play()
	if _sequence_editor_ctrl.is_playing():
		_play_overlay.visible = true
		if not _play_overlay.get_parent():
			_game.add_child(_play_overlay)
		_game.move_child(_play_overlay, _game.get_child_count() - 1)
		if _play_buttons_bar:
			_play_buttons_bar.visible = _toolbar_visible
			_game.move_child(_play_buttons_bar, -1)
		if _toolbar_toggle_button:
			_toolbar_toggle_button.visible = true
			_game.move_child(_toolbar_toggle_button, -1)
		if _typewriter_speed == 0.0:
			_sequence_editor_ctrl.skip_typewriter()
			_play_text_label.visible_characters = _sequence_editor_ctrl.get_visible_characters()
			_try_start_auto_play_timer()
		else:
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
	if _auto_play:
		_auto_play.stop_timer()
	# Pipeline plugins in-game pour les choix
	var display_choices = choices
	if _game_plugin_manager:
		display_choices = _game_plugin_manager.pipeline_before_choice(_plugin_ctx, choices)
	_hide_choice_overlay()
	var vbox = VBoxContainer.new()
	vbox.name = "ChoiceVBox"
	var title_label = Label.new()
	title_label.text = StoryI18nService.get_ui_string("Faites votre choix", _i18n)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", UIScale.scale(18))
	vbox.add_child(title_label)
	var buttons: Array[Button] = []
	for i in range(display_choices.size()):
		var btn = Button.new()
		btn.text = display_choices[i].text
		btn.focus_mode = Control.FOCUS_ALL
		var idx = i
		var choice_text = display_choices[i].text
		btn.pressed.connect(func(): _on_choice_selected(idx, choice_text))
		btn.gui_input.connect(func(event: InputEvent):
			if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
				btn.accept_event()
		)
		if _game_plugin_manager:
			_game_plugin_manager.pipeline_style_choice_button(_plugin_ctx, btn, display_choices[i], i)
		vbox.add_child(btn)
		buttons.append(btn)
	_choice_panel.add_child(vbox)
	_choice_overlay.visible = true
	if not _choice_overlay.get_parent():
		_game.add_child(_choice_overlay)
		_game.move_child(_game._menu_button, -1)
	# Cyclic focus: last ↓ → first, first ↑ → last (must be set after nodes are in tree)
	if buttons.size() > 1:
		buttons[0].focus_neighbor_top = buttons[buttons.size() - 1].get_path()
		buttons[buttons.size() - 1].focus_neighbor_bottom = buttons[0].get_path()
	# Focus first choice button
	if buttons.size() > 0:
		buttons[0].call_deferred("grab_focus")


func on_play_finished(reason: String) -> void:
	if _user_stopped:
		return
	_hide_choice_overlay()
	_cleanup_play()
	if reason == "game_over":
		if _game.get("_game_over_screen") != null:
			_game._game_over_screen.show_screen()
			return
	elif reason == "to_be_continued":
		if _game.get("_to_be_continued_screen") != null:
			_game._to_be_continued_screen.show_screen()
			return
	var messages = {
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
	# Stop any pending auto-play timer/voice wait from the previous dialogue
	if _auto_play:
		_auto_play.stop_timer()
		_cancel_voice_auto_play_wait()
	var dlg = seq.dialogues[index]
	_play_dialogue_voice(dlg)
	var display_character: String = dlg.character
	var display_text: String = dlg.text
	# Pipeline plugins in-game
	if _game_plugin_manager:
		if _plugin_ctx:
			_plugin_ctx.current_dialogue_index = index
		var result = _game_plugin_manager.pipeline_before_dialogue(_plugin_ctx, display_character, display_text)
		display_character = result["character"]
		display_text = result["text"]
	_play_character_label.text = display_character
	if _play_character_box:
		_play_character_box.visible = display_character != ""
	_play_text_label.text = display_text
	_sequence_editor_ctrl.set_display_text_length(display_text.length())
	add_history_entry(display_character, display_text)
	_play_text_label.visible_characters = 0
	# Dispatch after-dialogue to plugins
	if _game_plugin_manager:
		_game_plugin_manager.dispatch_on_after_dialogue(_plugin_ctx, display_character, display_text)
	# Restart typewriter for the new dialogue
	if _typewriter_speed == 0.0:
		_sequence_editor_ctrl.skip_typewriter()
		_play_text_label.visible_characters = _sequence_editor_ctrl.get_visible_characters()
		_try_start_auto_play_timer()
	else:
		_typewriter_timer.start()

	# Compute foreground transitions
	var new_fgs = _sequence_editor_ctrl.get_effective_foregrounds(index)
	var transitions = _foreground_transition.compute_transitions(_previous_play_foregrounds, new_fgs, _seen_fg_uuids)
	for fg in new_fgs:
		_seen_fg_uuids[fg.uuid] = true
	_previous_play_foregrounds = new_fgs

	# Phase 1 : Cloner les anciens nœuds AVANT la mise à jour visuelle
	var clones: Array = []
	var morph_data: Array = []
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
	_update_preview(index)

	# Phase 3 : Positionner les clones et appliquer les transitions
	# Le z_index sur les clones et les wrappers FG garantit le bon ordre visuel
	for entry in clones:
		var clone = entry["clone"]
		var action = entry["action"]
		var duration = entry["duration"]
		var uuid = entry["uuid"]
		var target = _visual_editor.get_foreground_node(uuid)

		if action == "fade_out":
			# z_index gère le layering visuel — pas besoin de move_child
			_foreground_transition.apply_tween_fade_out(clone, duration, true)

		elif action == "replace_fade":
			if target and is_instance_valid(target):
				var parent = clone.get_parent()
				if parent:
					# Placer le clone sous la cible pour le crossfade (même z_index)
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
			# z_index gère le layering visuel — le clone est déjà au-dessus
			# de la cible par l'ordre des enfants après Phase 2
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


func on_play_stopped() -> void:
	_handle_play_stopped()


func _handle_play_stopped() -> void:
	_play_overlay.visible = false
	if _play_buttons_bar:
		_play_buttons_bar.visible = false
	if _toolbar_toggle_button:
		_toolbar_toggle_button.visible = false
	_typewriter_timer.stop()
	if _auto_play:
		_auto_play.stop_timer()
	if _play_overlay.get_parent():
		_play_overlay.get_parent().remove_child(_play_overlay)
	
	var seq = _current_playing_sequence
	# Ne pas jouer la transition de sortie si l'ending est un choix :
	# le background/foreground doit rester visible derrière les boutons de choix.
	var has_choices_ending = seq != null and seq.ending != null and seq.ending.type == "choices"
	if seq and seq.transition_out_type != "none" and not _user_stopped and not has_choices_ending:
		_sequence_fx_player.fx_finished.connect(_on_trans_out_finished, CONNECT_ONE_SHOT)
		_sequence_fx_player.play_transition(seq.transition_out_type, seq.transition_out_duration, false, _visual_editor._fx_container)
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
	if _sequence_editor_ctrl.is_text_fully_displayed() and _auto_play and _auto_play.enabled:
		_typewriter_timer.stop()
		_try_start_auto_play_timer()


# --- Input ---

func _is_advance_input(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		return true
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		return true
	return false


func _input(event: InputEvent) -> void:
	if _is_showing_title:
		if _is_advance_input(event):
			_hide_title_screen()
			get_viewport().set_input_as_handled()
		return

	if not _sequence_editor_ctrl.is_playing():
		return
	if _is_advance_input(event):
		if _choice_overlay.visible or _history_open:
			return
		# Don't consume mouse clicks targeting the menu button, play buttons or toggle
		if event is InputEventMouseButton:
			var mouse_pos = event.position
			if _menu_button.visible and _menu_button.get_global_rect().has_point(mouse_pos):
				return
			if _play_buttons_bar and _play_buttons_bar.visible and _play_buttons_bar.get_global_rect().has_point(mouse_pos):
				return
			if _toolbar_toggle_button and _toolbar_toggle_button.visible and _toolbar_toggle_button.get_global_rect().has_point(mouse_pos):
				return
		if _auto_play:
			_auto_play.stop_timer()
			_cancel_voice_auto_play_wait()
		if not _sequence_editor_ctrl.is_text_fully_displayed():
			_sequence_editor_ctrl.skip_typewriter()
			_play_text_label.visible_characters = _sequence_editor_ctrl.get_visible_characters()
		else:
			_sequence_editor_ctrl.advance_play()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_S:
		execute_skip()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_H:
		if not _choice_overlay.visible:
			open_history()
			get_viewport().set_input_as_handled()


# --- Auto-play ---

func _on_auto_advance() -> void:
	if not _sequence_editor_ctrl.is_playing():
		return
	if _sequence_editor_ctrl.is_text_fully_displayed():
		_sequence_editor_ctrl.advance_play()


func _on_auto_play_toggled(active: bool) -> void:
	if _auto_play_button:
		_auto_play_button.text = StoryI18nService.get_ui_string("Auto [ON]" if active else "Auto", _i18n)
		if active:
			_auto_play_button.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
		else:
			_auto_play_button.remove_theme_color_override("font_color")
	if active and _sequence_editor_ctrl.is_playing() and _sequence_editor_ctrl.is_text_fully_displayed():
		_try_start_auto_play_timer()
	elif not active:
		_cancel_voice_auto_play_wait()


func toggle_auto_play() -> void:
	if _auto_play:
		_auto_play.toggle()


## Starts auto-play timer, waiting for voice to finish first if still playing.
func _try_start_auto_play_timer() -> void:
	if not _auto_play or not _auto_play.enabled:
		return
	if _voice_player and _voice_player.playing:
		if not _voice_auto_play_connected:
			_voice_player.finished.connect(_on_voice_finished_for_auto_play, CONNECT_ONE_SHOT)
			_voice_auto_play_connected = true
	else:
		_auto_play.start_timer()


func _on_voice_finished_for_auto_play() -> void:
	_voice_auto_play_connected = false
	if _auto_play and _auto_play.enabled and _sequence_editor_ctrl.is_playing() and _sequence_editor_ctrl.is_text_fully_displayed():
		_auto_play.start_timer()


func _cancel_voice_auto_play_wait() -> void:
	if _voice_auto_play_connected and _voice_player:
		if _voice_player.finished.is_connected(_on_voice_finished_for_auto_play):
			_voice_player.finished.disconnect(_on_voice_finished_for_auto_play)
		_voice_auto_play_connected = false


# --- Skip ---

## Définit la progression maximale calculée depuis les sauvegardes.
func set_skip_progression(max_ch_idx: int, max_sc_idx: int) -> void:
	_skip_max_chapter_index = max_ch_idx
	_skip_max_scene_index = max_sc_idx


## Met à jour l'état disabled du bouton Skip selon la scène courante.
func update_skip_availability(chapter_index: int, scene_index: int) -> void:
	if _skip_button == null:
		return
	_skip_button.disabled = not is_scene_available(chapter_index, scene_index, _skip_max_chapter_index, _skip_max_scene_index)


## Calcule si une scène est disponible pour le skip (logique pure, testable).
static func is_scene_available(ch_idx: int, sc_idx: int, max_ch_idx: int, max_sc_idx: int) -> bool:
	if max_ch_idx < 0:
		return false
	return ch_idx < max_ch_idx or (ch_idx == max_ch_idx and sc_idx <= max_sc_idx)


## Saute instantanément à la fin de la séquence courante.
## Un appui = un saut (action ponctuelle, pas un mode persistant).
func execute_skip() -> void:
	if _skip_button == null or _skip_button.disabled:
		return
	if not _sequence_editor_ctrl.is_playing():
		return
	_typewriter_timer.stop()
	if _auto_play:
		_auto_play.stop_timer()
	_sequence_editor_ctrl.skip_to_end()
	_handle_play_stopped()


# --- History ---

## Formate une entrée d'historique (logique pure).
static func format_history_entry(character: String, text: String) -> String:
	if character == "" and text == "":
		return ""
	if character == "":
		return text
	return character + " : " + text


## Ajoute un dialogue à l'historique.
func add_history_entry(character: String, text: String) -> void:
	_dialogue_history.append({"character": character, "text": text})


## Réinitialise l'historique.
func reset_history() -> void:
	_dialogue_history = []


## Ouvre ou ferme le panneau d'historique (toggle).
func open_history() -> void:
	if _history_open:
		close_history()
		return
	_history_open = true
	_update_history_button_text()
	_show_history_panel()


## Ferme le panneau d'historique.
func close_history() -> void:
	_history_open = false
	_update_history_button_text()
	_hide_history_panel()


## Met à jour le texte du bouton selon l'état du panneau.
func _update_history_button_text() -> void:
	if _history_button == null:
		return
	if _history_open:
		_history_button.text = StoryI18nService.get_ui_string("Histo [ON]", _i18n)
		_history_button.add_theme_color_override("font_color", Color(0.2, 0.8, 0.8))
	else:
		_history_button.text = StoryI18nService.get_ui_string("Histo (H)", _i18n)
		_history_button.remove_theme_color_override("font_color")


## Active ou désactive le bouton historique.
func _enable_history_button(enabled: bool) -> void:
	if _history_button == null:
		return
	_history_button.disabled = not enabled


## Construit et affiche le panneau d'historique.
func _show_history_panel() -> void:
	if _history_panel != null and is_instance_valid(_history_panel):
		_history_panel.queue_free()
		_history_panel = null

	# Fond cliquable pour fermer
	var overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 90
	overlay.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			close_history()
	)
	_history_panel = overlay

	# Panneau centré
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	overlay.add_child(center)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(UIScale.scale(600), UIScale.scale(400))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UIScale.scale(8))
	panel.add_child(vbox)

	var title = Label.new()
	title.text = StoryI18nService.get_ui_string("Historique", _i18n)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", UIScale.scale(18))
	vbox.add_child(title)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, UIScale.scale(300))
	vbox.add_child(scroll)

	var entries_vbox = VBoxContainer.new()
	entries_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entries_vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(entries_vbox)

	for entry in _dialogue_history:
		var lbl = Label.new()
		lbl.text = format_history_entry(entry["character"], entry["text"])
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		entries_vbox.add_child(lbl)

	# Scroll vers le bas après un frame
	scroll.call_deferred("set_v_scroll", 999999)

	var close_btn = Button.new()
	close_btn.text = StoryI18nService.get_ui_string("Fermer", _i18n)
	close_btn.pressed.connect(close_history)
	vbox.add_child(close_btn)

	if _game == null:
		return
	_game.add_child(overlay)


## Supprime le panneau d'historique.
func _hide_history_panel() -> void:
	if _history_panel != null and is_instance_valid(_history_panel):
		_history_panel.queue_free()
	_history_panel = null


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
		_visual_editor.update_foregrounds()


func _create_fade_out_clone(source: Control, z_order: int = 0) -> TextureRect:
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
	clone.flip_h = tex_node.flip_h
	clone.flip_v = tex_node.flip_v
	clone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clone.position = source.position
	clone.size = source.size
	clone.modulate = source.modulate
	clone.z_index = z_order
	fg_container.add_child(clone)
	return clone


func _on_choice_selected(index: int, choice_text: String = "") -> void:
	if choice_text != "":
		add_history_entry("→", choice_text)
	_hide_choice_overlay()
	_story_play_ctrl.on_choice_selected(index)


func _hide_choice_overlay() -> void:
	_choice_overlay.visible = false
	for child in _choice_panel.get_children():
		child.queue_free()
	if _choice_overlay.get_parent():
		_choice_overlay.get_parent().remove_child(_choice_overlay)


func _cleanup_play() -> void:
	reset_history()
	close_history()
	_enable_history_button(false)
	_is_showing_title = false
	_game._play_title_overlay.visible = false
	if _game._play_title_overlay.get_parent():
		_game._play_title_overlay.get_parent().remove_child(_game._play_title_overlay)
	if _sequence_fx_player:
		_sequence_fx_player.stop_fx()
	if _visual_editor:
		_visual_editor._is_preview_mode = false
	if _music_player:
		_music_player.stop_music()
	_stop_dialogue_voice()
	if _auto_play:
		_auto_play.reset()
	if _skip_button:
		_skip_button.disabled = true
	_menu_button.visible = false
	if _play_buttons_bar:
		_play_buttons_bar.visible = false
	if _toolbar_toggle_button:
		_toolbar_toggle_button.visible = false
	_play_overlay.visible = false
	_typewriter_timer.stop()
	if _play_overlay.get_parent():
		_play_overlay.get_parent().remove_child(_play_overlay)
	_previous_play_foregrounds = []
	_seen_fg_uuids = {}
	# Masquer l'affichage des variables
	if _game._variable_sidebar:
		_game._variable_sidebar.visible = false
	if _game._variable_sidebar_scroll:
		_game._variable_sidebar_scroll.visible = false
	if _game._variable_details_overlay:
		_game._variable_details_overlay.hide_details()


func _stop_dialogue_voice() -> void:
	if _voice_player and _voice_player.playing:
		_voice_player.stop()
	_restore_music_volume()


func _play_dialogue_voice(dlg) -> void:
	_stop_dialogue_voice()
	if _voice_player == null:
		return
	var voice_path := _get_dialogue_voice_path(dlg)
	if voice_path == "":
		return
	var resolved := MusicPlayer._resolve_path(voice_path, _story_base_path)
	if resolved == "":
		return
	var stream: AudioStream = MusicPlayer._load_audio_stream(resolved, false)
	if stream == null:
		return
	_voice_player.stream = stream
	_voice_player.play()
	_duck_music_volume()
	_voice_player.finished.connect(_restore_music_volume, CONNECT_ONE_SHOT)


func _duck_music_volume() -> void:
	if _music_player and _music_player.has_method("set_duck_volume_db"):
		_music_player.set_duck_volume_db(-4.0)


func _restore_music_volume() -> void:
	if _music_player and _music_player.has_method("set_duck_volume_db"):
		_music_player.set_duck_volume_db(0.0)


func _get_dialogue_voice_path(dlg) -> String:
	var voice_files = dlg.get("voice_files")
	if voice_files != null and voice_files is Dictionary and not voice_files.is_empty():
		# 1. Utiliser la langue voix si configurée
		if _voice_language != "" and voice_files.has(_voice_language):
			return voice_files[_voice_language]
		# 2. Sinon utiliser la langue du texte
		var lang: String = ""
		if _game and _game.get("_settings") != null and _game._settings.get("language") != null:
			lang = str(_game._settings.language)
		if lang != "" and voice_files.has(lang):
			return voice_files[lang]
		# Fallback: "default" key, then first available
		if voice_files.has("default"):
			return voice_files["default"]
		for key in voice_files:
			return voice_files[key]
	var old_vf = dlg.get("voice_file")
	if old_vf != null and old_vf is String and old_vf != "":
		return old_vf
	return ""