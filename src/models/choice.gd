extends RefCounted

const ConsequenceScript = preload("res://src/models/consequence.gd")

var text: String = ""
var consequence = null  # Consequence
var conditions: Dictionary = {}

func to_dict() -> Dictionary:
	var d := {
		"text": text,
		"consequence": consequence.to_dict() if consequence else {},
		"conditions": conditions,
	}
	return d

static func from_dict(d: Dictionary):
	var script = load("res://src/models/choice.gd")
	var c = script.new()
	c.text = d.get("text", "")
	if d.has("consequence"):
		c.consequence = ConsequenceScript.from_dict(d["consequence"])
	c.conditions = d.get("conditions", {})
	return c
