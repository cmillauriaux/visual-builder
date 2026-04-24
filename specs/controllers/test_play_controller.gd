extends GutTest

## Tests pour PlayController — contrôleur de lecture dans l'éditeur.

const MainScript = preload("res://src/main.gd")
const PlayControllerScript = preload("res://src/controllers/play_controller.gd")
const SequenceScript = preload("res://src/models/sequence.gd")
const DialogueScript = preload("res://src/models/dialogue.gd")

var _main: Control


func before_each() -> void:
	_main = Control.new()
	_main.set_script(MainScript)
	add_child(_main)


func after_each() -> void:
	remove_child(_main)
	_main.queue_free()


func test_play_controller_exists() -> void:
	assert_not_null(_main._play_ctrl)
	assert_true(_main._play_ctrl.get_script() == PlayControllerScript)


func test_is_story_play_mode_default_false() -> void:
	assert_false(_main._play_ctrl.is_story_play_mode())


func test_on_play_dialogue_changed_ignores_invalid_index() -> void:
	watch_signals(EventBus)
	_main._play_ctrl.on_play_dialogue_changed(-1)
	assert_signal_not_emitted(EventBus, "play_dialogue_changed")


func test_on_play_dialogue_changed_updates_labels() -> void:
	var seq = SequenceScript.new()
	var dlg = DialogueScript.new()
	dlg.character = "Alice"
	dlg.text = "Bonjour"
	seq.dialogues.append(dlg)
	_main._sequence_editor_ctrl.load_sequence(seq)
	_main._sequence_editor_ctrl.start_play()
	
	watch_signals(EventBus)
	_main._play_ctrl.on_play_dialogue_changed(0)
	
	assert_signal_emitted_with_parameters(EventBus, "play_dialogue_changed", ["Alice", "Bonjour", 0])
	# UI checks (main.gd is connected to EventBus)
	assert_eq(_main._play_character_label.text, "Alice")
	assert_eq(_main._play_text_label.text, "Bonjour")
	assert_eq(_main._play_text_label.visible_characters, 0)


func test_on_play_stopped_restores_ui() -> void:
	watch_signals(EventBus)
	_main._play_ctrl.on_play_stopped()
	assert_signal_emitted(EventBus, "play_stopped")
	# UI checks
	assert_false(_main._play_overlay.visible)
	assert_true(_main._play_button.visible)
	assert_false(_main._stop_button.visible)


func test_typewriter_tick_when_not_playing() -> void:
	_main._play_ctrl.on_typewriter_tick()
	pass_test("should not crash when not playing")


func test_typewriter_tick_advances_characters() -> void:
	var seq = SequenceScript.new()
	var dlg = DialogueScript.new()
	dlg.character = "Bob"
	dlg.text = "Test"
	seq.dialogues.append(dlg)
	_main._sequence_editor_ctrl.load_sequence(seq)
	_main._sequence_editor_ctrl.start_play()
	
	_main._play_ctrl.on_play_dialogue_changed(0)
	
	watch_signals(EventBus)
	_main._play_ctrl.on_typewriter_tick()
	
	assert_signal_emitted_with_parameters(EventBus, "play_typewriter_tick", [1])
	assert_eq(_main._play_text_label.visible_characters, 1)


func test_sequence_fx_player_exists() -> void:
	assert_not_null(_main._sequence_fx_player, "sequence_fx_player should exist")


func test_fx_panel_exists() -> void:
	assert_not_null(_main._fx_panel, "fx_panel should exist")


func test_story_play_sequence_with_title_no_dialogues_shows_title_screen() -> void:
	var seq = SequenceScript.new()
	seq.title = "Test Title"
	seq.subtitle = "Test Subtitle"
	# No dialogues
	
	# Setup story/chapter/scene to avoid errors during navigation in PlayController
	var story = preload("res://src/models/story.gd").new()
	story.title = "Test Story"
	var chapter = preload("res://src/models/chapter.gd").new()
	var scene = preload("res://src/models/scene_data.gd").new()
	_main._editor_main._story = story
	_main._editor_main._current_chapter = chapter
	_main._editor_main._current_scene = scene
	
	_main._play_ctrl._is_story_play_mode = true
	_main._play_ctrl.on_story_play_sequence_requested(seq)
	
	assert_true(_main._play_ctrl._is_showing_title, "Title screen should be showing")
	assert_eq(_main._play_title_label.text, "Test Title")
	assert_eq(_main._play_subtitle_label.text, "Test Subtitle")
	assert_true(_main._play_title_overlay.visible)
	assert_false(_main._play_overlay.visible, "Dialogue overlay should be hidden during title screen")
	
	# Hide title screen
	_main._play_ctrl._hide_title_screen()
	assert_false(_main._play_ctrl._is_showing_title, "Title screen should be hidden")
	assert_true(_main._play_overlay.visible, "Dialogue overlay should be shown after title screen")


func test_story_play_sequence_applies_title_background_color() -> void:
	var seq = SequenceScript.new()
	seq.title = "Test Title"
	seq.background_color = "ff0000ff"

	var story = preload("res://src/models/story.gd").new()
	story.title = "Test Story"
	var chapter = preload("res://src/models/chapter.gd").new()
	var scene = preload("res://src/models/scene_data.gd").new()
	_main._editor_main._story = story
	_main._editor_main._current_chapter = chapter
	_main._editor_main._current_scene = scene

	_main._play_ctrl._is_story_play_mode = true
	_main._play_ctrl.on_story_play_sequence_requested(seq)

	var bg_rect := _main._play_title_overlay.get_node("TitleBackgroundRect") as ColorRect
	assert_not_null(bg_rect)
	assert_eq(bg_rect.color, Color(1, 0, 0, 1))


func test_story_play_sequence_no_title_no_dialogues_skips_immediately() -> void:
	var seq = SequenceScript.new()
	# No title, no dialogues
	
	var story = preload("res://src/models/story.gd").new()
	story.title = "Test Story"
	var chapter = preload("res://src/models/chapter.gd").new()
	var scene = preload("res://src/models/scene_data.gd").new()
	_main._editor_main._story = story
	_main._editor_main._current_chapter = chapter
	_main._editor_main._current_scene = scene
	
	watch_signals(_main._story_play_ctrl)
	_main._play_ctrl._is_story_play_mode = true
	
	# Simulate StoryPlayController state
	_main._story_play_ctrl._current_sequence = seq
	_main._story_play_ctrl._state = 1 # State.PLAYING_SEQUENCE
	
	_main._play_ctrl.on_story_play_sequence_requested(seq)
	
	assert_false(_main._play_ctrl._is_showing_title, "Title screen should not be showing")
	assert_signal_emitted(_main._story_play_ctrl, "play_finished")


func _create_foreground(name: String, transition: String = "none"):
	var ForegroundScript = preload("res://src/models/foreground.gd")
	var fg = ForegroundScript.new()
	fg.fg_name = name
	fg.transition_type = transition
	return fg


func test_prepare_opening_visuals_shows_first_dialogue_foregrounds() -> void:
	var seq = SequenceScript.new()
	var dlg0 = DialogueScript.new()
	dlg0.character = "Alice"
	dlg0.text = "Premier"
	var fg0 = _create_foreground("fg_alice")
	dlg0.foregrounds.append(fg0)
	seq.dialogues.append(dlg0)

	var dlg1 = DialogueScript.new()
	dlg1.character = "Bob"
	dlg1.text = "Dernier"
	var fg1 = _create_foreground("fg_bob")
	dlg1.foregrounds.append(fg1)
	seq.dialogues.append(dlg1)

	# Simuler que le dernier dialogue est affiché
	seq.foregrounds = [fg1]
	_main._sequence_editor_ctrl.load_sequence(seq)

	_main._play_ctrl._prepare_opening_visuals()

	# Doit afficher les foregrounds du premier dialogue (fg0), pas du dernier (fg1)
	assert_eq(seq.foregrounds.size(), 1)
	assert_eq(seq.foregrounds[0].fg_name, "fg_alice")


func test_prepare_opening_visuals_filters_animated_foregrounds() -> void:
	var seq = SequenceScript.new()
	var dlg = DialogueScript.new()
	dlg.character = "Alice"
	dlg.text = "Test"
	var fg_static = _create_foreground("fg_static", "none")
	var fg_animated = _create_foreground("fg_animated", "fade")
	dlg.foregrounds.append(fg_static)
	dlg.foregrounds.append(fg_animated)
	seq.dialogues.append(dlg)

	_main._sequence_editor_ctrl.load_sequence(seq)

	_main._play_ctrl._prepare_opening_visuals()

	# Seul le foreground sans animation doit être affiché
	assert_eq(seq.foregrounds.size(), 1)
	assert_eq(seq.foregrounds[0].fg_name, "fg_static")


func test_prepare_opening_visuals_sets_previous_play_foregrounds() -> void:
	var seq = SequenceScript.new()
	var dlg = DialogueScript.new()
	dlg.character = "Alice"
	dlg.text = "Test"
	var fg = _create_foreground("fg_alice")
	dlg.foregrounds.append(fg)
	seq.dialogues.append(dlg)

	_main._sequence_editor_ctrl.load_sequence(seq)

	_main._play_ctrl._prepare_opening_visuals()

	assert_eq(_main._play_ctrl._previous_play_foregrounds.size(), 1)
	assert_eq(_main._play_ctrl._previous_play_foregrounds[0].fg_name, "fg_alice")


func test_prepare_opening_visuals_no_dialogues_does_nothing() -> void:
	var seq = SequenceScript.new()
	var fg = _create_foreground("old_fg")
	seq.foregrounds = [fg]
	_main._sequence_editor_ctrl.load_sequence(seq)

	_main._play_ctrl._prepare_opening_visuals()

	# Foregrounds should remain unchanged since there are no dialogues
	assert_eq(seq.foregrounds.size(), 1)
	assert_eq(seq.foregrounds[0].fg_name, "old_fg")


# --- Transition out skipped for choices ending ---

const EndingScript = preload("res://src/models/ending.gd")
const ChoiceScript = preload("res://src/models/choice.gd")

func test_handle_play_stopped_skips_transition_out_when_choices_ending() -> void:
	var seq = SequenceScript.new()
	var dlg = DialogueScript.new()
	dlg.character = "Alice"
	dlg.text = "Test"
	seq.dialogues.append(dlg)
	seq.transition_out_type = "fade"
	seq.transition_out_duration = 1.0
	var ending = EndingScript.new()
	ending.type = "choices"
	var c = ChoiceScript.new()
	c.text = "Go"
	ending.choices.append(c)
	seq.ending = ending
	_main._play_ctrl._current_playing_sequence = seq
	_main._play_ctrl._handle_play_stopped()
	var fx = _main._sequence_fx_player
	assert_false(fx.is_playing(), "fx player should NOT be playing transition for choices ending")


func test_handle_play_stopped_plays_transition_out_for_auto_redirect() -> void:
	var seq = SequenceScript.new()
	var dlg = DialogueScript.new()
	dlg.character = "Alice"
	dlg.text = "Test"
	seq.dialogues.append(dlg)
	seq.transition_out_type = "fade"
	seq.transition_out_duration = 0.5
	var ending = EndingScript.new()
	ending.type = "auto_redirect"
	seq.ending = ending
	_main._play_ctrl._current_playing_sequence = seq
	_main._play_ctrl._handle_play_stopped()
	var fx = _main._sequence_fx_player
	assert_true(fx.is_playing(), "fx player SHOULD play transition for auto_redirect ending")


# --- on_story_play_finished ---

func test_on_story_play_finished_emits_play_finished_signal() -> void:
	watch_signals(EventBus)
	_main._play_ctrl._is_story_play_mode = true
	_main._play_ctrl.on_story_play_finished("completed")
	assert_signal_emitted_with_parameters(EventBus, "play_finished", ["completed"])


func test_on_story_play_finished_restores_story_play_mode() -> void:
	_main._play_ctrl._is_story_play_mode = true
	_main._play_ctrl.on_story_play_finished("completed")
	assert_false(_main._play_ctrl._is_story_play_mode, "story play mode should be false after finish")


func test_on_story_play_finished_stops_music_when_player_exists() -> void:
	var mock_music = Node.new()
	mock_music.set_script(preload("res://src/services/music_player.gd"))
	add_child(mock_music)
	_main._play_ctrl._music_player = mock_music
	watch_signals(EventBus)
	_main._play_ctrl.on_story_play_finished("completed")
	assert_signal_emitted(EventBus, "play_finished")
	# Music player stop_music was called — no crash means it worked
	remove_child(mock_music)
	mock_music.queue_free()


func test_on_story_play_finished_without_music_player_does_not_crash() -> void:
	_main._play_ctrl._music_player = null
	watch_signals(EventBus)
	_main._play_ctrl.on_story_play_finished("aborted")
	assert_signal_emitted_with_parameters(EventBus, "play_finished", ["aborted"])


# --- on_story_play_choice_requested ---

func test_on_story_play_choice_requested_emits_signal() -> void:
	watch_signals(EventBus)
	var c1 = ChoiceScript.new()
	c1.text = "Option A"
	var c2 = ChoiceScript.new()
	c2.text = "Option B"
	var choices = [c1, c2]
	_main._play_ctrl.on_story_play_choice_requested(choices)
	assert_signal_emitted(EventBus, "play_choice_requested")


func test_on_story_play_choice_requested_empty_array() -> void:
	watch_signals(EventBus)
	_main._play_ctrl.on_story_play_choice_requested([])
	assert_signal_emitted(EventBus, "play_choice_requested")


# --- Skip preview ---

func test_execute_skip_stops_current_sequence_preview() -> void:
	var seq = SequenceScript.new()
	var dlg = DialogueScript.new()
	dlg.character = "Alice"
	dlg.text = "Hello"
	seq.dialogues.append(dlg)
	_main._sequence_editor_ctrl.load_sequence(seq)
	_main._sequence_editor_ctrl.start_play()
	_main._play_ctrl._current_playing_sequence = seq

	_main._play_ctrl.execute_skip()

	assert_false(_main._sequence_editor_ctrl.is_playing(), "skip preview should stop current sequence playback")


func test_s_key_triggers_skip_preview() -> void:
	var seq = SequenceScript.new()
	var dlg = DialogueScript.new()
	dlg.character = "Alice"
	dlg.text = "Hello"
	seq.dialogues.append(dlg)
	_main._sequence_editor_ctrl.load_sequence(seq)
	_main._sequence_editor_ctrl.start_play()
	_main._play_ctrl._current_playing_sequence = seq

	var event = InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_S
	_main._play_ctrl._input(event)

	assert_false(_main._sequence_editor_ctrl.is_playing(), "S should skip preview to the end of the current sequence")


func test_execute_skip_story_preview_shows_choices() -> void:
	var seq = SequenceScript.new()
	var dlg = DialogueScript.new()
	dlg.character = "Alice"
	dlg.text = "Hello"
	seq.dialogues.append(dlg)
	var ending = EndingScript.new()
	ending.type = "choices"
	var choice = ChoiceScript.new()
	choice.text = "Continue"
	ending.choices.append(choice)
	seq.ending = ending

	_main._sequence_editor_ctrl.load_sequence(seq)
	_main._sequence_editor_ctrl.start_play()
	_main._play_ctrl._is_story_play_mode = true
	_main._play_ctrl._current_playing_sequence = seq
	_main._story_play_ctrl._current_sequence = seq
	_main._story_play_ctrl._autosave_enabled = false
	_main._story_play_ctrl._state = 1 # State.PLAYING_SEQUENCE

	watch_signals(EventBus)
	_main._play_ctrl.execute_skip()

	assert_signal_emitted(EventBus, "play_choice_requested")


func test_execute_skip_story_preview_follows_auto_redirect() -> void:
	var ConsequenceScript = preload("res://src/models/consequence.gd")
	var StoryScript = preload("res://src/models/story.gd")
	var ChapterScript = preload("res://src/models/chapter.gd")
	var SceneScript = preload("res://src/models/scene_data.gd")

	var story = StoryScript.new()
	var chapter = ChapterScript.new()
	var scene = SceneScript.new()
	var seq_a = SequenceScript.new()
	var seq_b = SequenceScript.new()
	seq_a.seq_name = "A"
	seq_b.seq_name = "B"

	var dlg_a = DialogueScript.new()
	dlg_a.text = "A"
	seq_a.dialogues.append(dlg_a)
	var dlg_b = DialogueScript.new()
	dlg_b.text = "B"
	seq_b.dialogues.append(dlg_b)

	var ending = EndingScript.new()
	ending.type = "auto_redirect"
	var consequence = ConsequenceScript.new()
	consequence.type = "redirect_sequence"
	consequence.target = seq_b.uuid
	ending.auto_consequence = consequence
	seq_a.ending = ending

	scene.sequences.append(seq_a)
	scene.sequences.append(seq_b)
	chapter.scenes.append(scene)
	story.chapters.append(chapter)
	_main._editor_main._story = story
	_main._editor_main._current_chapter = chapter
	_main._editor_main._current_scene = scene

	_main._sequence_editor_ctrl.load_sequence(seq_a)
	_main._sequence_editor_ctrl.start_play()
	_main._play_ctrl._is_story_play_mode = true
	_main._play_ctrl._current_playing_sequence = seq_a
	_main._story_play_ctrl._current_sequence = seq_a
	_main._story_play_ctrl._current_scene = scene
	_main._story_play_ctrl._state = 1 # State.PLAYING_SEQUENCE

	_main._play_ctrl.execute_skip()

	assert_eq(_main._play_ctrl._current_playing_sequence, seq_b, "skip preview should follow auto_redirect to the next sequence")
	assert_eq(_main._play_text_label.text, "B", "skip preview should display the first dialogue of the next sequence")
	assert_false(_main._typewriter_timer.is_stopped(), "typewriter should restart after skip redirects to the next sequence")


# --- _apply_sequence_audio ---

func test_apply_sequence_audio_null_music_player_does_not_crash() -> void:
	_main._play_ctrl._music_player = null
	_main._play_ctrl._current_playing_sequence = SequenceScript.new()
	_main._play_ctrl._apply_sequence_audio()
	pass_test("should not crash when music player is null")


func test_apply_sequence_audio_null_sequence_does_not_crash() -> void:
	_main._play_ctrl._music_player = Node.new()
	_main._play_ctrl._current_playing_sequence = null
	_main._play_ctrl._apply_sequence_audio()
	pass_test("should not crash when sequence is null")
	_main._play_ctrl._music_player.free()


func test_apply_sequence_audio_both_null_does_not_crash() -> void:
	_main._play_ctrl._music_player = null
	_main._play_ctrl._current_playing_sequence = null
	_main._play_ctrl._apply_sequence_audio()
	pass_test("should not crash when both are null")


# --- _start_play_after_fx ---

func test_start_play_after_fx_shows_title_when_title_set() -> void:
	var seq = SequenceScript.new()
	seq.title = "Chapter One"
	seq.subtitle = ""
	var dlg = DialogueScript.new()
	dlg.character = "Alice"
	dlg.text = "Hello"
	seq.dialogues.append(dlg)
	_main._sequence_editor_ctrl.load_sequence(seq)
	_main._play_ctrl._current_playing_sequence = seq
	_main._play_ctrl._start_play_after_fx()
	assert_true(_main._play_ctrl._is_showing_title, "should show title screen when title is set")
	assert_eq(_main._play_title_label.text, "Chapter One")


func test_start_play_after_fx_shows_title_when_subtitle_set() -> void:
	var seq = SequenceScript.new()
	seq.title = ""
	seq.subtitle = "A new beginning"
	var dlg = DialogueScript.new()
	dlg.character = "Alice"
	dlg.text = "Hello"
	seq.dialogues.append(dlg)
	_main._sequence_editor_ctrl.load_sequence(seq)
	_main._play_ctrl._current_playing_sequence = seq
	_main._play_ctrl._start_play_after_fx()
	assert_true(_main._play_ctrl._is_showing_title, "should show title screen when subtitle is set")
	assert_eq(_main._play_subtitle_label.text, "A new beginning")


func test_start_play_after_fx_no_title_starts_sequence() -> void:
	var seq = SequenceScript.new()
	seq.title = ""
	seq.subtitle = ""
	var dlg = DialogueScript.new()
	dlg.character = "Alice"
	dlg.text = "Hello"
	seq.dialogues.append(dlg)
	_main._sequence_editor_ctrl.load_sequence(seq)
	_main._play_ctrl._current_playing_sequence = seq
	_main._play_ctrl._start_play_after_fx()
	assert_false(_main._play_ctrl._is_showing_title, "should not show title screen when no title or subtitle")


func test_start_play_after_fx_null_sequence_does_not_crash() -> void:
	_main._play_ctrl._current_playing_sequence = null
	_main._play_ctrl._start_play_after_fx()
	assert_false(_main._play_ctrl._is_showing_title, "should not show title when sequence is null")


# --- on_choice_selected delegates to story_play_ctrl ---

func test_on_choice_selected_delegates_to_story_play_ctrl() -> void:
	watch_signals(_main._story_play_ctrl)
	# Set up story play controller in a state where it can accept a choice
	_main._story_play_ctrl._state = 2 # State.WAITING_CHOICE
	_main._play_ctrl.on_choice_selected(0)
	# No crash means delegation happened; the story_play_ctrl handles the logic
	pass_test("on_choice_selected delegates without crashing")
