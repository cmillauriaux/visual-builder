extends "res://specs/e2e/e2e_editor_base.gd"

## Tests e2e — Opérations sur le graphe de séquences.
##
## Vérifie les transitions via nœuds, le copier-coller de foregrounds
## entre séquences, le toggle entry point, et la création de conditions.


func _load_story_and_navigate_to_sequences(story) -> void:
	_main._editor_main.open_story(story)
	_main.refresh_current_view()
	await _ui.wait_for_layout()

	var ch_uuid = story.chapters[0].uuid
	await _ui.double_click_graph_node(_main._chapter_graph_view, ch_uuid)

	var sc_uuid = story.chapters[0].scenes[0].uuid
	await _ui.double_click_graph_node(_main._scene_graph_view, sc_uuid)
	await _ui.wait_for_layout()


func test_set_transition_in_via_graph():
	var story = E2eStoryBuilder.make_story_with_multiple_sequences()
	await _load_story_and_navigate_to_sequences(story)

	var seq1 = story.chapters[0].scenes[0].sequences[0]
	var seq1_uuid = seq1.uuid

	# Émettre le signal de transition directement sur le nœud
	var node = _main._sequence_graph_view._node_map[seq1_uuid]
	node.transition_selected.emit(seq1_uuid, "transition_in_type", "fade")
	await _ui.wait_frames()

	assert_eq(seq1.transition_in_type, "fade",
		"Transition in type should be updated via graph node")


func test_set_transition_out_via_graph():
	var story = E2eStoryBuilder.make_story_with_multiple_sequences()
	await _load_story_and_navigate_to_sequences(story)

	var seq1 = story.chapters[0].scenes[0].sequences[0]
	var seq1_uuid = seq1.uuid

	var node = _main._sequence_graph_view._node_map[seq1_uuid]
	node.transition_selected.emit(seq1_uuid, "transition_out_type", "pixelate")
	await _ui.wait_frames()

	assert_eq(seq1.transition_out_type, "pixelate",
		"Transition out type should be updated via graph node")


func test_copy_paste_foregrounds_between_sequences():
	var story = E2eStoryBuilder.make_story_with_multiple_sequences()
	await _load_story_and_navigate_to_sequences(story)

	var scene = story.chapters[0].scenes[0]
	var seq1 = scene.sequences[0]
	var seq2 = scene.sequences[1]
	var seq1_uuid = seq1.uuid
	var seq2_uuid = seq2.uuid

	# Seq1 a 2 foregrounds dans son dialogue, seq2 n'en a pas
	assert_eq(seq1.dialogues[0].foregrounds.size(), 2)
	assert_eq(seq2.dialogues[0].foregrounds.size(), 0)

	# Copier les FGs de seq1 via le nœud graphe (id=3)
	await _ui.right_click_graph_node_menu(_main._sequence_graph_view, seq1_uuid, 3)

	# Vérifier que le clipboard est rempli
	assert_false(_main._sequence_graph_view._fg_clipboard.is_empty(),
		"FG clipboard should not be empty after copy")

	# Coller sur seq2 (id=4)
	await _ui.right_click_graph_node_menu(_main._sequence_graph_view, seq2_uuid, 4)

	# Vérifier que seq2 a maintenant des foregrounds
	assert_true(seq2.dialogues[0].foregrounds.size() > 0,
		"Seq2 dialogue should have foregrounds after paste")


func test_toggle_entry_point():
	var story = E2eStoryBuilder.make_story_with_multiple_sequences()
	await _load_story_and_navigate_to_sequences(story)

	var scene = story.chapters[0].scenes[0]
	var seq2 = scene.sequences[1]
	var seq2_uuid = seq2.uuid

	# Toggle entry point via le menu contextuel (id=1)
	await _ui.right_click_graph_node_menu(_main._sequence_graph_view, seq2_uuid, 1)

	# Vérifier que l'entry_point_uuid a changé
	assert_eq(scene.entry_point_uuid, seq2_uuid,
		"Entry point should be set to seq2")


func test_create_condition_node():
	var story = E2eStoryBuilder.make_story_with_multiple_sequences()
	await _load_story_and_navigate_to_sequences(story)

	var scene = story.chapters[0].scenes[0]
	var initial_conditions = scene.conditions.size()

	# Cliquer sur le bouton de création de condition
	await _ui.click_button(_main._create_condition_button, "Nouvelle condition")

	assert_eq(scene.conditions.size(), initial_conditions + 1,
		"Should have one more condition after create")
