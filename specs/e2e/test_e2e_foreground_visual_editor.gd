extends "res://specs/e2e/e2e_editor_base.gd"

## Tests e2e — Éditeur visuel de foregrounds.
##
## Vérifie la sélection, la désélection, le z-order, la suppression,
## le copier-coller et le masquage des foregrounds via interactions UI.


func _load_story_and_navigate_to_sequence_edit(story) -> void:
	_main._editor_main.open_story(story)
	_main.refresh_current_view()
	await _ui.wait_for_layout()

	var ch_uuid = story.chapters[0].uuid
	await _ui.double_click_graph_node(_main._chapter_graph_view, ch_uuid)

	var sc_uuid = story.chapters[0].scenes[0].uuid
	await _ui.double_click_graph_node(_main._scene_graph_view, sc_uuid)

	var seq_uuid = story.chapters[0].scenes[0].sequences[0].uuid
	await _ui.double_click_graph_node(_main._sequence_graph_view, seq_uuid)

	# Sélectionner le premier dialogue pour charger les foregrounds
	_main._sequence_editor_ctrl.select_dialogue(0)
	_main.update_preview_for_dialogue(0)
	await _ui.wait_for_layout()


func test_select_foreground_on_canvas():
	var story = E2eStoryBuilder.make_story_with_foregrounds()
	await _load_story_and_navigate_to_sequence_edit(story)

	assert_eq(_main._editor_main.get_current_level(), "sequence_edit")
	assert_eq(_main._visual_editor._fg_visual_map.size(), 2, "Should have 2 foreground wrappers")

	# Obtenir le UUID du premier foreground
	var seq = _main._editor_main._current_sequence
	var fgs = _main._sequence_editor_ctrl.get_effective_foregrounds(0)
	assert_true(fgs.size() >= 2, "Should have at least 2 foregrounds")

	var fg1_uuid = fgs[0].uuid
	# Sélectionner via l'API (simule un clic sur le wrapper)
	_main._visual_editor._select_foreground(fg1_uuid)
	await _ui.wait_frames()

	assert_true(fg1_uuid in _main._visual_editor._selected_fg_uuids,
		"FG1 should be selected")
	assert_true(_main._properties_panel.visible,
		"Properties panel should be visible when FG selected")


func test_deselect_foreground_click_empty():
	var story = E2eStoryBuilder.make_story_with_foregrounds()
	await _load_story_and_navigate_to_sequence_edit(story)

	var fgs = _main._sequence_editor_ctrl.get_effective_foregrounds(0)
	var fg1_uuid = fgs[0].uuid

	# Sélectionner d'abord
	_main._visual_editor._select_foreground(fg1_uuid)
	await _ui.wait_frames()
	assert_false(_main._visual_editor._selected_fg_uuids.is_empty(), "Should have selection")

	# Désélectionner
	_main._visual_editor._deselect_foreground()
	await _ui.wait_frames()

	assert_true(_main._visual_editor._selected_fg_uuids.is_empty(),
		"Selection should be empty after deselect")
	assert_false(_main._properties_panel.visible,
		"Properties panel should be hidden after deselect")


func test_foreground_z_order_child_ordering():
	var story = E2eStoryBuilder.make_story_with_foregrounds()
	await _load_story_and_navigate_to_sequence_edit(story)

	# Les foregrounds ont z_order 0 et 5
	var fgs = _main._sequence_editor_ctrl.get_effective_foregrounds(0)
	assert_eq(fgs.size(), 2)

	# Trouver quel fg a z_order 0 et lequel a z_order 5
	var fg_z0 = fgs[0] if fgs[0].z_order < fgs[1].z_order else fgs[1]
	var fg_z5 = fgs[1] if fgs[0].z_order < fgs[1].z_order else fgs[0]

	assert_eq(fg_z0.z_order, 0)
	assert_eq(fg_z5.z_order, 5)

	# Vérifier l'ordre des enfants dans _fg_container
	var container = _main._visual_editor._fg_container
	var wrapper_z0 = _main._visual_editor._fg_visual_map[fg_z0.uuid]
	var wrapper_z5 = _main._visual_editor._fg_visual_map[fg_z5.uuid]

	assert_true(wrapper_z0.get_index() < wrapper_z5.get_index(),
		"FG z_order=0 should be before FG z_order=5 in container")


func test_delete_foreground_via_key():
	var story = E2eStoryBuilder.make_story_with_foregrounds()
	await _load_story_and_navigate_to_sequence_edit(story)

	var fgs = _main._sequence_editor_ctrl.get_effective_foregrounds(0)
	var initial_count = fgs.size()
	assert_eq(initial_count, 2)

	var fg_uuid = fgs[0].uuid
	# Sélectionner le foreground
	_main._visual_editor._select_foreground(fg_uuid)
	await _ui.wait_frames()

	# Simuler touche Delete
	await _ui.press_key(KEY_DELETE)

	# Vérifier la suppression
	var seq = _main._editor_main._current_sequence
	var remaining = _main._sequence_editor_ctrl.get_effective_foregrounds(0)
	assert_eq(remaining.size(), initial_count - 1,
		"Should have one less foreground after delete")


func test_foreground_context_menu_delete():
	var story = E2eStoryBuilder.make_story_with_foregrounds()
	await _load_story_and_navigate_to_sequence_edit(story)

	var fgs = _main._sequence_editor_ctrl.get_effective_foregrounds(0)
	var initial_count = fgs.size()
	var fg_uuid = fgs[0].uuid

	# Sélectionner puis simuler la commande supprimer du menu contextuel
	_main._visual_editor._select_foreground(fg_uuid)
	_main._visual_editor._context_menu_uuid = fg_uuid
	await _ui.wait_frames()

	# Émettre le signal id_pressed avec id=0 (Supprimer)
	await _ui.select_popup_item(_main._visual_editor._context_menu, 0)

	var remaining = _main._sequence_editor_ctrl.get_effective_foregrounds(0)
	assert_eq(remaining.size(), initial_count - 1,
		"Should have one less foreground after context menu delete")


func test_foreground_copy_paste_params():
	var story = E2eStoryBuilder.make_story_with_foregrounds()
	await _load_story_and_navigate_to_sequence_edit(story)

	var fgs = _main._sequence_editor_ctrl.get_effective_foregrounds(0)
	assert_eq(fgs.size(), 2)

	var fg1 = fgs[0]
	var fg2 = fgs[1]

	# Copier les paramètres de fg1
	_main._visual_editor._context_menu_uuid = fg1.uuid
	_main._visual_editor._on_context_menu_id_pressed(1)  # Copier les paramètres
	await _ui.wait_frames()

	# Coller sur fg2
	_main._visual_editor._context_menu_uuid = fg2.uuid
	_main._visual_editor._on_context_menu_id_pressed(2)  # Coller les paramètres
	await _ui.wait_frames()

	# Vérifier que scale et anchor sont identiques
	assert_eq(fg2.scale, fg1.scale, "Scale should match after paste params")
	assert_eq(fg2.anchor_bg, fg1.anchor_bg, "Anchor BG should match after paste params")
	assert_eq(fg2.anchor_fg, fg1.anchor_fg, "Anchor FG should match after paste params")


func test_foreground_copy_paste_foreground():
	var story = E2eStoryBuilder.make_story_with_foregrounds()
	await _load_story_and_navigate_to_sequence_edit(story)

	var fgs = _main._sequence_editor_ctrl.get_effective_foregrounds(0)
	var initial_count = fgs.size()
	var fg1_uuid = fgs[0].uuid

	# Copier le foreground via le menu contextuel (id=3)
	_main._visual_editor._select_foreground(fg1_uuid)
	_main._visual_editor._context_menu_uuid = fg1_uuid
	_main._visual_editor._on_context_menu_id_pressed(3)  # Copier le foreground
	await _ui.wait_frames()

	# Coller le foreground (id=4)
	_main._visual_editor._on_context_menu_id_pressed(4)  # Coller le foreground
	await _ui.wait_frames()

	var new_fgs = _main._sequence_editor_ctrl.get_effective_foregrounds(0)
	assert_eq(new_fgs.size(), initial_count + 1,
		"Should have one more foreground after paste")


func test_foreground_hide_via_context_menu():
	var story = E2eStoryBuilder.make_story_with_foregrounds()
	await _load_story_and_navigate_to_sequence_edit(story)

	var fgs = _main._sequence_editor_ctrl.get_effective_foregrounds(0)
	var fg_uuid = fgs[0].uuid

	# Cacher via menu contextuel (id=7)
	_main._visual_editor._select_foreground(fg_uuid)
	_main._visual_editor._context_menu_uuid = fg_uuid
	_main._visual_editor._on_context_menu_id_pressed(7)  # Cacher
	await _ui.wait_frames()

	assert_true(fg_uuid in _main._visual_editor._hidden_fg_uuids,
		"FG should be in hidden list")
	assert_true(_main._visual_editor.is_foreground_hidden(fg_uuid),
		"is_foreground_hidden should return true")

	# Le wrapper doit être invisible
	var wrapper = _main._visual_editor._fg_visual_map.get(fg_uuid)
	if wrapper and is_instance_valid(wrapper):
		assert_false(wrapper.visible, "Hidden FG wrapper should not be visible")


func test_multi_select_with_shift():
	var story = E2eStoryBuilder.make_story_with_foregrounds()
	await _load_story_and_navigate_to_sequence_edit(story)

	var fgs = _main._sequence_editor_ctrl.get_effective_foregrounds(0)
	assert_eq(fgs.size(), 2)

	var fg1_uuid = fgs[0].uuid
	var fg2_uuid = fgs[1].uuid

	# Sélectionner fg1 sans shift
	_main._visual_editor._select_foreground(fg1_uuid, false)
	await _ui.wait_frames()
	assert_eq(_main._visual_editor._selected_fg_uuids.size(), 1)

	# Sélectionner fg2 avec shift
	_main._visual_editor._select_foreground(fg2_uuid, true)
	await _ui.wait_frames()

	assert_eq(_main._visual_editor._selected_fg_uuids.size(), 2,
		"Should have 2 selected foregrounds with shift-click")
	assert_true(fg1_uuid in _main._visual_editor._selected_fg_uuids)
	assert_true(fg2_uuid in _main._visual_editor._selected_fg_uuids)
