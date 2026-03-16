extends GutTest

const Story = preload("res://src/models/story.gd")

# Tests pour plugin_settings dans le modèle Story (remplace les anciens champs playfab)


func test_plugin_settings_default_empty():
	var story = Story.new()
	assert_eq(story.plugin_settings.size(), 0, "plugin_settings doit être vide par défaut")


func test_plugin_settings_to_dict():
	var story = Story.new()
	story.plugin_settings = {"playfab_analytics": {"title_id": "ABC123", "enabled": true}}
	var d = story.to_dict()
	assert_true(d.has("plugin_settings"), "to_dict doit contenir 'plugin_settings'")
	assert_eq(d["plugin_settings"]["playfab_analytics"]["title_id"], "ABC123")
	assert_eq(d["plugin_settings"]["playfab_analytics"]["enabled"], true)


func test_plugin_settings_to_dict_empty():
	var story = Story.new()
	var d = story.to_dict()
	assert_true(d.has("plugin_settings"))
	assert_eq(d["plugin_settings"].size(), 0)


func test_plugin_settings_from_dict():
	var d = {
		"title": "Test",
		"plugin_settings": {
			"playfab_analytics": {"title_id": "XYZ789", "enabled": true},
		},
	}
	var story = Story.from_dict(d)
	assert_eq(story.plugin_settings["playfab_analytics"]["title_id"], "XYZ789")
	assert_eq(story.plugin_settings["playfab_analytics"]["enabled"], true)


func test_plugin_settings_from_dict_missing():
	var d = {"title": "Old Story"}
	var story = Story.from_dict(d)
	assert_eq(story.plugin_settings.size(), 0)


func test_plugin_settings_from_dict_partial():
	var d = {
		"title": "Test",
		"plugin_settings": {
			"playfab_analytics": {"title_id": "PARTIAL"},
		},
	}
	var story = Story.from_dict(d)
	assert_eq(story.plugin_settings["playfab_analytics"]["title_id"], "PARTIAL")


# Rétrocompatibilité : l'ancien format "playfab" est migré vers plugin_settings

func test_retrocompat_playfab_to_plugin_settings():
	var d = {
		"title": "Old Story",
		"playfab": {"title_id": "OLD123", "enabled": true},
	}
	var story = Story.from_dict(d)
	assert_true(story.plugin_settings.has("playfab_analytics"))
	assert_eq(story.plugin_settings["playfab_analytics"]["title_id"], "OLD123")
	assert_eq(story.plugin_settings["playfab_analytics"]["enabled"], true)


func test_retrocompat_playfab_partial():
	var d = {
		"title": "Old Story",
		"playfab": {"title_id": "PARTIAL_OLD"},
	}
	var story = Story.from_dict(d)
	assert_eq(story.plugin_settings["playfab_analytics"]["title_id"], "PARTIAL_OLD")
	assert_eq(story.plugin_settings["playfab_analytics"]["enabled"], false)


func test_plugin_settings_takes_precedence_over_playfab():
	var d = {
		"title": "Test",
		"plugin_settings": {"playfab_analytics": {"title_id": "NEW", "enabled": true}},
		"playfab": {"title_id": "OLD", "enabled": false},
	}
	var story = Story.from_dict(d)
	assert_eq(story.plugin_settings["playfab_analytics"]["title_id"], "NEW")
	assert_eq(story.plugin_settings["playfab_analytics"]["enabled"], true)
