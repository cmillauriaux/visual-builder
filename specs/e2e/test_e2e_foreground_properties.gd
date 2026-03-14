extends "res://specs/e2e/e2e_editor_base.gd"

## Tests e2e — Panneau de propriétés des foregrounds (TransitionPanel).
##
## Vérifie le type de transition, la durée, le z-order, le flip,
## et la visibilité du panneau selon la sélection.


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

	_main._sequence_editor_ctrl.select_dialogue(0)
	_main.update_preview_for_dialogue(0)
	await _ui.wait_for_layout()


func _select_first_foreground() -> String:
	var fgs = _main._sequence_editor_ctrl.get_effective_foregrounds(0)
	assert_true(fgs.size() >= 1, "Should have at least 1 foreground")
	var uuid = fgs[0].uuid
	_main._visual_editor._select_foreground(uuid)
	# Trigger the signal handler manually (since _select_foreground emits foreground_selected)
	await _ui.wait_frames()
	return uuid


func test_set_transition_type_fade():
	var story = E2eStoryBuilder.make_story_with_foregrounds()
	await _load_story_and_navigate_to_sequence_edit(story)

	var uuid = await _select_first_foreground()
	assert_true(_main._transition_panel.visible, "Panel should be visible")

	# Changer le type de transition via l'OptionButton
	await _ui.select_option(_main._transition_panel._type_option, 1)  # "fade"

	var fg = _main._visual_editor.find_foreground(uuid)
	assert_eq(fg.transition_type, "fade",
		"Foreground transition type should be 'fade'")


func test_set_transition_duration():
	var story = E2eStoryBuilder.make_story_with_foregrounds()
	await _load_story_and_navigate_to_sequence_edit(story)

	var uuid = await _select_first_foreground()

	# Changer la durée
	await _ui.set_spinbox_value(_main._transition_panel._duration_spin, 1.5)

	var fg = _main._visual_editor.find_foreground(uuid)
	assert_almost_eq(fg.transition_duration, 1.5, 0.01,
		"Foreground transition duration should be 1.5")


func test_set_z_order():
	var story = E2eStoryBuilder.make_story_with_foregrounds()
	await _load_story_and_navigate_to_sequence_edit(story)

	var uuid = await _select_first_foreground()

	# Changer le z-order
	await _ui.set_spinbox_value(_main._transition_panel._z_order_spin, 10)

	var fg = _main._visual_editor.find_foreground(uuid)
	assert_eq(fg.z_order, 10,
		"Foreground z_order should be 10")


func test_set_flip_horizontal():
	var story = E2eStoryBuilder.make_story_with_foregrounds()
	await _load_story_and_navigate_to_sequence_edit(story)

	var uuid = await _select_first_foreground()

	# Sélectionner flip horizontal (index 1)
	await _ui.select_option(_main._transition_panel._flip_option, 1)

	var fg = _main._visual_editor.find_foreground(uuid)
	assert_true(fg.flip_h, "flip_h should be true after selecting horizontal")
	assert_false(fg.flip_v, "flip_v should be false for horizontal only")


func test_set_flip_both():
	var story = E2eStoryBuilder.make_story_with_foregrounds()
	await _load_story_and_navigate_to_sequence_edit(story)

	var uuid = await _select_first_foreground()

	# Sélectionner flip "Les deux" (index 3)
	await _ui.select_option(_main._transition_panel._flip_option, 3)

	var fg = _main._visual_editor.find_foreground(uuid)
	assert_true(fg.flip_h, "flip_h should be true for 'both'")
	assert_true(fg.flip_v, "flip_v should be true for 'both'")


func test_panel_hidden_on_deselect():
	var story = E2eStoryBuilder.make_story_with_foregrounds()
	await _load_story_and_navigate_to_sequence_edit(story)

	await _select_first_foreground()
	assert_true(_main._transition_panel.visible, "Panel should be visible when FG selected")

	# Désélectionner
	_main._visual_editor._deselect_foreground()
	await _ui.wait_frames()

	assert_false(_main._transition_panel.visible,
		"Panel should be hidden after deselect")
