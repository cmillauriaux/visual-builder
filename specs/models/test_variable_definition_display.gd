extends GutTest

const VariableDefinitionScript = preload("res://src/models/variable_definition.gd")


func test_default_display_values():
	var v = VariableDefinitionScript.new()
	assert_eq(v.show_on_main, false)
	assert_eq(v.show_on_details, false)
	assert_eq(v.visibility_mode, "always")
	assert_eq(v.visibility_variable, "")
	assert_eq(v.image, "")
	assert_eq(v.description, "")


func test_show_on_main_serialization():
	var v = VariableDefinitionScript.new()
	v.var_name = "score"
	v.show_on_main = true
	var d = v.to_dict()
	assert_eq(d["show_on_main"], true)
	var v2 = VariableDefinitionScript.from_dict(d)
	assert_eq(v2.show_on_main, true)


func test_show_on_details_serialization():
	var v = VariableDefinitionScript.new()
	v.var_name = "score"
	v.show_on_details = true
	var d = v.to_dict()
	assert_eq(d["show_on_details"], true)
	var v2 = VariableDefinitionScript.from_dict(d)
	assert_eq(v2.show_on_details, true)


func test_visibility_mode_always_serialization():
	var v = VariableDefinitionScript.new()
	v.var_name = "score"
	v.visibility_mode = "always"
	var d = v.to_dict()
	# "always" est la valeur par défaut, ne devrait pas être incluse
	assert_false(d.has("visibility_mode"))
	var v2 = VariableDefinitionScript.from_dict(d)
	assert_eq(v2.visibility_mode, "always")


func test_visibility_mode_variable_serialization():
	var v = VariableDefinitionScript.new()
	v.var_name = "score"
	v.visibility_mode = "variable"
	v.visibility_variable = "has_key"
	var d = v.to_dict()
	assert_eq(d["visibility_mode"], "variable")
	assert_eq(d["visibility_variable"], "has_key")
	var v2 = VariableDefinitionScript.from_dict(d)
	assert_eq(v2.visibility_mode, "variable")
	assert_eq(v2.visibility_variable, "has_key")


func test_image_serialization():
	var v = VariableDefinitionScript.new()
	v.var_name = "score"
	v.image = "assets/foregrounds/coin.png"
	var d = v.to_dict()
	assert_eq(d["image"], "assets/foregrounds/coin.png")
	var v2 = VariableDefinitionScript.from_dict(d)
	assert_eq(v2.image, "assets/foregrounds/coin.png")


func test_description_serialization():
	var v = VariableDefinitionScript.new()
	v.var_name = "score"
	v.description = "Votre score actuel"
	var d = v.to_dict()
	assert_eq(d["description"], "Votre score actuel")
	var v2 = VariableDefinitionScript.from_dict(d)
	assert_eq(v2.description, "Votre score actuel")


func test_full_display_roundtrip():
	var v = VariableDefinitionScript.new()
	v.var_name = "has_key"
	v.initial_value = "false"
	v.show_on_main = true
	v.show_on_details = true
	v.visibility_mode = "variable"
	v.visibility_variable = "key_found"
	v.image = "assets/foregrounds/key.png"
	v.description = "Clé magique"
	var d = v.to_dict()
	var v2 = VariableDefinitionScript.from_dict(d)
	assert_eq(v2.var_name, "has_key")
	assert_eq(v2.initial_value, "false")
	assert_eq(v2.show_on_main, true)
	assert_eq(v2.show_on_details, true)
	assert_eq(v2.visibility_mode, "variable")
	assert_eq(v2.visibility_variable, "key_found")
	assert_eq(v2.image, "assets/foregrounds/key.png")
	assert_eq(v2.description, "Clé magique")


func test_retrocompatibility_no_display_fields():
	var d = {"name": "score", "initial_value": "0"}
	var v = VariableDefinitionScript.from_dict(d)
	assert_eq(v.var_name, "score")
	assert_eq(v.initial_value, "0")
	assert_eq(v.show_on_main, false)
	assert_eq(v.show_on_details, false)
	assert_eq(v.visibility_mode, "always")
	assert_eq(v.visibility_variable, "")
	assert_eq(v.image, "")
	assert_eq(v.description, "")


func test_to_dict_omits_defaults():
	var v = VariableDefinitionScript.new()
	v.var_name = "score"
	v.initial_value = "0"
	var d = v.to_dict()
	assert_false(d.has("show_on_main"))
	assert_false(d.has("show_on_details"))
	assert_false(d.has("visibility_mode"))
	assert_false(d.has("visibility_variable"))
	assert_false(d.has("image"))
	assert_false(d.has("description"))
	assert_eq(d["name"], "score")
	assert_eq(d["initial_value"], "0")


func test_empty_dict_retrocompat():
	var v = VariableDefinitionScript.from_dict({})
	assert_eq(v.var_name, "")
	assert_eq(v.show_on_main, false)
	assert_eq(v.visibility_mode, "always")
