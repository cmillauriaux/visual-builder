extends GutTest

## Tests pour le champ menu_music du modèle Story.

const Story = preload("res://src/models/story.gd")


func test_menu_music_default_empty():
	var story = Story.new()
	assert_eq(story.menu_music, "")


func test_menu_music_to_dict():
	var story = Story.new()
	story.menu_music = "/path/to/menu_theme.ogg"
	var dict = story.to_dict()
	assert_eq(dict["menu_music"], "/path/to/menu_theme.ogg")


func test_menu_music_from_dict():
	var dict = {
		"title": "Test Story",
		"author": "",
		"description": "",
		"version": "1.0.0",
		"created_at": "2026-01-01T00:00:00Z",
		"updated_at": "2026-01-01T00:00:00Z",
		"menu_music": "/path/to/menu.ogg",
		"chapters": [],
		"variables": [],
		"notifications": [],
		"connections": [],
		"entry_point": "",
	}
	var story = Story.from_dict(dict)
	assert_eq(story.menu_music, "/path/to/menu.ogg")


func test_menu_music_retrocompat():
	# Ancien format sans menu_music — doit valoir "" par défaut
	var dict = {
		"title": "Old Story",
		"author": "",
		"description": "",
		"version": "1.0.0",
		"created_at": "2026-01-01T00:00:00Z",
		"updated_at": "2026-01-01T00:00:00Z",
		"chapters": [],
		"variables": [],
		"notifications": [],
		"connections": [],
		"entry_point": "",
	}
	var story = Story.from_dict(dict)
	assert_eq(story.menu_music, "")


func test_menu_music_roundtrip():
	var story = Story.new()
	story.menu_music = "/music/menu_theme.ogg"
	var dict = story.to_dict()
	var restored = Story.from_dict(dict)
	assert_eq(restored.menu_music, "/music/menu_theme.ogg")
