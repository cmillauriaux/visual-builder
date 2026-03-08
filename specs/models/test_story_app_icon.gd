extends GutTest

const Story = preload("res://src/models/story.gd")

# Tests pour le champ app_icon du modèle Story


func test_default_value():
	var story = Story.new()
	assert_eq(story.app_icon, "")


func test_to_dict_has_app_icon():
	var story = Story.new()
	var d = story.to_dict()
	assert_true(d.has("app_icon"), "to_dict doit contenir 'app_icon'")


func test_to_dict_app_icon_value():
	var story = Story.new()
	story.app_icon = "icon_1024.png"
	var d = story.to_dict()
	assert_eq(d["app_icon"], "icon_1024.png")


func test_from_dict_restores_app_icon():
	var d = {
		"title": "Test",
		"app_icon": "my_icon.png",
	}
	var story = Story.from_dict(d)
	assert_eq(story.app_icon, "my_icon.png")


func test_from_dict_missing_app_icon():
	var d = {"title": "Old Story"}
	var story = Story.from_dict(d)
	assert_eq(story.app_icon, "")


func test_roundtrip():
	var story = Story.new()
	story.app_icon = "custom_icon.png"
	var d = story.to_dict()
	var restored = Story.from_dict(d)
	assert_eq(restored.app_icon, "custom_icon.png")
