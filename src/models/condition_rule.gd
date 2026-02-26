extends RefCounted

const ConsequenceScript = preload("res://src/models/consequence.gd")

const VALID_OPERATORS := ["equal", "not_equal", "greater_than", "greater_than_equal", "less_than", "less_than_equal", "exists", "not_exists"]
const NUMERIC_OPERATORS := ["greater_than", "greater_than_equal", "less_than", "less_than_equal"]

var operator: String = ""
var value: String = ""
var consequence = null  # Consequence

## Évalue cette règle contre un dictionnaire de variables.
## Retourne true si la règle matche.
func evaluate(variables: Dictionary, variable_name: String) -> bool:
	match operator:
		"exists":
			return variables.has(variable_name)
		"not_exists":
			return not variables.has(variable_name)

	if not variables.has(variable_name):
		return false

	var var_value = str(variables[variable_name])

	if operator == "equal":
		return var_value == value
	elif operator == "not_equal":
		return var_value != value

	# Comparaisons numériques
	if operator in NUMERIC_OPERATORS:
		if not var_value.is_valid_float() or not value.is_valid_float():
			return false
		var fvar = var_value.to_float()
		var fval = value.to_float()
		match operator:
			"greater_than":
				return fvar > fval
			"greater_than_equal":
				return fvar >= fval
			"less_than":
				return fvar < fval
			"less_than_equal":
				return fvar <= fval

	return false

func to_dict() -> Dictionary:
	return {
		"operator": operator,
		"value": value,
		"consequence": consequence.to_dict() if consequence else {},
	}

static func from_dict(d: Dictionary):
	var script = load("res://src/models/condition_rule.gd")
	var rule = script.new()
	rule.operator = d.get("operator", "")
	rule.value = d.get("value", "")
	if d.has("consequence") and not d["consequence"].is_empty():
		rule.consequence = ConsequenceScript.from_dict(d["consequence"])
	return rule
