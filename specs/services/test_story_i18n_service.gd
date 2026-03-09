extends GutTest

var StoryI18nServiceScript

func before_each():
	StoryI18nServiceScript = load("res://src/services/story_i18n_service.gd")

func test_get_locales_list():
	var svc = StoryI18nServiceScript.new()
	var locales = svc.get_locales_list()
	assert_true(locales is Array, "Locales list should be an Array")
	assert_gt(locales.size(), 0, "Locales list should not be empty")

func test_set_current_locale():
	var svc = StoryI18nServiceScript.new()
	svc.set_current_locale("fr")
	assert_eq(svc.get_current_locale(), "fr", "Current locale should be set to 'fr'")
	svc.set_current_locale("en")
	assert_eq(svc.get_current_locale(), "en", "Current locale should be set to 'en'")

func test_translate_key_not_found():
	var svc = StoryI18nServiceScript.new()
	var translation = svc.translate("nonexistent_key")
	assert_eq(translation, "nonexistent_key", "Missing translation should return the key itself")
