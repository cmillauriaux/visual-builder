extends GutTest

var VariablePanelScript = load("res://src/ui/editors/variable_panel.gd")
var StoryScript = load("res://src/models/story.gd")
var VariableDefinitionScript = load("res://src/models/variable_definition.gd")

var _panel: VBoxContainer

func before_each():
	_panel = VBoxContainer.new()
	_panel.set_script(VariablePanelScript)
	add_child(_panel)

func after_each():
	_panel.queue_free()

# --- Chargement ---

func test_load_story_empty_variables():
	var story = StoryScript.new()
	_panel.load_story(story)
	assert_eq(_panel.get_variable_count(), 0)

func test_load_story_with_variables():
	var story = _make_story_with_vars({"score": "0", "hp": "100"})
	_panel.load_story(story)
	assert_eq(_panel.get_variable_count(), 2)

# --- Ajout ---

func test_add_variable():
	var story = StoryScript.new()
	_panel.load_story(story)
	_panel.add_variable()
	assert_eq(story.variables.size(), 1)
	assert_eq(_panel.get_variable_count(), 1)

func test_add_multiple_variables():
	var story = StoryScript.new()
	_panel.load_story(story)
	_panel.add_variable()
	_panel.add_variable()
	assert_eq(story.variables.size(), 2)

# --- Suppression ---

func test_remove_variable():
	var story = _make_story_with_vars({"a": "1", "b": "2", "c": "3"})
	_panel.load_story(story)
	_panel.remove_variable(1)
	assert_eq(story.variables.size(), 2)
	assert_eq(story.variables[0].var_name, "a")
	assert_eq(story.variables[1].var_name, "c")

func test_remove_variable_invalid_index():
	var story = _make_story_with_vars({"a": "1"})
	_panel.load_story(story)
	_panel.remove_variable(-1)
	_panel.remove_variable(5)
	assert_eq(story.variables.size(), 1, "Pas de suppression avec index invalide")

# --- Modification ---

func test_update_variable_name():
	var story = _make_story_with_vars({"score": "0"})
	_panel.load_story(story)
	_panel.update_variable_name(0, "points")
	assert_eq(story.variables[0].var_name, "points")

func test_update_variable_value():
	var story = _make_story_with_vars({"score": "0"})
	_panel.load_story(story)
	_panel.update_variable_value(0, "50")
	assert_eq(story.variables[0].initial_value, "50")

# --- Validation des doublons ---

func test_duplicate_name_rejected():
	var story = _make_story_with_vars({"score": "0", "hp": "100"})
	_panel.load_story(story)
	var accepted = _panel.update_variable_name(1, "score")
	assert_false(accepted, "Nom en doublon rejeté")
	assert_eq(story.variables[1].var_name, "hp", "Nom non modifié")

func test_unique_name_accepted():
	var story = _make_story_with_vars({"score": "0", "hp": "100"})
	_panel.load_story(story)
	var accepted = _panel.update_variable_name(1, "mana")
	assert_true(accepted, "Nom unique accepté")
	assert_eq(story.variables[1].var_name, "mana")

func test_same_name_as_self_accepted():
	var story = _make_story_with_vars({"score": "0"})
	_panel.load_story(story)
	var accepted = _panel.update_variable_name(0, "score")
	assert_true(accepted, "Même nom que soi-même accepté")

# --- Signal ---

func test_signal_emitted_on_add():
	var story = StoryScript.new()
	_panel.load_story(story)
	watch_signals(_panel)
	_panel.add_variable()
	assert_signal_emitted(_panel, "variables_changed")

func test_signal_emitted_on_remove():
	var story = _make_story_with_vars({"a": "1"})
	_panel.load_story(story)
	watch_signals(_panel)
	_panel.remove_variable(0)
	assert_signal_emitted(_panel, "variables_changed")

func test_signal_emitted_on_name_update():
	var story = _make_story_with_vars({"a": "1"})
	_panel.load_story(story)
	watch_signals(_panel)
	_panel.update_variable_name(0, "b")
	assert_signal_emitted(_panel, "variables_changed")

# --- Helpers ---

func _make_story_with_vars(vars: Dictionary):
	var story = StoryScript.new()
	for key in vars:
		var v = VariableDefinitionScript.new()
		v.var_name = key
		v.initial_value = vars[key]
		story.variables.append(v)
	return story
