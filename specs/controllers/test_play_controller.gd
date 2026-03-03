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
