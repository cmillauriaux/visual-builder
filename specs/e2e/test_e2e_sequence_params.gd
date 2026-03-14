extends "res://specs/e2e/e2e_editor_base.gd"

## Tests e2e — Paramètres de séquence (titre, sous-titre, couleur, transitions).
##
## Accès via l'onglet Paramètres (index 4) du TabContainer.


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

	# Aller sur l'onglet Paramètres (index 4)
	await _ui.select_tab(_main._tab_container, 4)
	await _ui.wait_frames()


func test_set_title():
	var story = E2eStoryBuilder.make_minimal_story()
	await _load_story_and_navigate(story)

	await _ui.set_line_edit_text(_main._seq_title_edit, "Mon Titre")

	var seq = _main._editor_main._current_sequence
	assert_eq(seq.title, "Mon Titre", "Sequence title should be updated")


func test_set_subtitle():
	var story = E2eStoryBuilder.make_minimal_story()
	await _load_story_and_navigate(story)

	await _ui.set_line_edit_text(_main._seq_subtitle_edit, "Mon Sous-titre")

	var seq = _main._editor_main._current_sequence
	assert_eq(seq.subtitle, "Mon Sous-titre", "Sequence subtitle should be updated")


func test_set_background_color():
	var story = E2eStoryBuilder.make_minimal_story()
	await _load_story_and_navigate(story)

	await _ui.set_color(_main._seq_bg_color_picker, Color.RED)

	var seq = _main._editor_main._current_sequence
	assert_ne(seq.background_color, "", "Background color should be set")
	var parsed = Color.from_string(seq.background_color, Color.BLACK)
	assert_almost_eq(parsed.r, 1.0, 0.01, "Red channel should be 1.0")


func test_set_transition_in_fade():
	var story = E2eStoryBuilder.make_minimal_story()
	await _load_story_and_navigate(story)

	# Index 1 = "fade" dans ["none", "fade", "pixelate"]
	await _ui.select_option(_main._seq_trans_in_type, 1)

	var seq = _main._editor_main._current_sequence
	assert_eq(seq.transition_in_type, "fade",
		"Transition in type should be fade")


func test_set_transition_in_pixelate():
	var story = E2eStoryBuilder.make_minimal_story()
	await _load_story_and_navigate(story)

	# Index 2 = "pixelate"
	await _ui.select_option(_main._seq_trans_in_type, 2)

	var seq = _main._editor_main._current_sequence
	assert_eq(seq.transition_in_type, "pixelate",
		"Transition in type should be pixelate")


func test_set_transition_out():
	var story = E2eStoryBuilder.make_minimal_story()
	await _load_story_and_navigate(story)

	# Index 1 = "fade"
	await _ui.select_option(_main._seq_trans_out_type, 1)

	var seq = _main._editor_main._current_sequence
	assert_eq(seq.transition_out_type, "fade",
		"Transition out type should be fade")


func test_set_transition_durations():
	var story = E2eStoryBuilder.make_minimal_story()
	await _load_story_and_navigate(story)

	await _ui.set_spinbox_value(_main._seq_trans_in_dur, 2.0)
	await _ui.set_spinbox_value(_main._seq_trans_out_dur, 3.0)

	var seq = _main._editor_main._current_sequence
	assert_almost_eq(seq.transition_in_duration, 2.0, 0.01,
		"Transition in duration should be 2.0")
	assert_almost_eq(seq.transition_out_duration, 3.0, 0.01,
		"Transition out duration should be 3.0")
