extends "res://specs/e2e/e2e_editor_base.gd"

## Tests e2e — Panneau de variables.
##
## Vérifie l'ouverture du popup, l'ajout/suppression de variables,
## l'édition de nom/valeur, et les checkboxes de visibilité.


func _load_story_with_variable() -> void:
	var story = E2eStoryBuilder.make_story_with_two_sequences()
	_main._editor_main.open_story(story)
	_main.refresh_current_view()
	await _ui.wait_for_layout()


func test_open_variable_panel():
	await _load_story_with_variable()

	# Ouvrir le panel variables
	_main._nav_ctrl.on_variables_pressed()
	await _ui.wait_frames(5)

	assert_true(_main._variable_panel_popup.visible,
		"Variable panel popup should be visible")


func test_add_variable():
	await _load_story_with_variable()

	_main._nav_ctrl.on_variables_pressed()
	await _ui.wait_frames(5)

	var story = _main._editor_main._story
	var initial_count = story.variables.size()

	# Ajouter une variable via le panel
	_main._variable_panel.add_variable()
	await _ui.wait_frames()

	assert_eq(story.variables.size(), initial_count + 1,
		"Should have one more variable after add")


func test_edit_variable_name():
	await _load_story_with_variable()

	_main._nav_ctrl.on_variables_pressed()
	await _ui.wait_frames(5)

	var story = _main._editor_main._story
	# Ajouter une variable vide d'abord
	_main._variable_panel.add_variable()
	await _ui.wait_frames()

	var new_idx = story.variables.size() - 1
	# Éditer le nom via l'API
	_main._variable_panel.update_variable_name(new_idx, "health")
	await _ui.wait_frames()

	assert_eq(story.variables[new_idx].var_name, "health",
		"Variable name should be 'health'")


func test_edit_variable_value():
	await _load_story_with_variable()

	_main._nav_ctrl.on_variables_pressed()
	await _ui.wait_frames(5)

	var story = _main._editor_main._story
	# La story "with_two_sequences" a déjà la variable "score" à l'index 0
	var score_idx = -1
	for i in story.variables.size():
		if story.variables[i].var_name == "score":
			score_idx = i
			break
	assert_true(score_idx >= 0, "Should have 'score' variable")

	_main._variable_panel.update_variable_value(score_idx, "100")
	await _ui.wait_frames()

	assert_eq(story.variables[score_idx].initial_value, "100",
		"Variable value should be '100'")


func test_delete_variable():
	await _load_story_with_variable()

	_main._nav_ctrl.on_variables_pressed()
	await _ui.wait_frames(5)

	var story = _main._editor_main._story
	# Ajouter 2 variables
	_main._variable_panel.add_variable()
	_main._variable_panel.add_variable()
	await _ui.wait_frames()

	var count_before = story.variables.size()

	# Supprimer la dernière
	_main._variable_panel.remove_variable(count_before - 1)
	await _ui.wait_frames()

	assert_eq(story.variables.size(), count_before - 1,
		"Should have one less variable after delete")


func test_show_on_main_toggle():
	await _load_story_with_variable()

	_main._nav_ctrl.on_variables_pressed()
	await _ui.wait_frames(5)

	var story = _main._editor_main._story
	# La story "with_two_sequences" a la variable "score"
	var score_idx = -1
	for i in story.variables.size():
		if story.variables[i].var_name == "score":
			score_idx = i
			break
	assert_true(score_idx >= 0)

	# Activer show_on_main
	_main._variable_panel.update_show_on_main(score_idx, true)
	await _ui.wait_frames()

	assert_true(story.variables[score_idx].show_on_main,
		"show_on_main should be true after toggle")
