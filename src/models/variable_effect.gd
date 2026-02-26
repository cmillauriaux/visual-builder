extends RefCounted

const VALID_OPERATIONS := ["set", "increment", "decrement", "delete"]

var variable: String = ""
var operation: String = ""
var value: String = ""

func apply(variables: Dictionary) -> void:
	match operation:
		"set":
			variables[variable] = value
		"increment":
			var current_str = str(variables.get(variable, "0"))
			if not current_str.is_valid_float() or not value.is_valid_float():
				return
			var result = float(current_str) + float(value)
			variables[variable] = str(result)
		"decrement":
			var current_str = str(variables.get(variable, "0"))
			if not current_str.is_valid_float() or not value.is_valid_float():
				return
			var result = float(current_str) - float(value)
			variables[variable] = str(result)
		"delete":
			variables.erase(variable)

func to_dict() -> Dictionary:
	var d := {
		"variable": variable,
		"operation": operation,
	}
	if operation != "delete":
		d["value"] = value
	return d

static func from_dict(d: Dictionary):
	var script = load("res://src/models/variable_effect.gd")
	var e = script.new()
	e.variable = d.get("variable", "")
	e.operation = d.get("operation", "")
	e.value = d.get("value", "")
	return e
