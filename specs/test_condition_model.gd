extends GutTest

const ConditionScript = preload("res://src/models/condition.gd")
const ConditionRuleScript = preload("res://src/models/condition_rule.gd")
const ConsequenceScript = preload("res://src/models/consequence.gd")

# --- Création ---

func test_default_values():
	var cond = ConditionScript.new()
	assert_ne(cond.uuid, "")
	assert_eq(cond.condition_name, "")
	assert_eq(cond.subtitle, "")
	assert_eq(cond.position, Vector2.ZERO)
	assert_eq(cond.rules.size(), 0)
	assert_null(cond.default_consequence)

func test_unique_uuid():
	var c1 = ConditionScript.new()
	var c2 = ConditionScript.new()
	assert_ne(c1.uuid, c2.uuid)

func test_set_properties():
	var cond = ConditionScript.new()
	cond.condition_name = "Score Check"
	cond.subtitle = "Vérifie le score"
	cond.position = Vector2(200, 300)
	assert_eq(cond.condition_name, "Score Check")
	assert_eq(cond.subtitle, "Vérifie le score")
	assert_eq(cond.position, Vector2(200, 300))

# --- Sérialisation ---

func test_to_dict_minimal():
	var cond = ConditionScript.new()
	cond.condition_name = "Test"
	var d = cond.to_dict()
	assert_eq(d["name"], "Test")
	assert_false(d.has("variable"))
	assert_eq(d["rules"], [])
	assert_false(d.has("default_consequence"))

func test_to_dict_with_rules():
	var cond = ConditionScript.new()
	cond.condition_name = "Check"
	cond.position = Vector2(100, 200)

	var rule = ConditionRuleScript.new()
	rule.variable = "score"
	rule.operator = "greater_than"
	rule.value = "50"
	var cons = ConsequenceScript.new()
	cons.type = "redirect_sequence"
	cons.target = "seq-1"
	rule.consequence = cons
	cond.rules.append(rule)

	var default_cons = ConsequenceScript.new()
	default_cons.type = "game_over"
	cond.default_consequence = default_cons

	var d = cond.to_dict()
	assert_eq(d["name"], "Check")
	assert_eq(d["position"]["x"], 100.0)
	assert_eq(d["position"]["y"], 200.0)
	assert_eq(d["rules"].size(), 1)
	assert_eq(d["rules"][0]["variable"], "score")
	assert_eq(d["rules"][0]["operator"], "greater_than")
	assert_eq(d["default_consequence"]["type"], "game_over")

func test_from_dict():
	var d = {
		"uuid": "test-uuid-123",
		"name": "My Condition",
		"subtitle": "sub",
		"position": {"x": 50, "y": 75},
		"rules": [
			{"variable": "health", "operator": "less_than", "value": "0", "consequence": {"type": "game_over"}},
		],
		"default_consequence": {"type": "redirect_sequence", "target": "seq-2"}
	}
	var cond = ConditionScript.from_dict(d)
	assert_eq(cond.uuid, "test-uuid-123")
	assert_eq(cond.condition_name, "My Condition")
	assert_eq(cond.subtitle, "sub")
	assert_eq(cond.position, Vector2(50, 75))
	assert_eq(cond.rules.size(), 1)
	assert_eq(cond.rules[0].variable, "health")
	assert_eq(cond.rules[0].operator, "less_than")
	assert_eq(cond.rules[0].value, "0")
	assert_eq(cond.rules[0].consequence.type, "game_over")
	assert_not_null(cond.default_consequence)
	assert_eq(cond.default_consequence.type, "redirect_sequence")
	assert_eq(cond.default_consequence.target, "seq-2")

func test_from_dict_empty():
	var cond = ConditionScript.from_dict({})
	assert_ne(cond.uuid, "")
	assert_eq(cond.condition_name, "")
	assert_eq(cond.rules.size(), 0)
	assert_null(cond.default_consequence)

func test_roundtrip():
	var cond = ConditionScript.new()
	cond.condition_name = "Roundtrip Test"
	cond.subtitle = "subtitle"
	cond.position = Vector2(123, 456)

	var rule1 = ConditionRuleScript.new()
	rule1.variable = "flag"
	rule1.operator = "equal"
	rule1.value = "yes"
	var cons1 = ConsequenceScript.new()
	cons1.type = "redirect_sequence"
	cons1.target = "s1"
	rule1.consequence = cons1
	cond.rules.append(rule1)

	var rule2 = ConditionRuleScript.new()
	rule2.variable = "other"
	rule2.operator = "exists"
	var cons2 = ConsequenceScript.new()
	cons2.type = "redirect_scene"
	cons2.target = "sc1"
	rule2.consequence = cons2
	cond.rules.append(rule2)

	var def_cons = ConsequenceScript.new()
	def_cons.type = "to_be_continued"
	cond.default_consequence = def_cons

	var restored = ConditionScript.from_dict(cond.to_dict())
	assert_eq(restored.condition_name, "Roundtrip Test")
	assert_eq(restored.subtitle, "subtitle")
	assert_eq(restored.position, Vector2(123, 456))
	assert_eq(restored.rules.size(), 2)
	assert_eq(restored.rules[0].variable, "flag")
	assert_eq(restored.rules[0].operator, "equal")
	assert_eq(restored.rules[0].value, "yes")
	assert_eq(restored.rules[1].variable, "other")
	assert_eq(restored.rules[1].operator, "exists")
	assert_eq(restored.default_consequence.type, "to_be_continued")

# --- Évaluation ---

func _make_rule(variable_name: String, op: String, val: String, target: String) -> Object:
	var rule = ConditionRuleScript.new()
	rule.variable = variable_name
	rule.operator = op
	rule.value = val
	var cons = ConsequenceScript.new()
	cons.type = "redirect_sequence"
	cons.target = target
	rule.consequence = cons
	return rule

func test_evaluate_first_matching_rule():
	var cond = ConditionScript.new()
	cond.rules.append(_make_rule("score", "greater_than", "100", "seq-high"))
	cond.rules.append(_make_rule("score", "greater_than", "50", "seq-mid"))
	cond.rules.append(_make_rule("score", "greater_than", "0", "seq-low"))

	var result = cond.evaluate({"score": "75"})
	assert_not_null(result)
	assert_eq(result.target, "seq-mid")

func test_evaluate_returns_default_when_no_match():
	var cond = ConditionScript.new()
	cond.rules.append(_make_rule("score", "greater_than", "100", "seq-high"))
	var def_cons = ConsequenceScript.new()
	def_cons.type = "redirect_sequence"
	def_cons.target = "seq-default"
	cond.default_consequence = def_cons

	var result = cond.evaluate({"score": "5"})
	assert_not_null(result)
	assert_eq(result.target, "seq-default")

func test_evaluate_returns_null_when_no_match_and_no_default():
	var cond = ConditionScript.new()
	cond.rules.append(_make_rule("score", "equal", "999", "seq-x"))

	var result = cond.evaluate({"score": "5"})
	assert_null(result)

func test_evaluate_with_empty_rules_returns_default():
	var cond = ConditionScript.new()
	var def_cons = ConsequenceScript.new()
	def_cons.type = "game_over"
	cond.default_consequence = def_cons

	var result = cond.evaluate({"x": "1"})
	assert_not_null(result)
	assert_eq(result.type, "game_over")

func test_evaluate_exists_operator():
	var cond = ConditionScript.new()
	cond.rules.append(_make_rule("flag", "exists", "", "seq-found"))

	var result = cond.evaluate({"flag": "1"})
	assert_not_null(result)
	assert_eq(result.target, "seq-found")

	var result2 = cond.evaluate({})
	assert_null(result2)

func test_evaluate_rules_with_different_variables():
	var cond = ConditionScript.new()
	cond.rules.append(_make_rule("score", "greater_than", "100", "seq-high-score"))
	cond.rules.append(_make_rule("health", "less_than", "10", "seq-low-health"))

	# score=50 (rule 1 fails), health=5 (rule 2 matches)
	var result = cond.evaluate({"score": "50", "health": "5"})
	assert_not_null(result)
	assert_eq(result.target, "seq-low-health")
