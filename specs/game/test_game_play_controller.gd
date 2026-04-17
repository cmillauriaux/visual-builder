extends GutTest

## Tests pour GamePlayController — logique de lecture en mode jeu standalone.

const GameScript = preload("res://src/game.gd")
const GamePlayControllerScript = preload("res://src/controllers/game_play_controller.gd")
const SequenceScript = preload("res://src/models/sequence.gd")
const DialogueScript = preload("res://src/models/dialogue.gd")
const StoryScript = preload("res://src/models/story.gd")
const ChapterScript = preload("res://src/models/chapter.gd")
const SceneDataScript = preload("res://src/models/scene_data.gd")

var _game: Control


func before_each() -> void:
	_game = Control.new()
	_game.set_script(GameScript)
	add_child(_game)


func after_each() -> void:
	remove_child(_game)
	_game.queue_free()


func test_play_ctrl_exists() -> void:
	assert_not_null(_game._play_ctrl, "play controller should exist")
	assert_true(_game._play_ctrl.get_script() == GamePlayControllerScript)


func test_setup_stores_references() -> void:
	assert_eq(_game._play_ctrl._sequence_editor_ctrl, _game._sequence_editor_ctrl)
	assert_eq(_game._play_ctrl._story_play_ctrl, _game._story_play_ctrl)
	assert_eq(_game._play_ctrl._visual_editor, _game._visual_editor)
	assert_eq(_game._play_ctrl._play_overlay, _game._play_overlay)
	assert_eq(_game._play_ctrl._sequence_fx_player, _game._sequence_fx_player)


func test_start_story_shows_menu_button() -> void:
	var story = _create_minimal_story()
	_game._play_ctrl.start_story(story)
	assert_true(_game._menu_button.visible, "menu button should be visible after start")


func test_on_play_dialogue_changed_updates_labels() -> void:
	var seq = _create_sequence_with_dialogue("Alice", "Hello world")
	_game._sequence_editor_ctrl.load_sequence(seq)
	_game._sequence_editor_ctrl.start_play()

	_game._play_ctrl.on_play_dialogue_changed(0)
	assert_eq(_game._play_character_label.text, "Alice")
	assert_eq(_game._play_text_label.text, "Hello world")
	assert_eq(_game._play_text_label.visible_characters, 0)


func test_on_play_dialogue_changed_ignores_invalid_index() -> void:
	_game._play_character_label.text = "initial"
	_game._play_ctrl.on_play_dialogue_changed(-1)
	assert_eq(_game._play_character_label.text, "initial", "should not change on invalid index")


func test_on_play_stopped_hides_overlay() -> void:
	_game._play_overlay.visible = true
	_game._play_ctrl.on_play_stopped()
	assert_false(_game._play_overlay.visible, "play overlay should be hidden after stop")


func test_typewriter_tick_advances_characters() -> void:
	var seq = _create_sequence_with_dialogue("Bob", "Bonjour")
	_game._sequence_editor_ctrl.load_sequence(seq)
	_game._sequence_editor_ctrl.start_play()

	_game._play_ctrl.on_play_dialogue_changed(0)
	_game._play_ctrl.on_typewriter_tick()
	assert_eq(_game._play_text_label.visible_characters, 1)

	_game._play_ctrl.on_typewriter_tick()
	assert_eq(_game._play_text_label.visible_characters, 2)


func test_typewriter_tick_stops_when_not_playing() -> void:
	# Not playing → should not crash
	_game._play_ctrl.on_typewriter_tick()
	pass_test("should not crash when not playing")


func test_cleanup_play_hides_ui() -> void:
	_game._menu_button.visible = true
	_game._play_overlay.visible = true
	_game._play_ctrl._cleanup_play()
	assert_false(_game._menu_button.visible)
	assert_false(_game._play_overlay.visible)


func test_hide_choice_overlay() -> void:
	var child = Label.new()
	_game._choice_panel.add_child(child)
	_game._choice_overlay.visible = true
	_game._play_ctrl._hide_choice_overlay()
	assert_false(_game._choice_overlay.visible)


func test_on_sequence_play_requested_starts_play() -> void:
	var seq = _create_sequence_with_dialogue("Charlie", "Test")
	_game._play_ctrl.on_sequence_play_requested(seq)
	assert_true(_game._sequence_editor_ctrl.is_playing(), "should start playing")
	assert_true(_game._play_overlay.visible, "play overlay should be visible")


func test_stop_current_cleans_up() -> void:
	_game._menu_button.visible = true
	_game._play_overlay.visible = true
	_game._play_ctrl.stop_current()
	assert_false(_game._menu_button.visible, "menu button should be hidden after stop")
	assert_false(_game._play_overlay.visible, "play overlay should be hidden after stop")


func test_stop_and_restart_relaunches_story() -> void:
	var story = _create_minimal_story()
	_game._play_ctrl.stop_and_restart(story)
	assert_true(_game._menu_button.visible, "menu button should be visible after restart")


# --- Helpers ---

func _create_sequence_with_dialogue(character: String, text: String):
	var seq = SequenceScript.new()
	var dlg = DialogueScript.new()
	dlg.character = character
	dlg.text = text
	seq.dialogues.append(dlg)
	return seq


func test_sequence_fx_player_exists() -> void:
	assert_not_null(_game._sequence_fx_player, "sequence_fx_player should exist")


# --- Auto-play ---

func test_auto_play_button_exists() -> void:
	assert_not_null(_game._auto_play_button, "auto play button should exist")
	assert_eq(_game._auto_play_button.text, "Auto")


func test_play_buttons_bar_hidden_by_default() -> void:
	assert_false(_game._play_buttons_bar.visible)


func test_auto_play_button_pressed_toggles_on() -> void:
	_game._auto_play_button.pressed.emit()
	var mgr = _game._play_ctrl.get_auto_play_manager()
	assert_true(mgr.enabled, "auto-play should be enabled after press")
	assert_eq(_game._auto_play_button.text, "Auto [ON]")


func test_auto_play_button_pressed_toggles_off() -> void:
	_game._auto_play_button.pressed.emit()
	_game._auto_play_button.pressed.emit()
	var mgr = _game._play_ctrl.get_auto_play_manager()
	assert_false(mgr.enabled, "auto-play should be disabled after second press")
	assert_eq(_game._auto_play_button.text, "Auto")


func test_auto_play_button_visible_during_play() -> void:
	var story = _create_minimal_story()
	_game._play_ctrl.start_story(story)
	assert_true(_game._auto_play_button.visible, "auto play button should be visible during play")


func _create_minimal_story():
	var story = StoryScript.new()
	story.title = "Test Story"
	var chapter = ChapterScript.new()
	chapter.chapter_name = "Chapter 1"
	var scene = SceneDataScript.new()
	scene.scene_name = "Scene 1"
	var seq = SequenceScript.new()
	seq.seq_name = "Seq 1"
	var dlg = DialogueScript.new()
	dlg.character = "Test"
	dlg.text = "Hello"
	seq.dialogues.append(dlg)
	scene.sequences.append(seq)
	chapter.scenes.append(scene)
	story.chapters.append(chapter)
	return story


# --- Mouse click advance (060) ---

func test_is_advance_input_spacebar() -> void:
	var event = InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_SPACE
	assert_true(_game._play_ctrl._is_advance_input(event), "spacebar should be advance input")


func test_is_advance_input_mouse_left_click() -> void:
	var event = InputEventMouseButton.new()
	event.pressed = true
	event.button_index = MOUSE_BUTTON_LEFT
	assert_true(_game._play_ctrl._is_advance_input(event), "left click should be advance input")


func test_is_advance_input_mouse_right_click_rejected() -> void:
	var event = InputEventMouseButton.new()
	event.pressed = true
	event.button_index = MOUSE_BUTTON_RIGHT
	assert_false(_game._play_ctrl._is_advance_input(event), "right click should not be advance input")


func test_is_advance_input_key_release_rejected() -> void:
	var event = InputEventKey.new()
	event.pressed = false
	event.keycode = KEY_SPACE
	assert_false(_game._play_ctrl._is_advance_input(event), "key release should not be advance input")


func test_is_advance_input_other_key_rejected() -> void:
	var event = InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_A
	assert_false(_game._play_ctrl._is_advance_input(event), "other keys should not be advance input")


func test_mouse_click_ignored_when_choice_visible() -> void:
	var seq = _create_sequence_with_dialogue("Alice", "Hello")
	_game._sequence_editor_ctrl.load_sequence(seq)
	_game._sequence_editor_ctrl.start_play()
	_game._play_ctrl.on_play_dialogue_changed(0)
	# Show all text first
	_game._sequence_editor_ctrl.skip_typewriter()
	_game._play_text_label.visible_characters = _game._sequence_editor_ctrl.get_visible_characters()
	# Make choice overlay visible
	_game._choice_overlay.visible = true
	# Attempt mouse click — should not advance
	var event = InputEventMouseButton.new()
	event.pressed = true
	event.button_index = MOUSE_BUTTON_LEFT
	_game._play_ctrl._input(event)
	# Still playing (not advanced past the only dialogue)
	assert_true(_game._sequence_editor_ctrl.is_playing(), "should still be playing when choice visible")


func test_mouse_click_ignored_when_history_open() -> void:
	var seq = _create_sequence_with_dialogue("Alice", "Hello")
	_game._sequence_editor_ctrl.load_sequence(seq)
	_game._sequence_editor_ctrl.start_play()
	_game._play_ctrl.on_play_dialogue_changed(0)
	_game._sequence_editor_ctrl.skip_typewriter()
	_game._play_text_label.visible_characters = _game._sequence_editor_ctrl.get_visible_characters()
	# Open history
	_game._play_ctrl._history_open = true
	var event = InputEventMouseButton.new()
	event.pressed = true
	event.button_index = MOUSE_BUTTON_LEFT
	_game._play_ctrl._input(event)
	assert_true(_game._sequence_editor_ctrl.is_playing(), "should still be playing when history open")


# --- Choice keyboard navigation (060) ---

const ChoiceScript = preload("res://src/models/choice.gd")

func test_choice_display_first_button_has_focus() -> void:
	var choices = []
	for t in ["Option A", "Option B", "Option C"]:
		var c = ChoiceScript.new()
		c.text = t
		choices.append(c)
	_game._play_ctrl.on_choice_display_requested(choices)
	# Wait one frame for deferred grab_focus
	await get_tree().process_frame
	var vbox = _game._choice_panel.get_child(0)
	# First child is the title label, buttons start at index 1
	var first_btn = vbox.get_child(1)
	assert_true(first_btn.has_focus(), "first choice button should have focus")
	_game._play_ctrl._hide_choice_overlay()


func test_choice_buttons_have_cyclic_focus() -> void:
	var choices = []
	for t in ["Option A", "Option B", "Option C"]:
		var c = ChoiceScript.new()
		c.text = t
		choices.append(c)
	_game._play_ctrl.on_choice_display_requested(choices)
	var vbox = _game._choice_panel.get_child(0)
	var first_btn = vbox.get_child(1)
	var last_btn = vbox.get_child(3)
	# focus_neighbor_top/bottom are set to absolute paths after nodes are in tree
	assert_ne(first_btn.focus_neighbor_top, NodePath(""), "first btn should have top neighbor set")
	assert_ne(last_btn.focus_neighbor_bottom, NodePath(""), "last btn should have bottom neighbor set")
	# Verify they point to each other by resolving the paths
	assert_eq(first_btn.get_node(first_btn.focus_neighbor_top), last_btn, "first btn top should resolve to last btn")
	assert_eq(last_btn.get_node(last_btn.focus_neighbor_bottom), first_btn, "last btn bottom should resolve to first btn")
	_game._play_ctrl._hide_choice_overlay()


# --- Transition out skipped for choices ending ---

const EndingScript = preload("res://src/models/ending.gd")

func test_handle_play_stopped_skips_transition_out_when_choices_ending() -> void:
	var seq = _create_sequence_with_dialogue("Alice", "Hello")
	seq.transition_out_type = "fade"
	seq.transition_out_duration = 1.0
	var ending = EndingScript.new()
	ending.type = "choices"
	var c = ChoiceScript.new()
	c.text = "Go"
	ending.choices.append(c)
	seq.ending = ending
	_game._play_ctrl._current_playing_sequence = seq
	_game._play_ctrl._handle_play_stopped()
	# Le fx_player ne doit PAS avoir de noeud TransFadeOutOverlay
	var fx = _game._sequence_fx_player
	assert_false(fx.is_playing(), "fx player should NOT be playing transition for choices ending")


func test_handle_play_stopped_plays_transition_out_for_auto_redirect() -> void:
	var seq = _create_sequence_with_dialogue("Alice", "Hello")
	seq.transition_out_type = "fade"
	seq.transition_out_duration = 0.5
	var ending = EndingScript.new()
	ending.type = "auto_redirect"
	seq.ending = ending
	_game._play_ctrl._current_playing_sequence = seq
	_game._play_ctrl._handle_play_stopped()
	var fx = _game._sequence_fx_player
	assert_true(fx.is_playing(), "fx player SHOULD play transition for auto_redirect ending")


# --- set_i18n ---

func test_set_i18n_stores_dictionary() -> void:
	var dict = {"hello": "bonjour"}
	_game._play_ctrl.set_i18n(dict)
	assert_eq(_game._play_ctrl._i18n, dict, "i18n dictionary should be stored")


# --- set_typewriter_speed ---

func test_set_typewriter_speed_updates_timer() -> void:
	_game._play_ctrl.set_typewriter_speed(0.05)
	assert_eq(_game._play_ctrl._typewriter_speed, 0.05, "typewriter speed should be updated")
	assert_eq(_game._typewriter_timer.wait_time, 0.05, "timer wait_time should match speed")


func test_set_typewriter_speed_zero_does_not_change_timer() -> void:
	var original_wait = _game._typewriter_timer.wait_time
	_game._play_ctrl.set_typewriter_speed(0.0)
	assert_eq(_game._play_ctrl._typewriter_speed, 0.0, "speed var should be zero")
	assert_eq(_game._typewriter_timer.wait_time, original_wait, "timer should not change for zero speed")


# --- set_dialogue_opacity ---

func test_set_dialogue_opacity_updates_overlay() -> void:
	_game._play_ctrl.set_dialogue_opacity(0.5)
	assert_eq(_game._play_ctrl._dialogue_opacity, 0.5, "opacity var should be updated")
	assert_eq(_game._play_dialogue_panel.self_modulate.a, 0.5, "play dialogue panel alpha should match")


# --- set_toolbar_visible ---

func test_set_toolbar_visible_stores_value() -> void:
	_game._play_ctrl.set_toolbar_visible(false)
	assert_false(_game._play_ctrl._toolbar_visible, "toolbar_visible should be false")
	_game._play_ctrl.set_toolbar_visible(true)
	assert_true(_game._play_ctrl._toolbar_visible, "toolbar_visible should be true")


# --- toolbar toggle button ---

func test_toolbar_toggle_button_exists() -> void:
	assert_not_null(_game._toolbar_toggle_button, "toolbar toggle button should exist")
	assert_is(_game._toolbar_toggle_button, Button)


func test_toggle_button_click_shows_toolbar() -> void:
	_game._play_ctrl.set_toolbar_visible(false)
	_game._play_ctrl._on_toolbar_toggle_pressed()
	assert_true(_game._play_ctrl._toolbar_visible, "toolbar should be visible after toggle")


func test_toggle_button_click_hides_toolbar() -> void:
	_game._play_ctrl.set_toolbar_visible(true)
	_game._play_ctrl._on_toolbar_toggle_pressed()
	assert_false(_game._play_ctrl._toolbar_visible, "toolbar should be hidden after toggle")


func test_toggle_button_updates_icon_when_visible() -> void:
	_game._play_ctrl.set_toolbar_visible(false)
	_game._play_ctrl._on_toolbar_toggle_pressed()
	assert_eq(_game._toolbar_toggle_button.text, "", "button should use icon, not text")
	assert_not_null(_game._toolbar_toggle_button.icon, "should have an icon when toolbar visible")


func test_toggle_button_updates_icon_when_hidden() -> void:
	_game._play_ctrl.set_toolbar_visible(true)
	_game._play_ctrl._on_toolbar_toggle_pressed()
	assert_eq(_game._toolbar_toggle_button.text, "", "button should use icon, not text")
	assert_not_null(_game._toolbar_toggle_button.icon, "should have an icon when toolbar hidden")


func test_toggle_updates_play_buttons_bar_visibility() -> void:
	_game._play_ctrl.set_toolbar_visible(false)
	_game._play_ctrl._on_toolbar_toggle_pressed()
	assert_true(_game._play_buttons_bar.visible, "bar should be visible after toggle on")
	_game._play_ctrl._on_toolbar_toggle_pressed()
	assert_false(_game._play_buttons_bar.visible, "bar should be hidden after toggle off")


func test_set_toolbar_visible_does_not_change_bar_visibility() -> void:
	_game._play_buttons_bar.visible = false
	_game._play_ctrl.set_toolbar_visible(true)
	assert_false(_game._play_buttons_bar.visible, "set_toolbar_visible should not show bar directly")


func test_toggle_emits_toolbar_toggled_signal() -> void:
	watch_signals(_game._play_ctrl)
	_game._play_ctrl._on_toolbar_toggle_pressed()
	assert_signal_emitted(_game._play_ctrl, "toolbar_toggled")


# --- is_scene_available (static, pure logic) ---

func test_is_scene_available_returns_false_when_no_progression() -> void:
	assert_false(
		GamePlayControllerScript.is_scene_available(0, 0, -1, -1),
		"should return false when max_ch_idx is negative"
	)


func test_is_scene_available_same_chapter_within_range() -> void:
	assert_true(
		GamePlayControllerScript.is_scene_available(1, 2, 1, 3),
		"scene within same chapter range should be available"
	)


func test_is_scene_available_same_chapter_beyond_range() -> void:
	assert_false(
		GamePlayControllerScript.is_scene_available(1, 4, 1, 3),
		"scene beyond max in same chapter should not be available"
	)


func test_is_scene_available_earlier_chapter() -> void:
	assert_true(
		GamePlayControllerScript.is_scene_available(0, 99, 1, 0),
		"any scene in earlier chapter should be available"
	)


func test_is_scene_available_later_chapter() -> void:
	assert_false(
		GamePlayControllerScript.is_scene_available(2, 0, 1, 5),
		"scene in later chapter should not be available"
	)


# --- format_history_entry (static, pure logic) ---

func test_format_history_entry_with_character_and_text() -> void:
	assert_eq(
		GamePlayControllerScript.format_history_entry("Alice", "Hello"),
		"Alice : Hello"
	)


func test_format_history_entry_empty_character() -> void:
	assert_eq(
		GamePlayControllerScript.format_history_entry("", "Narration text"),
		"Narration text"
	)


func test_format_history_entry_both_empty() -> void:
	assert_eq(
		GamePlayControllerScript.format_history_entry("", ""),
		""
	)


# --- add_history_entry / reset_history ---

func test_add_history_entry_appends_to_history() -> void:
	_game._play_ctrl.reset_history()
	_game._play_ctrl.add_history_entry("Bob", "Salut")
	_game._play_ctrl.add_history_entry("Alice", "Hey")
	var hist = _game._play_ctrl._dialogue_history
	assert_eq(hist.size(), 2, "should have 2 entries")
	assert_eq(hist[0]["character"], "Bob")
	assert_eq(hist[1]["text"], "Hey")


func test_reset_history_clears_entries() -> void:
	_game._play_ctrl.add_history_entry("Test", "Entry")
	_game._play_ctrl.reset_history()
	assert_eq(_game._play_ctrl._dialogue_history.size(), 0, "history should be empty after reset")


# --- set_skip_progression ---

func test_set_skip_progression_stores_indices() -> void:
	_game._play_ctrl.set_skip_progression(3, 7)
	assert_eq(_game._play_ctrl._skip_max_chapter_index, 3)
	assert_eq(_game._play_ctrl._skip_max_scene_index, 7)


# --- set_auto_play_delay ---

func test_set_auto_play_delay_updates_manager() -> void:
	_game._play_ctrl.set_auto_play_delay(5.0)
	var mgr = _game._play_ctrl.get_auto_play_manager()
	assert_eq(mgr.delay, 5.0, "auto play delay should be updated")


# --- toggle_auto_play ---

func test_toggle_auto_play_toggles_manager() -> void:
	var mgr = _game._play_ctrl.get_auto_play_manager()
	assert_false(mgr.enabled, "auto play should start disabled")
	_game._play_ctrl.toggle_auto_play()
	assert_true(mgr.enabled, "auto play should be enabled after toggle")
	_game._play_ctrl.toggle_auto_play()
	assert_false(mgr.enabled, "auto play should be disabled after second toggle")


# --- on_play_finished with _user_stopped guard ---

func test_on_play_finished_returns_early_when_user_stopped() -> void:
	_game._play_ctrl._user_stopped = true
	# Should not crash or show dialog — just return
	_game._play_ctrl.on_play_finished("completed")
	_game._play_ctrl._user_stopped = false
	pass_test("on_play_finished should return early when user_stopped is true")


# --- set_auto_play_enabled ---

func test_set_auto_play_enabled_toggles_on() -> void:
	var mgr = _game._play_ctrl.get_auto_play_manager()
	assert_false(mgr.enabled, "should start disabled")
	_game._play_ctrl.set_auto_play_enabled(true)
	assert_true(mgr.enabled, "should be enabled after set_auto_play_enabled(true)")


func test_set_auto_play_enabled_no_change_when_already_matching() -> void:
	var mgr = _game._play_ctrl.get_auto_play_manager()
	_game._play_ctrl.set_auto_play_enabled(false)
	assert_false(mgr.enabled, "should remain disabled when already disabled")


# --- Auto-play waits for voice ---

func test_try_start_auto_play_waits_for_voice() -> void:
	var mgr = _game._play_ctrl.get_auto_play_manager()
	mgr.toggle()
	mgr.delay = 0.1
	# Simulate voice playing
	_game._play_ctrl._voice_player.stream = AudioStreamGenerator.new()
	_game._play_ctrl._voice_player.play()
	watch_signals(mgr)
	_game._play_ctrl._try_start_auto_play_timer()
	# Timer should NOT have started yet (voice is playing)
	assert_true(_game._play_ctrl._voice_auto_play_connected, "should be waiting for voice")
	_game._play_ctrl._voice_player.stop()
	_game._play_ctrl._cancel_voice_auto_play_wait()


func test_try_start_auto_play_immediate_when_no_voice() -> void:
	var mgr = _game._play_ctrl.get_auto_play_manager()
	mgr.toggle()
	mgr.delay = 0.1
	# No voice playing — timer should start immediately
	watch_signals(mgr)
	_game._play_ctrl._try_start_auto_play_timer()
	assert_false(_game._play_ctrl._voice_auto_play_connected, "should not wait for voice")
	await get_tree().create_timer(0.2).timeout
	assert_signal_emitted(mgr, "auto_advance_requested")


func test_cancel_voice_auto_play_wait_disconnects() -> void:
	var mgr = _game._play_ctrl.get_auto_play_manager()
	mgr.toggle()
	# Simulate voice playing and connect
	_game._play_ctrl._voice_player.stream = AudioStreamGenerator.new()
	_game._play_ctrl._voice_player.play()
	_game._play_ctrl._try_start_auto_play_timer()
	assert_true(_game._play_ctrl._voice_auto_play_connected)
	# Cancel should disconnect
	_game._play_ctrl._cancel_voice_auto_play_wait()
	assert_false(_game._play_ctrl._voice_auto_play_connected)
	_game._play_ctrl._voice_player.stop()


func test_on_play_dialogue_changed_cancels_voice_wait() -> void:
	var mgr = _game._play_ctrl.get_auto_play_manager()
	mgr.toggle()
	var seq = _create_sequence_with_dialogue("Alice", "Hello")
	_game._sequence_editor_ctrl.load_sequence(seq)
	_game._sequence_editor_ctrl.start_play()
	# Simulate voice playing and waiting
	_game._play_ctrl._voice_player.stream = AudioStreamGenerator.new()
	_game._play_ctrl._voice_player.play()
	_game._play_ctrl._try_start_auto_play_timer()
	assert_true(_game._play_ctrl._voice_auto_play_connected)
	# Changing dialogue should cancel the wait
	_game._play_ctrl.on_play_dialogue_changed(0)
	assert_false(_game._play_ctrl._voice_auto_play_connected)
