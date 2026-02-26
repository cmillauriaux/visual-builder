extends RefCounted

const ConditionRuleScript = preload("res://src/models/condition_rule.gd")
const ConsequenceScript = preload("res://src/models/consequence.gd")

var uuid: String = ""
var condition_name: String = ""
var subtitle: String = ""
var position: Vector2 = Vector2.ZERO
var rules: Array = []  # Array[ConditionRule]
var default_consequence = null  # Consequence

func _init():
	uuid = _generate_uuid()

static func _generate_uuid() -> String:
	var chars = "abcdef0123456789"
	var result = ""
	for i in range(8):
		result += chars[randi() % chars.length()]
	result += "-"
	for i in range(4):
		result += chars[randi() % chars.length()]
	result += "-4"
	for i in range(3):
		result += chars[randi() % chars.length()]
	result += "-"
	for i in range(4):
		result += chars[randi() % chars.length()]
	result += "-"
	for i in range(12):
		result += chars[randi() % chars.length()]
	return result

## Évalue la condition contre un dictionnaire de variables.
## Retourne la Consequence de la première règle qui matche, ou default_consequence, ou null.
func evaluate(variables: Dictionary):
	for rule in rules:
		if rule.evaluate(variables):
			return rule.consequence
	return default_consequence

func to_dict() -> Dictionary:
	var rules_arr := []
	for rule in rules:
		rules_arr.append(rule.to_dict())

	var d := {
		"uuid": uuid,
		"name": condition_name,
		"subtitle": subtitle,
		"position": {"x": position.x, "y": position.y},
		"rules": rules_arr,
	}

	if default_consequence:
		d["default_consequence"] = default_consequence.to_dict()

	return d

static func from_dict(d: Dictionary):
	var script = load("res://src/models/condition.gd")
	var cond = script.new()
	cond.uuid = d.get("uuid", cond.uuid)
	cond.condition_name = d.get("name", "")
	cond.subtitle = d.get("subtitle", "")
	if d.has("position"):
		cond.position = Vector2(d["position"].get("x", 0), d["position"].get("y", 0))

	if d.has("rules"):
		for rule_dict in d["rules"]:
			cond.rules.append(ConditionRuleScript.from_dict(rule_dict))

	if d.has("default_consequence"):
		cond.default_consequence = ConsequenceScript.from_dict(d["default_consequence"])

	return cond
