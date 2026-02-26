extends GutTest

const VariableEffectScript = preload("res://src/models/variable_effect.gd")

# --- Propriétés par défaut ---

func test_default_values():
	var e = VariableEffectScript.new()
	assert_eq(e.variable, "")
	assert_eq(e.operation, "")
	assert_eq(e.value, "")

# --- to_dict / from_dict ---

func test_to_dict():
	var e = VariableEffectScript.new()
	e.variable = "score"
	e.operation = "increment"
	e.value = "10"
	var d = e.to_dict()
	assert_eq(d["variable"], "score")
	assert_eq(d["operation"], "increment")
	assert_eq(d["value"], "10")

func test_to_dict_delete_omits_value():
	var e = VariableEffectScript.new()
	e.variable = "temp"
	e.operation = "delete"
	e.value = "ignored"
	var d = e.to_dict()
	assert_eq(d["variable"], "temp")
	assert_eq(d["operation"], "delete")
	assert_false(d.has("value"), "delete ne sérialise pas value")

func test_from_dict():
	var d = {"variable": "hp", "operation": "set", "value": "50"}
	var e = VariableEffectScript.from_dict(d)
	assert_eq(e.variable, "hp")
	assert_eq(e.operation, "set")
	assert_eq(e.value, "50")

func test_from_dict_empty():
	var d = {}
	var e = VariableEffectScript.from_dict(d)
	assert_eq(e.variable, "")
	assert_eq(e.operation, "")
	assert_eq(e.value, "")

func test_roundtrip():
	var e = VariableEffectScript.new()
	e.variable = "gold"
	e.operation = "decrement"
	e.value = "5"
	var e2 = VariableEffectScript.from_dict(e.to_dict())
	assert_eq(e2.variable, "gold")
	assert_eq(e2.operation, "decrement")
	assert_eq(e2.value, "5")

# --- apply() : set ---

func test_apply_set_new_variable():
	var vars = {}
	var e = _make_effect("score", "set", "100")
	e.apply(vars)
	assert_eq(vars["score"], "100")

func test_apply_set_overwrite():
	var vars = {"score": "50"}
	var e = _make_effect("score", "set", "200")
	e.apply(vars)
	assert_eq(vars["score"], "200")

# --- apply() : increment ---

func test_apply_increment():
	var vars = {"score": "10"}
	var e = _make_effect("score", "increment", "5")
	e.apply(vars)
	assert_eq(vars["score"], "15.0")

func test_apply_increment_nonexistent_variable():
	var vars = {}
	var e = _make_effect("score", "increment", "7")
	e.apply(vars)
	assert_eq(vars["score"], "7.0")

func test_apply_increment_non_numeric_value_ignored():
	var vars = {"score": "abc"}
	var e = _make_effect("score", "increment", "5")
	e.apply(vars)
	assert_eq(vars["score"], "abc", "Valeur non numérique : effet ignoré")

func test_apply_increment_non_numeric_operand_ignored():
	var vars = {"score": "10"}
	var e = _make_effect("score", "increment", "xyz")
	e.apply(vars)
	assert_eq(vars["score"], "10", "Opérande non numérique : effet ignoré")

func test_apply_increment_float():
	var vars = {"score": "1.5"}
	var e = _make_effect("score", "increment", "2.5")
	e.apply(vars)
	assert_eq(vars["score"], "4.0")

# --- apply() : decrement ---

func test_apply_decrement():
	var vars = {"score": "20"}
	var e = _make_effect("score", "decrement", "3")
	e.apply(vars)
	assert_eq(vars["score"], "17.0")

func test_apply_decrement_nonexistent_variable():
	var vars = {}
	var e = _make_effect("score", "decrement", "5")
	e.apply(vars)
	assert_eq(vars["score"], "-5.0")

func test_apply_decrement_non_numeric_ignored():
	var vars = {"score": "abc"}
	var e = _make_effect("score", "decrement", "5")
	e.apply(vars)
	assert_eq(vars["score"], "abc")

# --- apply() : delete ---

func test_apply_delete():
	var vars = {"score": "10", "hp": "50"}
	var e = _make_effect("score", "delete", "")
	e.apply(vars)
	assert_false(vars.has("score"), "Variable supprimée")
	assert_eq(vars["hp"], "50", "Autres variables intactes")

func test_apply_delete_nonexistent():
	var vars = {"hp": "50"}
	var e = _make_effect("score", "delete", "")
	e.apply(vars)
	assert_false(vars.has("score"), "Pas d'erreur si variable absente")
	assert_eq(vars.size(), 1)

# --- apply() : opération invalide ---

func test_apply_unknown_operation_ignored():
	var vars = {"score": "10"}
	var e = _make_effect("score", "unknown_op", "5")
	e.apply(vars)
	assert_eq(vars["score"], "10", "Opération inconnue : ignorée")

# --- Helper ---

func _make_effect(variable: String, operation: String, value: String) -> RefCounted:
	var e = VariableEffectScript.new()
	e.variable = variable
	e.operation = operation
	e.value = value
	return e
