extends GutTest

const StoryI18nService = preload("res://src/services/story_i18n_service.gd")
const Story = preload("res://src/models/story.gd")


func _make_story_with_launcher(launcher_cfg: Dictionary = {}) -> RefCounted:
	var story = Story.new()
	story.title = "Test"
	story.plugin_settings["launcher"] = launcher_cfg
	return story


# --- extract_strings ---

func test_extract_strings_includes_disclaimer_text():
	var story = _make_story_with_launcher({
		"disclaimer_enabled": true,
		"disclaimer_text": "Ce jeu est une fiction.",
	})
	var strings = StoryI18nService.extract_strings(story)
	assert_true(strings.has("Ce jeu est une fiction."))


func test_extract_strings_includes_free_text_content():
	var story = _make_story_with_launcher({
		"free_text_enabled": true,
		"free_text_content": "Merci de jouer",
	})
	var strings = StoryI18nService.extract_strings(story)
	assert_true(strings.has("Merci de jouer"))


func test_extract_strings_includes_studio_logo_fallback_text():
	var story = _make_story_with_launcher({
		"studio_logo_enabled": true,
		"studio_logo_fallback_text": "Mon Studio",
	})
	var strings = StoryI18nService.extract_strings(story)
	assert_true(strings.has("Mon Studio"))


func test_extract_strings_ignores_empty_launcher_texts():
	var story = _make_story_with_launcher({
		"disclaimer_text": "",
		"free_text_content": "",
		"studio_logo_fallback_text": "",
	})
	var strings = StoryI18nService.extract_strings(story)
	assert_false(strings.has(""))


func test_extract_strings_no_launcher_settings():
	var story = Story.new()
	story.title = "Test"
	# Pas de plugin_settings["launcher"] => pas d'erreur
	var strings = StoryI18nService.extract_strings(story)
	assert_true(strings.has("Test"))


# --- apply_to_story ---

func test_apply_translations_translates_disclaimer():
	var story = _make_story_with_launcher({
		"disclaimer_enabled": true,
		"disclaimer_text": "Ce jeu est une fiction.",
	})
	var i18n = {"Ce jeu est une fiction.": "This game is a work of fiction."}
	StoryI18nService.apply_to_story(story, i18n)
	assert_eq(story.plugin_settings["launcher"]["disclaimer_text"], "This game is a work of fiction.")


func test_apply_translations_translates_free_text():
	var story = _make_story_with_launcher({
		"free_text_enabled": true,
		"free_text_content": "Merci de jouer",
	})
	var i18n = {"Merci de jouer": "Thanks for playing"}
	StoryI18nService.apply_to_story(story, i18n)
	assert_eq(story.plugin_settings["launcher"]["free_text_content"], "Thanks for playing")


func test_apply_translations_translates_studio_fallback():
	var story = _make_story_with_launcher({
		"studio_logo_enabled": true,
		"studio_logo_fallback_text": "Mon Studio",
	})
	var i18n = {"Mon Studio": "My Studio"}
	StoryI18nService.apply_to_story(story, i18n)
	assert_eq(story.plugin_settings["launcher"]["studio_logo_fallback_text"], "My Studio")


func test_apply_translations_keeps_source_if_missing():
	var story = _make_story_with_launcher({
		"disclaimer_text": "Ce jeu est une fiction.",
	})
	var i18n = {}
	StoryI18nService.apply_to_story(story, i18n)
	assert_eq(story.plugin_settings["launcher"]["disclaimer_text"], "Ce jeu est une fiction.")


func test_apply_translations_no_launcher_settings():
	var story = Story.new()
	story.title = "Test"
	var i18n = {"Test": "Test EN"}
	# Pas de plugin_settings["launcher"] => pas d'erreur
	StoryI18nService.apply_to_story(story, i18n)
	assert_eq(story.title, "Test EN")
