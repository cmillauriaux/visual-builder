extends GutTest

## Tests e2e — Play depuis l'éditeur (séquence et story).

const MainScript = preload("res://src/main.gd")
const E2eStoryBuilder = preload("res://specs/e2e/e2e_story_builder.gd")

var _main: Control


func before_each():
	_main = Control.new()
	_main.set_script(MainScript)
	add_child(_main)
	await get_tree().process_frame


func after_each():
	if _main:
		_main.queue_free()
		_main = null


func _navigate_to_sequence_edit() -> void:
	_main._nav_ctrl.on_new_story_pressed()
	var ch_uuid = _main._editor_main._story.chapters[0].uuid
	_main._nav_ctrl.on_chapter_double_clicked(ch_uuid)
	var sc_uuid = _main._editor_main._current_chapter.scenes[0].uuid
	_main._nav_ctrl.on_scene_double_clicked(sc_uuid)
	var seq_uuid = _main._editor_main._current_scene.sequences[0].uuid
	_main._nav_ctrl.on_sequence_double_clicked(seq_uuid)


func test_play_sequence_and_stop():
	_navigate_to_sequence_edit()
	assert_eq(_main._editor_main.get_current_level(), "sequence_edit")

	# Lancer le play de la séquence
	_main._play_ctrl.on_play_pressed()
	assert_true(_main._sequence_editor_ctrl.is_playing(), "Should be playing")

	# Vérifier que le dialogue est affiché
	_main._play_ctrl.on_play_dialogue_changed(0)
	var seq = _main._sequence_editor_ctrl.get_sequence()
	assert_eq(seq.dialogues[0].character, "Narrateur")

	# Arrêter
	_main._play_ctrl.on_stop_pressed()
	assert_false(_main._sequence_editor_ctrl.is_playing(), "Should have stopped")


func test_play_story_from_chapter_level():
	# Charger une story branchante
	var story = E2eStoryBuilder.make_branching_story()
	_main._undo_redo.clear()
	_main._editor_main.open_story(story)
	_main.refresh_current_view()
	assert_eq(_main._editor_main.get_current_level(), "chapters")

	# Lancer le play story depuis les chapitres
	_main._play_ctrl.on_top_play_pressed()
	assert_true(_main._play_ctrl.is_story_play_mode(), "Should be in story play mode")
	assert_eq(_main._story_play_ctrl.get_state(), _main._story_play_ctrl.State.PLAYING_SEQUENCE)

	# Vérifier qu'on joue la séquence Intro (entry point)
	var current_seq = _main._story_play_ctrl.get_current_sequence()
	assert_eq(current_seq.seq_name, "Intro")

	# Arrêter le play
	_main._play_ctrl.on_top_stop_pressed()
	assert_false(_main._play_ctrl.is_story_play_mode(), "Should have exited story play mode")
	assert_eq(_main._editor_main.get_current_level(), "chapters", "Should return to chapters")
