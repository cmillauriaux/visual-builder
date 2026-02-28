extends GutTest

## Tests pour Condition — modèle de condition avec règles et évaluation.

const ConditionScript = preload("res://src/models/condition.gd")
const ConditionRuleScript = preload("res://src/models/condition_rule.gd")
const ConsequenceScript = preload("res://src/models/consequence.gd")


func test_uuid_generated_on_init() -> void:
	var cond = ConditionScript.new()
	assert_ne(cond.uuid, "", "uuid should be generated on init")
	assert_true(cond.uuid.length() > 20, "uuid should be long enough")


func test_uuid_unique() -> void:
	var c1 = ConditionScript.new()
	var c2 = ConditionScript.new()
	assert_ne(c1.uuid, c2.uuid, "two conditions should have different uuids")


func test_default_values() -> void:
	var cond = ConditionScript.new()
	assert_eq(cond.condition_name, "")
	assert_eq(cond.subtitle, "")
	assert_eq(cond.position, Vector2.ZERO)
	assert_eq(cond.rules.size(), 0)
	assert_null(cond.default_consequence)


func test_to_dict_minimal() -> void:
	var cond = ConditionScript.new()
	cond.uuid = "test-uuid"
	cond.condition_name = "My Condition"
	cond.subtitle = "Sub"
	cond.position = Vector2(10, 20)
	var d = cond.to_dict()
	assert_eq(d["uuid"], "test-uuid")
	assert_eq(d["name"], "My Condition")
	assert_eq(d["subtitle"], "Sub")
	assert_eq(d["position"]["x"], 10.0)
	assert_eq(d["position"]["y"], 20.0)
	assert_eq(d["rules"].size(), 0)
	assert_false(d.has("default_consequence"))


func test_to_dict_with_default_consequence() -> void:
	var cond = ConditionScript.new()
	cond.uuid = "c1"
	cond.default_consequence = ConsequenceScript.new()
	cond.default_consequence.type = "redirect_sequence"
	cond.default_consequence.target = "target-1"
	var d = cond.to_dict()
	assert_true(d.has("default_consequence"))
	assert_eq(d["default_consequence"]["target"], "target-1")


func test_to_dict_with_rules() -> void:
	var cond = ConditionScript.new()
	cond.uuid = "c2"
	var rule = ConditionRuleScript.new()
	rule.variable = "score"
	rule.operator = "greater_than"
	rule.value = "10"
	cond.rules.append(rule)
	var d = cond.to_dict()
	assert_eq(d["rules"].size(), 1)
	assert_eq(d["rules"][0]["variable"], "score")


func test_from_dict() -> void:
	var d = {
		"uuid": "abc-123",
		"name": "Test Cond",
		"subtitle": "Subtitle",
		"position": {"x": 100, "y": 200},
		"rules": [
			{"variable": "hp", "operator": "less_than", "value": "0", "consequence": {"type": "redirect_sequence", "target": "end-1"}}
		],
		"default_consequence": {"type": "redirect_sequence", "target": "default-t"}
	}
	var cond = ConditionScript.from_dict(d)
	assert_eq(cond.uuid, "abc-123")
	assert_eq(cond.condition_name, "Test Cond")
	assert_eq(cond.subtitle, "Subtitle")
	assert_eq(cond.position, Vector2(100, 200))
	assert_eq(cond.rules.size(), 1)
	assert_eq(cond.rules[0].variable, "hp")
	assert_not_null(cond.default_consequence)
	assert_eq(cond.default_consequence.target, "default-t")


func test_from_dict_empty() -> void:
	var cond = ConditionScript.from_dict({})
	assert_ne(cond.uuid, "", "should still have a uuid")
	assert_eq(cond.condition_name, "")
	assert_eq(cond.rules.size(), 0)
	assert_null(cond.default_consequence)


func test_roundtrip() -> void:
	var original = ConditionScript.new()
	original.condition_name = "Round"
	original.subtitle = "Trip"
	original.position = Vector2(50, 75)
	var rule = ConditionRuleScript.new()
	rule.variable = "x"
	rule.operator = "equal"
	rule.value = "yes"
	rule.consequence = ConsequenceScript.new()
	rule.consequence.type = "redirect_sequence"
	rule.consequence.target = "seq-1"
	original.rules.append(rule)
	original.default_consequence = ConsequenceScript.new()
	original.default_consequence.type = "redirect_sequence"
	original.default_consequence.target = "def-1"

	var restored = ConditionScript.from_dict(original.to_dict())
	assert_eq(restored.condition_name, "Round")
	assert_eq(restored.subtitle, "Trip")
	assert_eq(restored.position, Vector2(50, 75))
	assert_eq(restored.rules.size(), 1)
	assert_eq(restored.rules[0].variable, "x")
	assert_eq(restored.default_consequence.target, "def-1")


func test_evaluate_returns_matching_rule_consequence() -> void:
	var cond = ConditionScript.new()
	var rule = ConditionRuleScript.new()
	rule.variable = "mood"
	rule.operator = "equal"
	rule.value = "happy"
	rule.consequence = ConsequenceScript.new()
	rule.consequence.target = "happy-path"
	cond.rules.append(rule)
	cond.default_consequence = ConsequenceScript.new()
	cond.default_consequence.target = "default-path"

	var result = cond.evaluate({"mood": "happy"})
	assert_eq(result.target, "happy-path")


func test_evaluate_returns_default_when_no_match() -> void:
	var cond = ConditionScript.new()
	var rule = ConditionRuleScript.new()
	rule.variable = "mood"
	rule.operator = "equal"
	rule.value = "happy"
	rule.consequence = ConsequenceScript.new()
	rule.consequence.target = "happy-path"
	cond.rules.append(rule)
	cond.default_consequence = ConsequenceScript.new()
	cond.default_consequence.target = "default-path"

	var result = cond.evaluate({"mood": "sad"})
	assert_eq(result.target, "default-path")


func test_evaluate_returns_null_when_no_match_and_no_default() -> void:
	var cond = ConditionScript.new()
	var result = cond.evaluate({"x": "1"})
	assert_null(result)


func test_evaluate_first_matching_rule() -> void:
	var cond = ConditionScript.new()
	var r1 = ConditionRuleScript.new()
	r1.variable = "x"
	r1.operator = "equal"
	r1.value = "1"
	r1.consequence = ConsequenceScript.new()
	r1.consequence.target = "first"
	cond.rules.append(r1)
	var r2 = ConditionRuleScript.new()
	r2.variable = "x"
	r2.operator = "equal"
	r2.value = "1"
	r2.consequence = ConsequenceScript.new()
	r2.consequence.target = "second"
	cond.rules.append(r2)

	var result = cond.evaluate({"x": "1"})
	assert_eq(result.target, "first", "should return first matching rule")
