extends GutTest

const SceneDataScript = preload("res://src/models/scene_data.gd")
const ConditionScript = preload("res://src/models/condition.gd")
const ConditionRuleScript = preload("res://src/models/condition_rule.gd")
const ConsequenceScript = preload("res://src/models/consequence.gd")

# --- Champ conditions ---

func test_scene_data_has_conditions_array():
	var scene = SceneDataScript.new()
	assert_eq(scene.conditions.size(), 0)

func test_add_condition():
	var scene = SceneDataScript.new()
	var cond = ConditionScript.new()
	cond.condition_name = "Test"
	scene.conditions.append(cond)
	assert_eq(scene.conditions.size(), 1)
	assert_eq(scene.conditions[0].condition_name, "Test")

# --- find_condition ---

func test_find_condition_found():
	var scene = SceneDataScript.new()
	var cond = ConditionScript.new()
	cond.condition_name = "Found"
	scene.conditions.append(cond)
	var found = scene.find_condition(cond.uuid)
	assert_not_null(found)
	assert_eq(found.condition_name, "Found")

func test_find_condition_not_found():
	var scene = SceneDataScript.new()
	var result = scene.find_condition("nonexistent")
	assert_null(result)

# --- Sérialisation avec conditions ---

func test_to_dict_includes_conditions():
	var scene = SceneDataScript.new()
	scene.scene_name = "Scene 1"

	var cond = ConditionScript.new()
	cond.condition_name = "Score Check"
	cond.variable = "score"
	scene.conditions.append(cond)

	var d = scene.to_dict()
	assert_true(d.has("conditions"))
	assert_eq(d["conditions"].size(), 1)
	assert_eq(d["conditions"][0]["name"], "Score Check")
	assert_eq(d["conditions"][0]["variable"], "score")

func test_to_dict_empty_conditions():
	var scene = SceneDataScript.new()
	var d = scene.to_dict()
	assert_true(d.has("conditions"))
	assert_eq(d["conditions"].size(), 0)

func test_from_dict_with_conditions():
	var d = {
		"uuid": "scene-uuid",
		"name": "Scene 1",
		"conditions": [
			{
				"uuid": "cond-uuid",
				"name": "Health",
				"variable": "health",
				"position": {"x": 100, "y": 200},
				"rules": [
					{"operator": "less_than", "value": "0", "consequence": {"type": "game_over"}}
				],
				"default_consequence": {"type": "redirect_sequence", "target": "s1"}
			}
		]
	}
	var scene = SceneDataScript.from_dict(d)
	assert_eq(scene.conditions.size(), 1)
	assert_eq(scene.conditions[0].uuid, "cond-uuid")
	assert_eq(scene.conditions[0].condition_name, "Health")
	assert_eq(scene.conditions[0].variable, "health")
	assert_eq(scene.conditions[0].rules.size(), 1)
	assert_not_null(scene.conditions[0].default_consequence)

func test_from_dict_without_conditions_key():
	var d = {"uuid": "x", "name": "S"}
	var scene = SceneDataScript.from_dict(d)
	assert_eq(scene.conditions.size(), 0)

func test_roundtrip_with_conditions():
	var scene = SceneDataScript.new()
	scene.scene_name = "Test Scene"

	var cond = ConditionScript.new()
	cond.condition_name = "Cond1"
	cond.variable = "flag"
	var rule = ConditionRuleScript.new()
	rule.operator = "exists"
	var cons = ConsequenceScript.new()
	cons.type = "redirect_sequence"
	cons.target = "s1"
	rule.consequence = cons
	cond.rules.append(rule)
	scene.conditions.append(cond)

	var restored = SceneDataScript.from_dict(scene.to_dict())
	assert_eq(restored.conditions.size(), 1)
	assert_eq(restored.conditions[0].condition_name, "Cond1")
	assert_eq(restored.conditions[0].variable, "flag")
	assert_eq(restored.conditions[0].rules.size(), 1)
	assert_eq(restored.conditions[0].rules[0].operator, "exists")
