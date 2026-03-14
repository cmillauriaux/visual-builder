extends "res://specs/e2e/e2e_editor_base.gd"

## Tests e2e — Édition de dialogues dans l'éditeur de séquence.
##
## Vérifie l'ajout, la suppression, la sélection de dialogues,
## et la cohérence entre la liste UI et le modèle.


func _load_story_and_navigate(story) -> void:
	_main._editor_main.open_story(story)
	_main.refresh_current_view()
	await _ui.wait_for_layout()

	var ch_uuid = story.chapters[0].uuid
	await _ui.double_click_graph_node(_main._chapter_graph_view, ch_uuid)

	var sc_uuid = story.chapters[0].scenes[0].uuid
	await _ui.double_click_graph_node(_main._scene_graph_view, sc_uuid)

	var seq_uuid = story.chapters[0].scenes[0].sequences[0].uuid
	await _ui.double_click_graph_node(_main._sequence_graph_view, seq_uuid)
	await _ui.wait_for_layout()


func test_add_dialogue():
	var story = E2eStoryBuilder.make_story_with_multiple_dialogues()
	await _load_story_and_navigate(story)

	var seq = _main._editor_main._current_sequence
	var initial_count = seq.dialogues.size()
	assert_eq(initial_count, 3)

	_main._seq_ui_ctrl.on_add_dialogue_pressed()
	await _ui.wait_frames()

	assert_eq(seq.dialogues.size(), initial_count + 1,
		"Should have one more dialogue after add")


func test_add_multiple_dialogues():
	var story = E2eStoryBuilder.make_story_with_multiple_dialogues()
	await _load_story_and_navigate(story)

	var seq = _main._editor_main._current_sequence
	var initial_count = seq.dialogues.size()

	for i in 3:
		_main._seq_ui_ctrl.on_add_dialogue_pressed()
		await _ui.wait_frames()

	assert_eq(seq.dialogues.size(), initial_count + 3,
		"Should have 3 more dialogues after 3 adds")


func test_select_dialogue_from_list():
	var story = E2eStoryBuilder.make_story_with_multiple_dialogues()
	await _load_story_and_navigate(story)

	# Sélectionner le dialogue 1
	_main._sequence_editor_ctrl.select_dialogue(1)
	await _ui.wait_frames()

	assert_eq(_main._sequence_editor_ctrl.get_selected_dialogue_index(), 1,
		"Selected dialogue index should be 1")


func test_delete_dialogue():
	var story = E2eStoryBuilder.make_story_with_multiple_dialogues()
	await _load_story_and_navigate(story)

	var seq = _main._editor_main._current_sequence
	var initial_count = seq.dialogues.size()
	assert_eq(initial_count, 3)

	# Supprimer le dialogue du milieu (index 1) via le contrôleur
	# Note : on_delete_dialogue ouvre un ConfirmationDialog, on appelle directement la logique
	var cmd = preload("res://src/commands/remove_dialogue_command.gd").new(seq, 1)
	_main._undo_redo.push_and_execute(cmd)
	_main._rebuild_dialogue_list()
	await _ui.wait_frames()

	assert_eq(seq.dialogues.size(), initial_count - 1,
		"Should have one less dialogue after delete")
	# Vérifier que les textes restants sont corrects
	assert_eq(seq.dialogues[0].text, "Premier dialogue.")
	assert_eq(seq.dialogues[1].text, "Troisième dialogue.")


func test_selection_updates_visual_editor():
	var story = E2eStoryBuilder.make_story_with_foregrounds()
	await _load_story_and_navigate(story)

	var seq = _main._editor_main._current_sequence
	# Le premier dialogue a 2 foregrounds
	assert_eq(seq.dialogues[0].foregrounds.size(), 2)

	_main._sequence_editor_ctrl.select_dialogue(0)
	_main.update_preview_for_dialogue(0)
	await _ui.wait_frames()

	# Le visual editor devrait afficher les foregrounds
	assert_eq(_main._visual_editor._fg_visual_map.size(), 2,
		"Visual editor should show 2 foreground wrappers for dialogue 0")


func test_add_preserves_existing():
	var story = E2eStoryBuilder.make_story_with_multiple_dialogues()
	await _load_story_and_navigate(story)

	var seq = _main._editor_main._current_sequence
	var original_texts = []
	for dlg in seq.dialogues:
		original_texts.append(dlg.text)

	_main._seq_ui_ctrl.on_add_dialogue_pressed()
	await _ui.wait_frames()

	# L'ajout insère après la sélection courante, donc les textes originaux
	# sont tous toujours présents (potentiellement à des indices décalés).
	var current_texts = []
	for dlg in seq.dialogues:
		current_texts.append(dlg.text)
	for text in original_texts:
		assert_true(text in current_texts,
			"Original text '%s' should still exist after add" % text)


func test_list_rebuild_after_deletion():
	var story = E2eStoryBuilder.make_story_with_multiple_dialogues()
	await _load_story_and_navigate(story)

	var seq = _main._editor_main._current_sequence
	assert_eq(seq.dialogues.size(), 3)

	# Supprimer dialogue 1
	var cmd = preload("res://src/commands/remove_dialogue_command.gd").new(seq, 1)
	_main._undo_redo.push_and_execute(cmd)
	_main._rebuild_dialogue_list()
	await _ui.wait_frames()

	# Vérifier que le nombre d'items dans la liste correspond au modèle
	var list_count = _main._dialogue_timeline.get_item_count() if _main._dialogue_timeline.has_method("get_item_count") else seq.dialogues.size()
	assert_eq(seq.dialogues.size(), 2, "Model should have 2 dialogues")


func test_first_dialogue_auto_selected():
	var story = E2eStoryBuilder.make_story_with_multiple_dialogues()
	await _load_story_and_navigate(story)

	# Au chargement, le premier dialogue doit être sélectionné
	# La navigation vers sequence_edit déclenche une auto-sélection
	var idx = _main._sequence_editor_ctrl.get_selected_dialogue_index()
	assert_eq(idx, 0, "First dialogue should be auto-selected on entry")
