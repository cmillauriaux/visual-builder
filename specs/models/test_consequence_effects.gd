extends GutTest

const ConsequenceScript = preload("res://src/models/consequence.gd")
const VariableEffectScript = preload("res://src/models/variable_effect.gd")

# --- Champ effects ---

func test_consequence_has_effects_array():
	var c = ConsequenceScript.new()
	assert_eq(c.effects.size(), 0, "effects initialisé vide")

func test_add_effect_to_consequence():
	var c = ConsequenceScript.new()
	c.type = "redirect_sequence"
	c.target = "uuid-123"
	var e = VariableEffectScript.new()
	e.variable = "score"
	e.operation = "increment"
	e.value = "10"
	c.effects.append(e)
	assert_eq(c.effects.size(), 1)

# --- Sérialisation ---

func test_to_dict_with_effects():
	var c = ConsequenceScript.new()
	c.type = "redirect_sequence"
	c.target = "uuid-123"
	var e = VariableEffectScript.new()
	e.variable = "score"
	e.operation = "set"
	e.value = "100"
	c.effects.append(e)
	var d = c.to_dict()
	assert_true(d.has("effects"))
	assert_eq(d["effects"].size(), 1)
	assert_eq(d["effects"][0]["variable"], "score")
	assert_eq(d["effects"][0]["operation"], "set")
	assert_eq(d["effects"][0]["value"], "100")

func test_to_dict_without_effects():
	var c = ConsequenceScript.new()
	c.type = "game_over"
	var d = c.to_dict()
	assert_true(d.has("effects"))
	assert_eq(d["effects"].size(), 0)

func test_from_dict_with_effects():
	var d = {
		"type": "redirect_sequence",
		"target": "uuid-456",
		"effects": [
			{"variable": "hp", "operation": "decrement", "value": "5"},
			{"variable": "visited", "operation": "set", "value": "true"},
		]
	}
	var c = ConsequenceScript.from_dict(d)
	assert_eq(c.effects.size(), 2)
	assert_eq(c.effects[0].variable, "hp")
	assert_eq(c.effects[0].operation, "decrement")
	assert_eq(c.effects[1].variable, "visited")
	assert_eq(c.effects[1].operation, "set")

func test_from_dict_without_effects_retrocompat():
	var d = {"type": "game_over"}
	var c = ConsequenceScript.from_dict(d)
	assert_eq(c.effects.size(), 0, "Rétrocompatibilité : pas d'effets")

func test_roundtrip_with_effects():
	var c = ConsequenceScript.new()
	c.type = "redirect_chapter"
	c.target = "ch-1"
	var e1 = VariableEffectScript.new()
	e1.variable = "chapter_count"
	e1.operation = "increment"
	e1.value = "1"
	var e2 = VariableEffectScript.new()
	e2.variable = "old_flag"
	e2.operation = "delete"
	c.effects.append(e1)
	c.effects.append(e2)
	var c2 = ConsequenceScript.from_dict(c.to_dict())
	assert_eq(c2.effects.size(), 2)
	assert_eq(c2.effects[0].variable, "chapter_count")
	assert_eq(c2.effects[0].operation, "increment")
	assert_eq(c2.effects[0].value, "1")
	assert_eq(c2.effects[1].variable, "old_flag")
	assert_eq(c2.effects[1].operation, "delete")

func test_is_valid_still_works_with_effects():
	var c = ConsequenceScript.new()
	c.type = "redirect_sequence"
	c.target = "uuid-123"
	var e = VariableEffectScript.new()
	e.variable = "x"
	e.operation = "set"
	e.value = "1"
	c.effects.append(e)
	assert_true(c.is_valid())
