extends "res://specs/e2e/e2e_editor_base.gd"

## Tests e2e — Éditeur de terminaison (EndingEditor).
##
## Vérifie les modes (none/redirect/choices), l'ajout de choix,
## la limite de choix, et les types de redirection.


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


func _switch_to_ending_tab() -> void:
	# Onglet Terminaison = index 1 dans le TabContainer
	await _ui.select_tab(_main._tab_container, 1)
	await _ui.wait_frames()


func test_ending_mode_none_by_default():
	var story = E2eStoryBuilder.make_minimal_story()
	await _load_story_and_navigate(story)
	await _switch_to_ending_tab()

	var seq = _main._editor_main._current_sequence
	assert_null(seq.ending, "Ending should be null by default")
	assert_eq(_main._ending_editor.get_ending_type(), "",
		"Ending type should be empty string when no ending")


func test_set_mode_redirect():
	var story = E2eStoryBuilder.make_minimal_story()
	await _load_story_and_navigate(story)
	await _switch_to_ending_tab()

	# Cliquer sur le bouton Redirect
	await _ui.click_button(_main._ending_editor._mode_redirect_btn, "Mode redirect")

	var seq = _main._editor_main._current_sequence
	assert_not_null(seq.ending, "Ending should be created")
	assert_eq(seq.ending.type, "auto_redirect",
		"Ending type should be auto_redirect")


func test_set_mode_choices():
	var story = E2eStoryBuilder.make_minimal_story()
	await _load_story_and_navigate(story)
	await _switch_to_ending_tab()

	# Cliquer sur le bouton Choices
	await _ui.click_button(_main._ending_editor._mode_choices_btn, "Mode choices")

	var seq = _main._editor_main._current_sequence
	assert_not_null(seq.ending, "Ending should be created")
	assert_eq(seq.ending.type, "choices",
		"Ending type should be choices")


func test_add_choice():
	var story = E2eStoryBuilder.make_minimal_story()
	await _load_story_and_navigate(story)
	await _switch_to_ending_tab()

	await _ui.click_button(_main._ending_editor._mode_choices_btn, "Mode choices")
	await _ui.wait_frames()

	# Ajouter un choix
	await _ui.click_button(_main._ending_editor._add_choice_btn, "Ajouter choix")

	var seq = _main._editor_main._current_sequence
	assert_eq(seq.ending.choices.size(), 1, "Should have 1 choice")


func test_add_choices_up_to_limit():
	var story = E2eStoryBuilder.make_minimal_story()
	await _load_story_and_navigate(story)
	await _switch_to_ending_tab()

	await _ui.click_button(_main._ending_editor._mode_choices_btn, "Mode choices")
	await _ui.wait_frames()

	# Ajouter 8 choix (limite)
	for i in 8:
		await _ui.click_button(_main._ending_editor._add_choice_btn, "Ajouter choix %d" % i)

	var seq = _main._editor_main._current_sequence
	assert_eq(seq.ending.choices.size(), 8, "Should have 8 choices (max)")
	assert_true(_main._ending_editor._add_choice_btn.disabled,
		"Add choice button should be disabled at limit")


func test_redirect_type_game_over():
	var story = E2eStoryBuilder.make_minimal_story()
	await _load_story_and_navigate(story)
	await _switch_to_ending_tab()

	await _ui.click_button(_main._ending_editor._mode_redirect_btn, "Mode redirect")
	await _ui.wait_frames()

	# Trouver l'index de "game_over" dans les CONSEQUENCE_TYPES
	var types = _main._ending_editor.CONSEQUENCE_TYPES
	var game_over_idx = types.find("game_over")
	assert_true(game_over_idx >= 0, "game_over should exist in types")

	await _ui.select_option(_main._ending_editor._redirect_type_dropdown, game_over_idx)

	var seq = _main._editor_main._current_sequence
	assert_eq(seq.ending.auto_consequence.type, "game_over",
		"Consequence type should be game_over")


func test_redirect_type_to_be_continued():
	var story = E2eStoryBuilder.make_minimal_story()
	await _load_story_and_navigate(story)
	await _switch_to_ending_tab()

	await _ui.click_button(_main._ending_editor._mode_redirect_btn, "Mode redirect")
	await _ui.wait_frames()

	var types = _main._ending_editor.CONSEQUENCE_TYPES
	var tbc_idx = types.find("to_be_continued")
	assert_true(tbc_idx >= 0, "to_be_continued should exist in types")

	await _ui.select_option(_main._ending_editor._redirect_type_dropdown, tbc_idx)

	var seq = _main._editor_main._current_sequence
	assert_eq(seq.ending.auto_consequence.type, "to_be_continued",
		"Consequence type should be to_be_continued")


func test_switch_modes_clears_previous():
	var story = E2eStoryBuilder.make_minimal_story()
	await _load_story_and_navigate(story)
	await _switch_to_ending_tab()

	# D'abord mode redirect
	await _ui.click_button(_main._ending_editor._mode_redirect_btn, "Mode redirect")
	await _ui.wait_frames()

	var seq = _main._editor_main._current_sequence
	assert_eq(seq.ending.type, "auto_redirect")

	# Puis mode choices
	await _ui.click_button(_main._ending_editor._mode_choices_btn, "Mode choices")
	await _ui.wait_frames()

	assert_eq(seq.ending.type, "choices",
		"Type should change to choices after switching mode")
