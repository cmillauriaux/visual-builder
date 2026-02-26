extends GutTest

const ConditionRuleScript = preload("res://src/models/condition_rule.gd")
const ConsequenceScript = preload("res://src/models/consequence.gd")

# --- Création ---

func test_default_values():
	var rule = ConditionRuleScript.new()
	assert_eq(rule.operator, "")
	assert_eq(rule.value, "")
	assert_null(rule.consequence)

func test_set_properties():
	var rule = ConditionRuleScript.new()
	rule.operator = "equal"
	rule.value = "42"
	var cons = ConsequenceScript.new()
	cons.type = "redirect_sequence"
	cons.target = "abc-123"
	rule.consequence = cons
	assert_eq(rule.operator, "equal")
	assert_eq(rule.value, "42")
	assert_eq(rule.consequence.type, "redirect_sequence")
	assert_eq(rule.consequence.target, "abc-123")

# --- Opérateurs valides ---

func test_valid_operators():
	var valid = ["equal", "not_equal", "greater_than", "greater_than_equal", "less_than", "less_than_equal", "exists", "not_exists"]
	assert_eq(ConditionRuleScript.VALID_OPERATORS, valid)

# --- Sérialisation ---

func test_to_dict():
	var rule = ConditionRuleScript.new()
	rule.operator = "greater_than"
	rule.value = "100"
	var cons = ConsequenceScript.new()
	cons.type = "redirect_sequence"
	cons.target = "target-uuid"
	rule.consequence = cons

	var d = rule.to_dict()
	assert_eq(d["operator"], "greater_than")
	assert_eq(d["value"], "100")
	assert_eq(d["consequence"]["type"], "redirect_sequence")
	assert_eq(d["consequence"]["target"], "target-uuid")

func test_to_dict_no_consequence():
	var rule = ConditionRuleScript.new()
	rule.operator = "exists"
	var d = rule.to_dict()
	assert_eq(d["consequence"], {})

func test_from_dict():
	var d = {
		"operator": "less_than_equal",
		"value": "50",
		"consequence": {"type": "game_over"}
	}
	var rule = ConditionRuleScript.from_dict(d)
	assert_eq(rule.operator, "less_than_equal")
	assert_eq(rule.value, "50")
	assert_not_null(rule.consequence)
	assert_eq(rule.consequence.type, "game_over")

func test_from_dict_empty():
	var rule = ConditionRuleScript.from_dict({})
	assert_eq(rule.operator, "")
	assert_eq(rule.value, "")
	assert_null(rule.consequence)

func test_roundtrip():
	var rule = ConditionRuleScript.new()
	rule.operator = "not_equal"
	rule.value = "hello"
	var cons = ConsequenceScript.new()
	cons.type = "redirect_scene"
	cons.target = "scene-uuid"
	rule.consequence = cons

	var restored = ConditionRuleScript.from_dict(rule.to_dict())
	assert_eq(restored.operator, "not_equal")
	assert_eq(restored.value, "hello")
	assert_eq(restored.consequence.type, "redirect_scene")
	assert_eq(restored.consequence.target, "scene-uuid")

# --- Évaluation ---

func test_evaluate_equal_match():
	var rule = ConditionRuleScript.new()
	rule.operator = "equal"
	rule.value = "alice"
	assert_true(rule.evaluate({"character": "alice"}, "character"))

func test_evaluate_equal_no_match():
	var rule = ConditionRuleScript.new()
	rule.operator = "equal"
	rule.value = "alice"
	assert_false(rule.evaluate({"character": "bob"}, "character"))

func test_evaluate_not_equal_match():
	var rule = ConditionRuleScript.new()
	rule.operator = "not_equal"
	rule.value = "alice"
	assert_true(rule.evaluate({"character": "bob"}, "character"))

func test_evaluate_not_equal_no_match():
	var rule = ConditionRuleScript.new()
	rule.operator = "not_equal"
	rule.value = "alice"
	assert_false(rule.evaluate({"character": "alice"}, "character"))

func test_evaluate_greater_than_match():
	var rule = ConditionRuleScript.new()
	rule.operator = "greater_than"
	rule.value = "10"
	assert_true(rule.evaluate({"score": "15"}, "score"))

func test_evaluate_greater_than_no_match():
	var rule = ConditionRuleScript.new()
	rule.operator = "greater_than"
	rule.value = "10"
	assert_false(rule.evaluate({"score": "10"}, "score"))

func test_evaluate_greater_than_equal_match():
	var rule = ConditionRuleScript.new()
	rule.operator = "greater_than_equal"
	rule.value = "10"
	assert_true(rule.evaluate({"score": "10"}, "score"))

func test_evaluate_greater_than_equal_no_match():
	var rule = ConditionRuleScript.new()
	rule.operator = "greater_than_equal"
	rule.value = "10"
	assert_false(rule.evaluate({"score": "9"}, "score"))

func test_evaluate_less_than_match():
	var rule = ConditionRuleScript.new()
	rule.operator = "less_than"
	rule.value = "10"
	assert_true(rule.evaluate({"score": "5"}, "score"))

func test_evaluate_less_than_no_match():
	var rule = ConditionRuleScript.new()
	rule.operator = "less_than"
	rule.value = "10"
	assert_false(rule.evaluate({"score": "10"}, "score"))

func test_evaluate_less_than_equal_match():
	var rule = ConditionRuleScript.new()
	rule.operator = "less_than_equal"
	rule.value = "10"
	assert_true(rule.evaluate({"score": "10"}, "score"))

func test_evaluate_less_than_equal_no_match():
	var rule = ConditionRuleScript.new()
	rule.operator = "less_than_equal"
	rule.value = "10"
	assert_false(rule.evaluate({"score": "11"}, "score"))

func test_evaluate_exists_match():
	var rule = ConditionRuleScript.new()
	rule.operator = "exists"
	assert_true(rule.evaluate({"flag": "1"}, "flag"))

func test_evaluate_exists_no_match():
	var rule = ConditionRuleScript.new()
	rule.operator = "exists"
	assert_false(rule.evaluate({}, "flag"))

func test_evaluate_not_exists_match():
	var rule = ConditionRuleScript.new()
	rule.operator = "not_exists"
	assert_true(rule.evaluate({}, "flag"))

func test_evaluate_not_exists_no_match():
	var rule = ConditionRuleScript.new()
	rule.operator = "not_exists"
	assert_false(rule.evaluate({"flag": "1"}, "flag"))

func test_evaluate_numeric_invalid_value_returns_false():
	var rule = ConditionRuleScript.new()
	rule.operator = "greater_than"
	rule.value = "10"
	assert_false(rule.evaluate({"score": "not_a_number"}, "score"))

func test_evaluate_numeric_invalid_rule_value_returns_false():
	var rule = ConditionRuleScript.new()
	rule.operator = "greater_than"
	rule.value = "not_a_number"
	assert_false(rule.evaluate({"score": "15"}, "score"))

func test_evaluate_variable_not_found_returns_false():
	var rule = ConditionRuleScript.new()
	rule.operator = "equal"
	rule.value = "test"
	assert_false(rule.evaluate({}, "missing_var"))

func test_evaluate_equal_numeric_as_string():
	var rule = ConditionRuleScript.new()
	rule.operator = "equal"
	rule.value = "10"
	# equal compare en string
	assert_true(rule.evaluate({"score": "10"}, "score"))
	assert_false(rule.evaluate({"score": "10.0"}, "score"))
