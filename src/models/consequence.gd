extends RefCounted

## Types de conséquence valides
const VALID_TYPES := ["redirect_sequence", "redirect_scene", "redirect_chapter", "game_over", "to_be_continued"]
const REDIRECT_TYPES := ["redirect_sequence", "redirect_scene", "redirect_chapter"]

var type: String = ""
var target: String = ""

func is_valid() -> bool:
	if type not in VALID_TYPES:
		return false
	if type in REDIRECT_TYPES and target == "":
		return false
	return true

func to_dict() -> Dictionary:
	var d := {"type": type}
	if type in REDIRECT_TYPES:
		d["target"] = target
	return d

static func from_dict(d: Dictionary):
	var script = load("res://src/models/consequence.gd")
	var c = script.new()
	c.type = d.get("type", "")
	c.target = d.get("target", "")
	return c
