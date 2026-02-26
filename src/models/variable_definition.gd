extends RefCounted

var var_name: String = ""
var initial_value: String = ""

func is_valid() -> bool:
	return var_name.strip_edges() != ""

func to_dict() -> Dictionary:
	return {
		"name": var_name,
		"initial_value": initial_value,
	}

static func from_dict(d: Dictionary):
	var script = load("res://src/models/variable_definition.gd")
	var v = script.new()
	v.var_name = d.get("name", "")
	v.initial_value = d.get("initial_value", "")
	return v
