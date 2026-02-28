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
	_game._choice_overlay.add_child(child)
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
