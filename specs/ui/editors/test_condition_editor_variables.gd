extends GutTest

const ConditionEditorScript = preload("res://src/ui/editors/condition_editor.gd")
const ConditionScript = preload("res://src/models/condition.gd")

var _editor: VBoxContainer
var _condition: Object

func before_each():
	_editor = VBoxContainer.new()
	_editor.set_script(ConditionEditorScript)
	add_child(_editor)
	_condition = ConditionScript.new()
	_condition.condition_name = "Test"

func after_each():
	_editor.queue_free()

func test_set_variable_names():
	_editor.set_variable_names(["score", "hp", "level"])
	assert_eq(_editor.get_variable_names(), ["score", "hp", "level"])

func test_set_variable_names_empty():
	_editor.set_variable_names([])
	assert_eq(_editor.get_variable_names(), [])

func test_variable_names_shown_in_rule_tooltip():
	_editor.load_condition(_condition)
	_editor.set_available_targets(
		[{"uuid": "s1", "name": "Seq1"}],
		[{"uuid": "sc1", "name": "Scene1"}],
		[{"uuid": "ch1", "name": "Chapter1"}]
	)
	_editor.set_variable_names(["score", "hp"])
	_editor.add_rule()
	# The variable edit in the rule row should have a tooltip with variable names
	var rule_row = _editor._rules_list.get_child(0)
	var var_edit = rule_row.get_node_or_null("HBoxContainer/VariableEdit")
	if var_edit == null:
		# Try finding by iterating children
		for child in rule_row.get_children():
			if child is HBoxContainer:
				for sub in child.get_children():
					if sub is LineEdit and sub.name == "VariableEdit":
						var_edit = sub
						break
				if var_edit:
					break
	assert_not_null(var_edit, "Le champ VariableEdit doit exister dans la règle")
	if var_edit:
		assert_true(var_edit.tooltip_text.contains("score"), "Le tooltip doit contenir 'score'")
		assert_true(var_edit.tooltip_text.contains("hp"), "Le tooltip doit contenir 'hp'")
