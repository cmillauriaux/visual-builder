extends GutTest

const Consequence = preload("res://src/models/consequence.gd")
const Choice = preload("res://src/models/choice.gd")

# Tests pour le modèle Choice

func test_create_choice():
	var c = Choice.new()
	c.text = "Explorer le chemin de gauche"
	c.consequence = Consequence.new()
	c.consequence.type = "redirect_sequence"
	c.consequence.target = "seq-002"
	assert_eq(c.text, "Explorer le chemin de gauche")
	assert_eq(c.consequence.type, "redirect_sequence")

func test_default_values():
	var c = Choice.new()
	assert_eq(c.text, "")
	assert_null(c.consequence)
	assert_true(c.conditions is Dictionary)
	assert_eq(c.conditions.size(), 0)

func test_conditions_empty_by_default():
	var c = Choice.new()
	assert_eq(c.conditions, {}, "Le champ conditions doit être un dict vide par défaut")

func test_to_dict():
	var c = Choice.new()
	c.text = "Abandonner"
	c.consequence = Consequence.new()
	c.consequence.type = "game_over"
	var d = c.to_dict()
	assert_eq(d["text"], "Abandonner")
	assert_eq(d["consequence"]["type"], "game_over")
	assert_true(d.has("conditions"), "Le dict doit inclure conditions")
	assert_eq(d["conditions"], {})

func test_from_dict():
	var d = {
		"text": "Faire demi-tour",
		"consequence": {"type": "redirect_scene", "target": "scene-003"},
		"conditions": {}
	}
	var c = Choice.from_dict(d)
	assert_eq(c.text, "Faire demi-tour")
	assert_eq(c.consequence.type, "redirect_scene")
	assert_eq(c.consequence.target, "scene-003")
	assert_eq(c.conditions, {})

func test_from_dict_without_conditions():
	var d = {
		"text": "Test",
		"consequence": {"type": "game_over"}
	}
	var c = Choice.from_dict(d)
	assert_eq(c.conditions, {}, "conditions doit être {} même si absent du dict")
