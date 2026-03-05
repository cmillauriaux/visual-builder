extends GutTest

const Story = preload("res://src/models/story.gd")

# Tests pour les champs de liens externes du modèle Story


func test_links_default_values():
	var story = Story.new()
	assert_eq(story.patreon_url, "", "patreon_url doit être vide par défaut")
	assert_eq(story.itchio_url, "", "itchio_url doit être vide par défaut")


func test_links_to_dict():
	var story = Story.new()
	story.patreon_url = "https://www.patreon.com/mygame"
	story.itchio_url = "https://mygame.itch.io/game"
	var d = story.to_dict()
	assert_true(d.has("links"), "to_dict doit contenir une clé 'links'")
	assert_eq(d["links"]["patreon"], "https://www.patreon.com/mygame")
	assert_eq(d["links"]["itchio"], "https://mygame.itch.io/game")


func test_links_to_dict_empty():
	var story = Story.new()
	var d = story.to_dict()
	assert_true(d.has("links"))
	assert_eq(d["links"]["patreon"], "")
	assert_eq(d["links"]["itchio"], "")


func test_links_from_dict():
	var d = {
		"title": "Test",
		"links": {
			"patreon": "https://www.patreon.com/test",
			"itchio": "https://test.itch.io/game",
		},
	}
	var story = Story.from_dict(d)
	assert_eq(story.patreon_url, "https://www.patreon.com/test")
	assert_eq(story.itchio_url, "https://test.itch.io/game")


func test_links_from_dict_missing():
	var d = {"title": "Old Story"}
	var story = Story.from_dict(d)
	assert_eq(story.patreon_url, "")
	assert_eq(story.itchio_url, "")


func test_links_from_dict_partial():
	var d = {
		"title": "Test",
		"links": {
			"patreon": "https://www.patreon.com/partial",
		},
	}
	var story = Story.from_dict(d)
	assert_eq(story.patreon_url, "https://www.patreon.com/partial")
	assert_eq(story.itchio_url, "")
