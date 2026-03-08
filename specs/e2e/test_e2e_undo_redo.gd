extends GutTest

## Tests e2e — Undo/Redo à travers plusieurs opérations.

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


func _count_graph_nodes(graph: GraphEdit) -> int:
	var count = 0
	for child in graph.get_children():
		if child is GraphNode:
			count += 1
	return count


func test_undo_redo_chapter_creation():
	_main._nav_ctrl.on_new_story_pressed()
	assert_eq(_main._editor_main._story.chapters.size(), 1)

	# Créer un chapitre
	_main._nav_ctrl.on_create_pressed()
	assert_eq(_main._editor_main._story.chapters.size(), 2)
	assert_eq(_count_graph_nodes(_main._chapter_graph_view), 2)

	# Undo → retour à 1 chapitre
	_main._on_undo_pressed()
	assert_eq(_main._editor_main._story.chapters.size(), 1)
	assert_eq(_count_graph_nodes(_main._chapter_graph_view), 1)

	# Redo → retour à 2 chapitres
	_main._on_redo_pressed()
	assert_eq(_main._editor_main._story.chapters.size(), 2)
	assert_eq(_count_graph_nodes(_main._chapter_graph_view), 2)


func test_undo_redo_multiple_operations():
	_main._nav_ctrl.on_new_story_pressed()
	assert_eq(_main._editor_main._story.chapters.size(), 1)

	# 3 créations successives
	_main._nav_ctrl.on_create_pressed()
	_main._nav_ctrl.on_create_pressed()
	_main._nav_ctrl.on_create_pressed()
	assert_eq(_main._editor_main._story.chapters.size(), 4)

	# 3 undos → retour à 1 chapitre
	_main._on_undo_pressed()
	_main._on_undo_pressed()
	_main._on_undo_pressed()
	assert_eq(_main._editor_main._story.chapters.size(), 1)

	# 2 redos → 3 chapitres
	_main._on_redo_pressed()
	_main._on_redo_pressed()
	assert_eq(_main._editor_main._story.chapters.size(), 3)

	# Nouvelle action → redo stack vidée
	_main._nav_ctrl.on_create_pressed()
	assert_eq(_main._editor_main._story.chapters.size(), 4)
	assert_false(_main._undo_redo.can_redo(), "Redo stack should be cleared after new action")


func test_undo_redo_button_state():
	_main._nav_ctrl.on_new_story_pressed()

	# Initialement pas d'undo ni redo
	assert_false(_main._undo_redo.can_undo(), "Should not be able to undo initially")
	assert_false(_main._undo_redo.can_redo(), "Should not be able to redo initially")

	# Après création
	_main._nav_ctrl.on_create_pressed()
	assert_true(_main._undo_redo.can_undo(), "Should be able to undo after create")
	assert_false(_main._undo_redo.can_redo(), "Should not be able to redo after create")

	# Après undo
	_main._on_undo_pressed()
	assert_false(_main._undo_redo.can_undo(), "Should not be able to undo after undoing all")
	assert_true(_main._undo_redo.can_redo(), "Should be able to redo after undo")

	# Après redo
	_main._on_redo_pressed()
	assert_true(_main._undo_redo.can_undo(), "Should be able to undo after redo")
	assert_false(_main._undo_redo.can_redo(), "Should not be able to redo after redoing all")


func test_undo_redo_scene_creation():
	_main._nav_ctrl.on_new_story_pressed()
	var ch_uuid = _main._editor_main._story.chapters[0].uuid
	_main._nav_ctrl.on_chapter_double_clicked(ch_uuid)
	assert_eq(_main._editor_main._current_chapter.scenes.size(), 1)

	_main._nav_ctrl.on_create_pressed()
	assert_eq(_main._editor_main._current_chapter.scenes.size(), 2)

	_main._on_undo_pressed()
	assert_eq(_main._editor_main._current_chapter.scenes.size(), 1)

	_main._on_redo_pressed()
	assert_eq(_main._editor_main._current_chapter.scenes.size(), 2)


func test_undo_redo_condition_creation():
	_main._nav_ctrl.on_new_story_pressed()
	var ch_uuid = _main._editor_main._story.chapters[0].uuid
	_main._nav_ctrl.on_chapter_double_clicked(ch_uuid)
	var sc_uuid = _main._editor_main._current_chapter.scenes[0].uuid
	_main._nav_ctrl.on_scene_double_clicked(sc_uuid)
	assert_eq(_main._editor_main._current_scene.conditions.size(), 0)

	_main._nav_ctrl.on_create_condition_pressed()
	assert_eq(_main._editor_main._current_scene.conditions.size(), 1)

	_main._on_undo_pressed()
	assert_eq(_main._editor_main._current_scene.conditions.size(), 0)

	_main._on_redo_pressed()
	assert_eq(_main._editor_main._current_scene.conditions.size(), 1)
