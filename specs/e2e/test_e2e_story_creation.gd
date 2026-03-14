extends GutTest

## Tests e2e — Workflow complet de création d'une histoire.

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


func test_create_full_story_hierarchy():
	# 1. Créer une nouvelle histoire
	_main._nav_ctrl.on_new_story_pressed()
	assert_eq(_main._editor_main._story.title, "Mon Histoire")
	assert_true(_main._chapter_graph_view.visible, "Chapter view should be visible")
	assert_eq(_main._editor_main._story.chapters.size(), 1)
	assert_eq(_count_graph_nodes(_main._chapter_graph_view), 1)

	# 2. Créer un deuxième chapitre
	_main._nav_ctrl.on_create_pressed()
	assert_eq(_main._editor_main._story.chapters.size(), 2)
	assert_eq(_count_graph_nodes(_main._chapter_graph_view), 2)

	# 3. Naviguer dans le premier chapitre
	var ch1_uuid = _main._editor_main._story.chapters[0].uuid
	_main._nav_ctrl.on_chapter_double_clicked(ch1_uuid)
	assert_eq(_main._editor_main.get_current_level(), "scenes")
	assert_true(_main._scene_graph_view.visible, "Scene view should be visible")
	assert_eq(_main._editor_main._current_chapter.scenes.size(), 1)

	# 4. Créer une deuxième scène
	_main._nav_ctrl.on_create_pressed()
	assert_eq(_main._editor_main._current_chapter.scenes.size(), 2)
	assert_eq(_count_graph_nodes(_main._scene_graph_view), 2)

	# 5. Naviguer dans la première scène
	var sc1_uuid = _main._editor_main._current_chapter.scenes[0].uuid
	_main._nav_ctrl.on_scene_double_clicked(sc1_uuid)
	assert_eq(_main._editor_main.get_current_level(), "sequences")
	assert_true(_main._sequence_graph_view.visible, "Sequence view should be visible")
	assert_eq(_main._editor_main._current_scene.sequences.size(), 1)

	# 6. Créer une deuxième séquence
	_main._nav_ctrl.on_create_pressed()
	assert_eq(_main._editor_main._current_scene.sequences.size(), 2)
	assert_eq(_count_graph_nodes(_main._sequence_graph_view), 2)

	# 7. Naviguer dans la première séquence
	var seq1_uuid = _main._editor_main._current_scene.sequences[0].uuid
	_main._nav_ctrl.on_sequence_double_clicked(seq1_uuid)
	assert_eq(_main._editor_main.get_current_level(), "sequence_edit")
	assert_true(_main._sequence_editor_panel.visible, "Sequence editor should be visible")

	# 8. Vérifier le dialogue par défaut et en ajouter un
	assert_eq(_main._editor_main._current_sequence.dialogues.size(), 1)
	assert_gt(_main._dialogue_timeline.get_child_count(), 0, "Dialogue list should not be empty")
	_main._seq_ui_ctrl.on_add_dialogue_pressed()
	assert_eq(_main._editor_main._current_sequence.dialogues.size(), 2)


func test_create_condition_in_sequence_view():
	_main._nav_ctrl.on_new_story_pressed()

	# Naviguer jusqu'au niveau séquences
	var ch_uuid = _main._editor_main._story.chapters[0].uuid
	_main._nav_ctrl.on_chapter_double_clicked(ch_uuid)
	var sc_uuid = _main._editor_main._current_chapter.scenes[0].uuid
	_main._nav_ctrl.on_scene_double_clicked(sc_uuid)
	assert_eq(_main._editor_main.get_current_level(), "sequences")

	# Créer une condition
	assert_eq(_main._editor_main._current_scene.conditions.size(), 0)
	_main._nav_ctrl.on_create_condition_pressed()
	assert_eq(_main._editor_main._current_scene.conditions.size(), 1)

	# Double-clic sur la condition
	var cond_uuid = _main._editor_main._current_scene.conditions[0].uuid
	_main._nav_ctrl.on_condition_double_clicked(cond_uuid)
	assert_eq(_main._editor_main.get_current_level(), "condition_edit")
	assert_true(_main._condition_editor_panel.visible, "Condition editor should be visible")
