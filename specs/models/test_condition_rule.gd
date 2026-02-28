extends GutTest

## Tests pour ConditionRule — évaluation d'une règle conditionnelle.

const ConditionRuleScript = preload("res://src/models/condition_rule.gd")
const ConsequenceScript = preload("res://src/models/consequence.gd")


func test_default_values() -> void:
	var rule = ConditionRuleScript.new()
	assert_eq(rule.variable, "")
	assert_eq(rule.operator, "")
	assert_eq(rule.value, "")
	assert_null(rule.consequence)


func test_valid_operators_constant() -> void:
	assert_true(ConditionRuleScript.VALID_OPERATORS.size() > 0)
	assert_true("equal" in ConditionRuleScript.VALID_OPERATORS)
	assert_true("not_equal" in ConditionRuleScript.VALID_OPERATORS)
	assert_true("greater_than" in ConditionRuleScript.VALID_OPERATORS)
	assert_true("exists" in ConditionRuleScript.VALID_OPERATORS)
	assert_true("not_exists" in ConditionRuleScript.VALID_OPERATORS)


func test_evaluate_exists() -> void:
	var rule = _make_rule("x", "exists", "")
	assert_true(rule.evaluate({"x": "1"}))
	assert_false(rule.evaluate({"y": "1"}))


func test_evaluate_not_exists() -> void:
	var rule = _make_rule("x", "not_exists", "")
	assert_false(rule.evaluate({"x": "1"}))
	assert_true(rule.evaluate({"y": "1"}))


func test_evaluate_equal() -> void:
	var rule = _make_rule("color", "equal", "blue")
	assert_true(rule.evaluate({"color": "blue"}))
	assert_false(rule.evaluate({"color": "red"}))


func test_evaluate_equal_with_numeric_string() -> void:
	var rule = _make_rule("score", "equal", "10")
	assert_true(rule.evaluate({"score": 10}), "int value should be stringified for comparison")
	assert_true(rule.evaluate({"score": "10"}))


func test_evaluate_not_equal() -> void:
	var rule = _make_rule("color", "not_equal", "blue")
	assert_false(rule.evaluate({"color": "blue"}))
	assert_true(rule.evaluate({"color": "red"}))


func test_evaluate_greater_than() -> void:
	var rule = _make_rule("score", "greater_than", "10")
	assert_true(rule.evaluate({"score": "15"}))
	assert_false(rule.evaluate({"score": "10"}))
	assert_false(rule.evaluate({"score": "5"}))


func test_evaluate_greater_than_equal() -> void:
	var rule = _make_rule("score", "greater_than_equal", "10")
	assert_true(rule.evaluate({"score": "15"}))
	assert_true(rule.evaluate({"score": "10"}))
	assert_false(rule.evaluate({"score": "5"}))


func test_evaluate_less_than() -> void:
	var rule = _make_rule("score", "less_than", "10")
	assert_true(rule.evaluate({"score": "5"}))
	assert_false(rule.evaluate({"score": "10"}))
	assert_false(rule.evaluate({"score": "15"}))


func test_evaluate_less_than_equal() -> void:
	var rule = _make_rule("score", "less_than_equal", "10")
	assert_true(rule.evaluate({"score": "5"}))
	assert_true(rule.evaluate({"score": "10"}))
	assert_false(rule.evaluate({"score": "15"}))


func test_evaluate_missing_variable_returns_false() -> void:
	var rule = _make_rule("score", "equal", "10")
	assert_false(rule.evaluate({}))


func test_evaluate_non_numeric_for_numeric_operator_returns_false() -> void:
	var rule = _make_rule("score", "greater_than", "10")
	assert_false(rule.evaluate({"score": "abc"}))


func test_evaluate_non_numeric_value_for_numeric_operator_returns_false() -> void:
	var rule = _make_rule("score", "greater_than", "abc")
	assert_false(rule.evaluate({"score": "10"}))


func test_evaluate_unknown_operator_returns_false() -> void:
	var rule = _make_rule("x", "banana", "1")
	assert_false(rule.evaluate({"x": "1"}))


func test_to_dict() -> void:
	var rule = _make_rule("hp", "less_than", "0")
	rule.consequence = ConsequenceScript.new()
	rule.consequence.type = "redirect_sequence"
	rule.consequence.target = "game-over"
	var d = rule.to_dict()
	assert_eq(d["variable"], "hp")
	assert_eq(d["operator"], "less_than")
	assert_eq(d["value"], "0")
	assert_eq(d["consequence"]["target"], "game-over")


func test_to_dict_without_consequence() -> void:
	var rule = _make_rule("x", "equal", "1")
	var d = rule.to_dict()
	assert_eq(d["consequence"], {})


func test_from_dict() -> void:
	var d = {
		"variable": "mood",
		"operator": "equal",
		"value": "happy",
		"consequence": {"type": "redirect_sequence", "target": "joy-scene"}
	}
	var rule = ConditionRuleScript.from_dict(d)
	assert_eq(rule.variable, "mood")
	assert_eq(rule.operator, "equal")
	assert_eq(rule.value, "happy")
	assert_not_null(rule.consequence)
	assert_eq(rule.consequence.target, "joy-scene")


func test_from_dict_empty_consequence() -> void:
	var d = {"variable": "x", "operator": "equal", "value": "1", "consequence": {}}
	var rule = ConditionRuleScript.from_dict(d)
	assert_null(rule.consequence)


func test_from_dict_empty() -> void:
	var rule = ConditionRuleScript.from_dict({})
	assert_eq(rule.variable, "")
	assert_eq(rule.operator, "")
	assert_eq(rule.value, "")


func test_roundtrip() -> void:
	var original = _make_rule("score", "greater_than_equal", "50")
	original.consequence = ConsequenceScript.new()
	original.consequence.type = "redirect_sequence"
	original.consequence.target = "win"
	var restored = ConditionRuleScript.from_dict(original.to_dict())
	assert_eq(restored.variable, "score")
	assert_eq(restored.operator, "greater_than_equal")
	assert_eq(restored.value, "50")
	assert_eq(restored.consequence.target, "win")


# --- Helper ---

func _make_rule(variable: String, operator: String, value: String) -> RefCounted:
	var rule = ConditionRuleScript.new()
	rule.variable = variable
	rule.operator = operator
	rule.value = value
	return rule
