extends GutTest

const Story = preload("res://src/models/story.gd")

# Tests pour les champs PlayFab du modèle Story


func test_playfab_default_values():
	var story = Story.new()
	assert_eq(story.playfab_title_id, "", "playfab_title_id doit être vide par défaut")
	assert_eq(story.playfab_enabled, false, "playfab_enabled doit être false par défaut")


func test_playfab_to_dict():
	var story = Story.new()
	story.playfab_title_id = "ABC123"
	story.playfab_enabled = true
	var d = story.to_dict()
	assert_true(d.has("playfab"), "to_dict doit contenir une clé 'playfab'")
	assert_eq(d["playfab"]["title_id"], "ABC123")
	assert_eq(d["playfab"]["enabled"], true)


func test_playfab_to_dict_disabled():
	var story = Story.new()
	var d = story.to_dict()
	assert_true(d.has("playfab"))
	assert_eq(d["playfab"]["title_id"], "")
	assert_eq(d["playfab"]["enabled"], false)


func test_playfab_from_dict():
	var d = {
		"title": "Test",
		"playfab": {
			"title_id": "XYZ789",
			"enabled": true,
		},
	}
	var story = Story.from_dict(d)
	assert_eq(story.playfab_title_id, "XYZ789")
	assert_eq(story.playfab_enabled, true)


func test_playfab_from_dict_missing():
	var d = {"title": "Old Story"}
	var story = Story.from_dict(d)
	assert_eq(story.playfab_title_id, "")
	assert_eq(story.playfab_enabled, false)


func test_playfab_from_dict_partial():
	var d = {
		"title": "Test",
		"playfab": {
			"title_id": "PARTIAL",
		},
	}
	var story = Story.from_dict(d)
	assert_eq(story.playfab_title_id, "PARTIAL")
	assert_eq(story.playfab_enabled, false)
