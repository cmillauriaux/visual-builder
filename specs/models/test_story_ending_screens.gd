extends GutTest

const Story = preload("res://src/models/story.gd")

# Tests pour les champs d'écrans de fin du modèle Story (Game Over, To Be Continued)


func test_default_values():
	var story = Story.new()
	assert_eq(story.game_over_title, "")
	assert_eq(story.game_over_subtitle, "")
	assert_eq(story.game_over_background, "")
	assert_eq(story.to_be_continued_title, "")
	assert_eq(story.to_be_continued_subtitle, "")
	assert_eq(story.to_be_continued_background, "")


func test_to_dict_has_screens_block():
	var story = Story.new()
	var d = story.to_dict()
	assert_true(d.has("screens"), "to_dict doit contenir un bloc 'screens'")
	assert_true(d["screens"].has("game_over"))
	assert_true(d["screens"].has("to_be_continued"))


func test_to_dict_game_over_fields():
	var story = Story.new()
	story.game_over_title = "Game Over!"
	story.game_over_subtitle = "Tu as perdu"
	story.game_over_background = "backgrounds/game_over.png"
	var d = story.to_dict()
	var go = d["screens"]["game_over"]
	assert_eq(go["title"], "Game Over!")
	assert_eq(go["subtitle"], "Tu as perdu")
	assert_eq(go["background"], "backgrounds/game_over.png")


func test_to_dict_to_be_continued_fields():
	var story = Story.new()
	story.to_be_continued_title = "À suivre..."
	story.to_be_continued_subtitle = "Prochain épisode"
	story.to_be_continued_background = "backgrounds/tbc.png"
	var d = story.to_dict()
	var tbc = d["screens"]["to_be_continued"]
	assert_eq(tbc["title"], "À suivre...")
	assert_eq(tbc["subtitle"], "Prochain épisode")
	assert_eq(tbc["background"], "backgrounds/tbc.png")


func test_from_dict_restores_game_over():
	var d = {
		"title": "Test",
		"screens": {
			"game_over": {
				"title": "Game Over!",
				"subtitle": "Réessaye",
				"background": "bg.png",
			},
		},
	}
	var story = Story.from_dict(d)
	assert_eq(story.game_over_title, "Game Over!")
	assert_eq(story.game_over_subtitle, "Réessaye")
	assert_eq(story.game_over_background, "bg.png")


func test_from_dict_restores_to_be_continued():
	var d = {
		"title": "Test",
		"screens": {
			"to_be_continued": {
				"title": "Suite...",
				"subtitle": "Bientôt",
				"background": "tbc.png",
			},
		},
	}
	var story = Story.from_dict(d)
	assert_eq(story.to_be_continued_title, "Suite...")
	assert_eq(story.to_be_continued_subtitle, "Bientôt")
	assert_eq(story.to_be_continued_background, "tbc.png")


func test_from_dict_missing_screens_block():
	var d = {"title": "Old Story"}
	var story = Story.from_dict(d)
	assert_eq(story.game_over_title, "")
	assert_eq(story.game_over_subtitle, "")
	assert_eq(story.game_over_background, "")
	assert_eq(story.to_be_continued_title, "")
	assert_eq(story.to_be_continued_subtitle, "")
	assert_eq(story.to_be_continued_background, "")


func test_from_dict_missing_sub_blocks():
	var d = {"title": "Test", "screens": {}}
	var story = Story.from_dict(d)
	assert_eq(story.game_over_title, "")
	assert_eq(story.to_be_continued_title, "")


func test_roundtrip():
	var story = Story.new()
	story.game_over_title = "Perdu"
	story.game_over_subtitle = "Retente"
	story.game_over_background = "go_bg.png"
	story.to_be_continued_title = "À suivre"
	story.to_be_continued_subtitle = "Episode 2"
	story.to_be_continued_background = "tbc_bg.png"
	var d = story.to_dict()
	var restored = Story.from_dict(d)
	assert_eq(restored.game_over_title, "Perdu")
	assert_eq(restored.game_over_subtitle, "Retente")
	assert_eq(restored.game_over_background, "go_bg.png")
	assert_eq(restored.to_be_continued_title, "À suivre")
	assert_eq(restored.to_be_continued_subtitle, "Episode 2")
	assert_eq(restored.to_be_continued_background, "tbc_bg.png")
