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
	var story = load("res://src/models/story.gd").new()
	story.title = "Test Story"
	var chapter = load("res://src/models/chapter.gd").new()
	var scene = load("res://src/models/scene_data.gd").new()
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


func test_story_play_sequence_no_title_no_dialogues_skips_immediately() -> void:
	var seq = SequenceScript.new()
	# No title, no dialogues
	
	var story = load("res://src/models/story.gd").new()
	story.title = "Test Story"
	var chapter = load("res://src/models/chapter.gd").new()
	var scene = load("res://src/models/scene_data.gd").new()
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
	var ForegroundScript = load("res://src/models/foreground.gd")
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
