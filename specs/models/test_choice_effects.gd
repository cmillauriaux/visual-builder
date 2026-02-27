extends GutTest

const ChoiceScript = preload("res://src/models/choice.gd")
const VariableEffectScript = preload("res://src/models/variable_effect.gd")
const ConsequenceScript = preload("res://src/models/consequence.gd")

# --- Champ effects ---

func test_choice_has_effects_array():
	var c = ChoiceScript.new()
	assert_eq(c.effects.size(), 0, "effects initialisé vide")

func test_add_effect_to_choice():
	var c = ChoiceScript.new()
	var e = VariableEffectScript.new()
	e.variable = "has_key"
	e.operation = "set"
	e.value = "true"
	c.effects.append(e)
	assert_eq(c.effects.size(), 1)

# --- Sérialisation ---

func test_to_dict_with_effects():
	var c = ChoiceScript.new()
	c.text = "Take the key"
	c.consequence = ConsequenceScript.new()
	c.consequence.type = "redirect_sequence"
	c.consequence.target = "uuid-123"
	var e = VariableEffectScript.new()
	e.variable = "has_key"
	e.operation = "set"
	e.value = "true"
	c.effects.append(e)
	var d = c.to_dict()
	assert_true(d.has("effects"))
	assert_eq(d["effects"].size(), 1)
	assert_eq(d["effects"][0]["variable"], "has_key")

func test_to_dict_without_effects():
	var c = ChoiceScript.new()
	c.text = "Go left"
	c.consequence = ConsequenceScript.new()
	c.consequence.type = "game_over"
	var d = c.to_dict()
	assert_true(d.has("effects"))
	assert_eq(d["effects"].size(), 0)

func test_from_dict_with_effects():
	var d = {
		"text": "Pick up sword",
		"consequence": {"type": "redirect_sequence", "target": "uuid-789"},
		"effects": [
			{"variable": "has_sword", "operation": "set", "value": "true"},
			{"variable": "strength", "operation": "increment", "value": "5"},
		]
	}
	var c = ChoiceScript.from_dict(d)
	assert_eq(c.effects.size(), 2)
	assert_eq(c.effects[0].variable, "has_sword")
	assert_eq(c.effects[1].variable, "strength")
	assert_eq(c.effects[1].operation, "increment")

func test_from_dict_without_effects_retrocompat():
	var d = {
		"text": "Old choice",
		"consequence": {"type": "game_over"},
	}
	var c = ChoiceScript.from_dict(d)
	assert_eq(c.effects.size(), 0, "Rétrocompatibilité : pas d'effets")

func test_roundtrip_with_effects():
	var c = ChoiceScript.new()
	c.text = "Test"
	c.consequence = ConsequenceScript.new()
	c.consequence.type = "game_over"
	var e = VariableEffectScript.new()
	e.variable = "gold"
	e.operation = "decrement"
	e.value = "10"
	c.effects.append(e)
	var c2 = ChoiceScript.from_dict(c.to_dict())
	assert_eq(c2.effects.size(), 1)
	assert_eq(c2.effects[0].variable, "gold")
	assert_eq(c2.effects[0].operation, "decrement")
	assert_eq(c2.effects[0].value, "10")
