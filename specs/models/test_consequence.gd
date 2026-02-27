extends GutTest

const Consequence = preload("res://src/models/consequence.gd")

# Tests pour le modèle Consequence
# Types valides : redirect_sequence, redirect_scene, redirect_chapter, game_over, to_be_continued

func test_create_redirect_sequence():
	var c = Consequence.new()
	c.type = "redirect_sequence"
	c.target = "seq-002"
	assert_eq(c.type, "redirect_sequence")
	assert_eq(c.target, "seq-002")

func test_create_redirect_scene():
	var c = Consequence.new()
	c.type = "redirect_scene"
	c.target = "scene-003"
	assert_eq(c.type, "redirect_scene")
	assert_eq(c.target, "scene-003")

func test_create_redirect_chapter():
	var c = Consequence.new()
	c.type = "redirect_chapter"
	c.target = "chapter-001"
	assert_eq(c.type, "redirect_chapter")
	assert_eq(c.target, "chapter-001")

func test_create_game_over():
	var c = Consequence.new()
	c.type = "game_over"
	assert_eq(c.type, "game_over")
	assert_eq(c.target, "", "game_over ne doit pas avoir de cible")

func test_create_to_be_continued():
	var c = Consequence.new()
	c.type = "to_be_continued"
	assert_eq(c.type, "to_be_continued")
	assert_eq(c.target, "", "to_be_continued ne doit pas avoir de cible")

func test_default_values():
	var c = Consequence.new()
	assert_eq(c.type, "")
	assert_eq(c.target, "")

func test_to_dict():
	var c = Consequence.new()
	c.type = "redirect_sequence"
	c.target = "seq-002"
	var d = c.to_dict()
	assert_eq(d["type"], "redirect_sequence")
	assert_eq(d["target"], "seq-002")

func test_to_dict_without_target():
	var c = Consequence.new()
	c.type = "game_over"
	var d = c.to_dict()
	assert_eq(d["type"], "game_over")
	assert_false(d.has("target"), "game_over ne doit pas inclure target dans le dict")

func test_from_dict():
	var d = {"type": "redirect_scene", "target": "scene-003"}
	var c = Consequence.from_dict(d)
	assert_eq(c.type, "redirect_scene")
	assert_eq(c.target, "scene-003")

func test_from_dict_without_target():
	var d = {"type": "game_over"}
	var c = Consequence.from_dict(d)
	assert_eq(c.type, "game_over")
	assert_eq(c.target, "")

func test_valid_types():
	var valid_types = ["redirect_sequence", "redirect_scene", "redirect_chapter", "game_over", "to_be_continued"]
	for t in valid_types:
		var c = Consequence.new()
		c.type = t
		if t in Consequence.REDIRECT_TYPES:
			c.target = "some-uuid"
		assert_true(c.is_valid(), "Le type '%s' devrait être valide" % t)

func test_invalid_type():
	var c = Consequence.new()
	c.type = "invalid_type"
	assert_false(c.is_valid(), "Un type invalide ne devrait pas être valide")

func test_empty_type_is_invalid():
	var c = Consequence.new()
	assert_false(c.is_valid(), "Un type vide ne devrait pas être valide")

func test_redirect_types_require_target():
	var redirect_types = ["redirect_sequence", "redirect_scene", "redirect_chapter"]
	for t in redirect_types:
		var c = Consequence.new()
		c.type = t
		assert_false(c.is_valid(), "Le type '%s' sans target ne devrait pas être valide" % t)
		c.target = "some-uuid"
		assert_true(c.is_valid(), "Le type '%s' avec target devrait être valide" % t)
