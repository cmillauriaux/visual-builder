extends GutTest

const StoryScript = preload("res://src/models/story.gd")
const VariableDefinitionScript = preload("res://src/models/variable_definition.gd")

# --- Champ variables ---

func test_story_has_variables_array():
	var story = StoryScript.new()
	assert_eq(story.variables.size(), 0, "variables initialisé vide")

func test_add_variable_to_story():
	var story = StoryScript.new()
	var v = VariableDefinitionScript.new()
	v.var_name = "score"
	v.initial_value = "0"
	story.variables.append(v)
	assert_eq(story.variables.size(), 1)

# --- find_variable ---

func test_find_variable_found():
	var story = _story_with_vars(["score", "hp"])
	var found = story.find_variable("hp")
	assert_not_null(found)
	assert_eq(found.var_name, "hp")

func test_find_variable_not_found():
	var story = _story_with_vars(["score"])
	var found = story.find_variable("nonexistent")
	assert_null(found)

func test_find_variable_empty_list():
	var story = StoryScript.new()
	assert_null(story.find_variable("any"))

# --- get_variable_names ---

func test_get_variable_names():
	var story = _story_with_vars(["score", "hp", "has_key"])
	var names = story.get_variable_names()
	assert_eq(names.size(), 3)
	assert_has(names, "score")
	assert_has(names, "hp")
	assert_has(names, "has_key")

func test_get_variable_names_empty():
	var story = StoryScript.new()
	var names = story.get_variable_names()
	assert_eq(names.size(), 0)

# --- Sérialisation ---

func test_to_dict_includes_variables():
	var story = _story_with_vars(["score", "hp"])
	story.variables[0].initial_value = "0"
	story.variables[1].initial_value = "100"
	var d = story.to_dict()
	assert_true(d.has("variables"))
	assert_eq(d["variables"].size(), 2)
	assert_eq(d["variables"][0]["name"], "score")
	assert_eq(d["variables"][0]["initial_value"], "0")
	assert_eq(d["variables"][1]["name"], "hp")

func test_from_dict_loads_variables():
	var d = {
		"title": "Test",
		"variables": [
			{"name": "score", "initial_value": "0"},
			{"name": "hp", "initial_value": "100"},
		]
	}
	var story = StoryScript.from_dict(d)
	assert_eq(story.variables.size(), 2)
	assert_eq(story.variables[0].var_name, "score")
	assert_eq(story.variables[0].initial_value, "0")
	assert_eq(story.variables[1].var_name, "hp")
	assert_eq(story.variables[1].initial_value, "100")

func test_from_dict_without_variables_retrocompat():
	var d = {"title": "Old Story"}
	var story = StoryScript.from_dict(d)
	assert_eq(story.variables.size(), 0, "Rétrocompatibilité : pas de variables")

func test_roundtrip_variables():
	var story = _story_with_vars(["a", "b"])
	story.variables[0].initial_value = "10"
	story.variables[1].initial_value = "hello"
	var story2 = StoryScript.from_dict(story.to_dict())
	assert_eq(story2.variables.size(), 2)
	assert_eq(story2.variables[0].var_name, "a")
	assert_eq(story2.variables[0].initial_value, "10")
	assert_eq(story2.variables[1].var_name, "b")
	assert_eq(story2.variables[1].initial_value, "hello")

# --- Helper ---

func _story_with_vars(names: Array) -> RefCounted:
	var story = StoryScript.new()
	for n in names:
		var v = VariableDefinitionScript.new()
		v.var_name = n
		story.variables.append(v)
	return story
