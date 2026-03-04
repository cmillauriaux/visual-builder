extends RefCounted

var var_name: String = ""
var initial_value: String = ""

# Champs d'affichage (spec 046)
var show_on_main: bool = false
var show_on_details: bool = false
var visibility_mode: String = "always"  # "always" ou "variable"
var visibility_variable: String = ""
var image: String = ""
var description: String = ""

func is_valid() -> bool:
	return var_name.strip_edges() != ""

func to_dict() -> Dictionary:
	var d := {
		"name": var_name,
		"initial_value": initial_value,
	}
	if show_on_main:
		d["show_on_main"] = true
	if show_on_details:
		d["show_on_details"] = true
	if visibility_mode != "always":
		d["visibility_mode"] = visibility_mode
		d["visibility_variable"] = visibility_variable
	if image != "":
		d["image"] = image
	if description != "":
		d["description"] = description
	return d

static func from_dict(d: Dictionary):
	var script = load("res://src/models/variable_definition.gd")
	var v = script.new()
	v.var_name = d.get("name", "")
	v.initial_value = d.get("initial_value", "")
	v.show_on_main = d.get("show_on_main", false)
	v.show_on_details = d.get("show_on_details", false)
	v.visibility_mode = d.get("visibility_mode", "always")
	v.visibility_variable = d.get("visibility_variable", "")
	v.image = d.get("image", "")
	v.description = d.get("description", "")
	return v
