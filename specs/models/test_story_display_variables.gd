extends GutTest

const StoryScript = preload("res://src/models/story.gd")
const VariableDefinitionScript = preload("res://src/models/variable_definition.gd")


func _make_var(vname: String, on_main: bool, on_details: bool) -> RefCounted:
	var v = VariableDefinitionScript.new()
	v.var_name = vname
	v.show_on_main = on_main
	v.show_on_details = on_details
	return v


func test_get_main_display_variables_empty():
	var story = StoryScript.new()
	assert_eq(story.get_main_display_variables().size(), 0)


func test_get_main_display_variables_none_marked():
	var story = StoryScript.new()
	story.variables.append(_make_var("a", false, false))
	story.variables.append(_make_var("b", false, true))
	assert_eq(story.get_main_display_variables().size(), 0)


func test_get_main_display_variables_filtered():
	var story = StoryScript.new()
	story.variables.append(_make_var("a", true, false))
	story.variables.append(_make_var("b", false, false))
	story.variables.append(_make_var("c", true, true))
	var result = story.get_main_display_variables()
	assert_eq(result.size(), 2)
	assert_eq(result[0].var_name, "a")
	assert_eq(result[1].var_name, "c")


func test_get_details_display_variables_empty():
	var story = StoryScript.new()
	assert_eq(story.get_details_display_variables().size(), 0)


func test_get_details_display_variables_none_marked():
	var story = StoryScript.new()
	story.variables.append(_make_var("a", true, false))
	story.variables.append(_make_var("b", false, false))
	assert_eq(story.get_details_display_variables().size(), 0)


func test_get_details_display_variables_filtered():
	var story = StoryScript.new()
	story.variables.append(_make_var("a", false, true))
	story.variables.append(_make_var("b", false, false))
	story.variables.append(_make_var("c", true, true))
	var result = story.get_details_display_variables()
	assert_eq(result.size(), 2)
	assert_eq(result[0].var_name, "a")
	assert_eq(result[1].var_name, "c")


func test_get_both_display_types():
	var story = StoryScript.new()
	var v = _make_var("score", true, true)
	story.variables.append(v)
	assert_eq(story.get_main_display_variables().size(), 1)
	assert_eq(story.get_details_display_variables().size(), 1)
	assert_eq(story.get_main_display_variables()[0].var_name, "score")
	assert_eq(story.get_details_display_variables()[0].var_name, "score")
