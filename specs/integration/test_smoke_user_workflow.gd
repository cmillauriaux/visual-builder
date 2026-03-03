extends GutTest

const MainScript = preload("res://src/main.gd")
const StoryModel = preload("res://src/models/story.gd")

var _main: Control

func before_each():
	_main = Control.new()
	_main.set_script(MainScript)
	add_child(_main)
	# On attend un frame pour le _ready
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

func test_full_user_workflow_integration():
	# 1. Créer une nouvelle histoire
	_main._nav_ctrl.on_new_story_pressed()
	assert_eq(_main._editor_main._story.title, "Mon Histoire")
	assert_true(_main._chapter_graph_view.visible, "Chapter view should be visible")
	
	# Vérifier que le graphe a bien chargé le chapitre par défaut
	assert_eq(_count_graph_nodes(_main._chapter_graph_view), 1, "Should have 1 node in chapter graph")

	# 2. Créer un deuxième chapitre via le bouton create
	_main._nav_ctrl.on_create_pressed()
	assert_eq(_main._editor_main._story.chapters.size(), 2)
	assert_eq(_count_graph_nodes(_main._chapter_graph_view), 2, "Should now have 2 nodes in chapter graph")

	# 3. Naviguer dans le premier chapitre (double-clic)
	var first_ch_uuid = _main._editor_main._story.chapters[0].uuid
	_main._nav_ctrl.on_chapter_double_clicked(first_ch_uuid)
	
	assert_true(_main._scene_graph_view.visible, "Scene view should be visible after double click")
	assert_eq(_main._editor_main.get_current_level(), "scenes")
	assert_gt(_count_graph_nodes(_main._scene_graph_view), 0, "Scene graph should not be empty")

	# 4. Naviguer dans la première séquence de la première scène
	var first_sc_uuid = _main._editor_main._current_chapter.scenes[0].uuid
	_main._nav_ctrl.on_scene_double_clicked(first_sc_uuid)
	
	var first_seq_uuid = _main._editor_main._current_scene.sequences[0].uuid
	_main._nav_ctrl.on_sequence_double_clicked(first_seq_uuid)
	
	assert_true(_main._sequence_editor_panel.visible, "Sequence editor should be visible")
	assert_eq(_main._editor_main.get_current_level(), "sequence_edit")
	
	# 5. Vérifier que l'éditeur de séquence a bien chargé les données
	# (Le premier dialogue par défaut)
	assert_gt(_main._dialogue_list_container.get_child_count(), 0, "Dialogue list should not be empty")

	# 6. Tester le retour arrière
	_main._nav_ctrl.on_back_pressed()
	assert_true(_main._sequence_graph_view.visible, "Should be back to sequence graph")
	assert_eq(_main._editor_main.get_current_level(), "sequences")
	
	_main._nav_ctrl.on_back_pressed()
	assert_true(_main._scene_graph_view.visible, "Should be back to scene graph")
	
	_main._nav_ctrl.on_back_pressed()
	assert_true(_main._chapter_graph_view.visible, "Should be back to chapter graph")
