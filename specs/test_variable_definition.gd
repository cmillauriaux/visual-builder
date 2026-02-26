extends GutTest

const VariableDefinitionScript = preload("res://src/models/variable_definition.gd")

func test_default_values():
	var v = VariableDefinitionScript.new()
	assert_eq(v.var_name, "", "var_name par défaut vide")
	assert_eq(v.initial_value, "", "initial_value par défaut vide")

func test_set_properties():
	var v = VariableDefinitionScript.new()
	v.var_name = "score"
	v.initial_value = "0"
	assert_eq(v.var_name, "score")
	assert_eq(v.initial_value, "0")

func test_to_dict():
	var v = VariableDefinitionScript.new()
	v.var_name = "has_key"
	v.initial_value = "false"
	var d = v.to_dict()
	assert_eq(d["name"], "has_key")
	assert_eq(d["initial_value"], "false")

func test_from_dict():
	var d = {"name": "score", "initial_value": "100"}
	var v = VariableDefinitionScript.from_dict(d)
	assert_eq(v.var_name, "score")
	assert_eq(v.initial_value, "100")

func test_from_dict_empty():
	var d = {}
	var v = VariableDefinitionScript.from_dict(d)
	assert_eq(v.var_name, "")
	assert_eq(v.initial_value, "")

func test_roundtrip():
	var v = VariableDefinitionScript.new()
	v.var_name = "level"
	v.initial_value = "5"
	var v2 = VariableDefinitionScript.from_dict(v.to_dict())
	assert_eq(v2.var_name, "level")
	assert_eq(v2.initial_value, "5")

func test_is_valid_with_name():
	var v = VariableDefinitionScript.new()
	v.var_name = "score"
	assert_true(v.is_valid(), "Variable avec nom est valide")

func test_is_valid_empty_name():
	var v = VariableDefinitionScript.new()
	v.var_name = ""
	assert_false(v.is_valid(), "Variable sans nom est invalide")

func test_is_valid_whitespace_name():
	var v = VariableDefinitionScript.new()
	v.var_name = "   "
	assert_false(v.is_valid(), "Variable avec nom whitespace est invalide")
