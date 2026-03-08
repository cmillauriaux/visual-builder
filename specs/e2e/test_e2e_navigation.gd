extends GutTest

## Tests e2e — Navigation complète dans l'éditeur.

const MainScript = preload("res://src/main.gd")

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


func test_navigate_down_and_back():
	_navigate_to_sequence_edit()
	assert_eq(_main._editor_main.get_current_level(), "sequence_edit")
	assert_true(_main._sequence_editor_panel.visible)

	# Back → sequences
	_main._nav_ctrl.on_back_pressed()
	assert_eq(_main._editor_main.get_current_level(), "sequences")
	assert_true(_main._sequence_graph_view.visible)

	# Back → scenes
	_main._nav_ctrl.on_back_pressed()
	assert_eq(_main._editor_main.get_current_level(), "scenes")
	assert_true(_main._scene_graph_view.visible)

	# Back → chapters
	_main._nav_ctrl.on_back_pressed()
	assert_eq(_main._editor_main.get_current_level(), "chapters")
	assert_true(_main._chapter_graph_view.visible)


func test_breadcrumb_navigation():
	_navigate_to_sequence_edit()
	assert_eq(_main._editor_main.get_current_level(), "sequence_edit")

	# Breadcrumb clic index 2 → retour aux séquences
	_main._nav_ctrl.on_breadcrumb_clicked(2)
	assert_eq(_main._editor_main.get_current_level(), "sequences")
	assert_true(_main._sequence_graph_view.visible)

	# Breadcrumb clic index 0 → retour aux chapitres
	_main._nav_ctrl.on_breadcrumb_clicked(0)
	assert_eq(_main._editor_main.get_current_level(), "chapters")
	assert_true(_main._chapter_graph_view.visible)


func test_breadcrumb_shows_correct_path():
	_navigate_to_sequence_edit()
	var path = _main._editor_main.get_breadcrumb_path()
	assert_eq(path.size(), 4, "Path should have 4 levels: story, chapter, scene, sequence")
	assert_eq(path[0], "Mon Histoire")
	assert_eq(path[1], "Chapitre 1")
	assert_eq(path[2], "Scène 1")
	assert_eq(path[3], "Séquence 1")


func test_welcome_screen_to_editor():
	# Au démarrage, welcome screen visible
	assert_true(_main._welcome_screen.visible, "Welcome screen should be visible initially")
	assert_false(_main._chapter_graph_view.visible, "Chapter view should be hidden initially")

	# Créer une histoire
	_main._nav_ctrl.on_new_story_pressed()
	assert_false(_main._welcome_screen.visible, "Welcome screen should be hidden after new story")
	assert_true(_main._chapter_graph_view.visible, "Chapter view should be visible after new story")


func test_navigate_condition_and_back():
	_main._nav_ctrl.on_new_story_pressed()
	var ch_uuid = _main._editor_main._story.chapters[0].uuid
	_main._nav_ctrl.on_chapter_double_clicked(ch_uuid)
	var sc_uuid = _main._editor_main._current_chapter.scenes[0].uuid
	_main._nav_ctrl.on_scene_double_clicked(sc_uuid)

	# Créer et naviguer dans une condition
	_main._nav_ctrl.on_create_condition_pressed()
	var cond_uuid = _main._editor_main._current_scene.conditions[0].uuid
	_main._nav_ctrl.on_condition_double_clicked(cond_uuid)
	assert_eq(_main._editor_main.get_current_level(), "condition_edit")
	assert_true(_main._condition_editor_panel.visible)

	# Back → séquences
	_main._nav_ctrl.on_back_pressed()
	assert_eq(_main._editor_main.get_current_level(), "sequences")
	assert_true(_main._sequence_graph_view.visible)
