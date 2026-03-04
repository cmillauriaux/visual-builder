extends GutTest

const StoryI18nService = preload("res://src/services/story_i18n_service.gd")
const Story = preload("res://src/models/story.gd")
const VariableDefinition = preload("res://src/models/variable_definition.gd")
const Chapter = preload("res://src/models/chapter.gd")


func _make_story_with_vars() -> RefCounted:
	var story = Story.new()
	story.title = "Test"
	var v1 = VariableDefinition.new()
	v1.var_name = "score"
	v1.description = "Votre score actuel"
	story.variables.append(v1)
	var v2 = VariableDefinition.new()
	v2.var_name = "health"
	v2.description = "Points de vie"
	story.variables.append(v2)
	return story


func test_extract_strings_includes_variable_descriptions():
	var story = _make_story_with_vars()
	var strings = StoryI18nService.extract_strings(story)
	assert_true(strings.has("Votre score actuel"))
	assert_true(strings.has("Points de vie"))


func test_extract_strings_ignores_empty_descriptions():
	var story = Story.new()
	story.title = "Test"
	var v = VariableDefinition.new()
	v.var_name = "score"
	v.description = ""
	story.variables.append(v)
	var strings = StoryI18nService.extract_strings(story)
	assert_false(strings.has(""))


func test_apply_translations_translates_descriptions():
	var story = _make_story_with_vars()
	var i18n = {
		"Votre score actuel": "Your current score",
		"Points de vie": "Health points",
	}
	StoryI18nService.apply_to_story(story, i18n)
	assert_eq(story.variables[0].description, "Your current score")
	assert_eq(story.variables[1].description, "Health points")


func test_apply_translations_keeps_source_if_missing():
	var story = _make_story_with_vars()
	var i18n = {}
	StoryI18nService.apply_to_story(story, i18n)
	assert_eq(story.variables[0].description, "Votre score actuel")
	assert_eq(story.variables[1].description, "Points de vie")


func test_ui_strings_contains_details_and_close():
	assert_true(StoryI18nService.UI_STRINGS.has("Détails"))
	assert_true(StoryI18nService.UI_STRINGS.has("Fermer"))
