extends RefCounted

const ConsequenceScript = preload("res://src/models/consequence.gd")
const VariableEffectScript = preload("res://src/models/variable_effect.gd")

var text: String = ""
var consequence = null  # Consequence
var conditions: Dictionary = {}
var effects: Array = []  # Array[VariableEffect]

func to_dict() -> Dictionary:
	var effects_arr := []
	for e in effects:
		effects_arr.append(e.to_dict())
	var d := {
		"text": text,
		"consequence": consequence.to_dict() if consequence else {},
		"conditions": conditions,
		"effects": effects_arr,
	}
	return d

static func from_dict(d: Dictionary):
	var script = load("res://src/models/choice.gd")
	var c = script.new()
	c.text = d.get("text", "")
	if d.has("consequence"):
		c.consequence = ConsequenceScript.from_dict(d["consequence"])
	c.conditions = d.get("conditions", {})
	if d.has("effects"):
		for effect_dict in d["effects"]:
			c.effects.append(VariableEffectScript.from_dict(effect_dict))
	return c
