extends GutTest

const EffectRowBuilderScript = preload("res://src/ui/shared/effect_row_builder.gd")
const VariableEffectScript = preload("res://src/models/variable_effect.gd")

var _last_var_changed: String = ""
var _last_op_changed: String = ""
var _last_value_changed: String = ""
var _delete_called: bool = false


func before_each():
	_last_var_changed = ""
	_last_op_changed = ""
	_last_value_changed = ""
	_delete_called = false


func _make_effect(variable: String = "", operation: String = "set", value: String = ""):
	var e = VariableEffectScript.new()
	e.variable = variable
	e.operation = operation
	e.value = value
	return e


func _on_var(t): _last_var_changed = t
func _on_op(op): _last_op_changed = op
func _on_val(t): _last_value_changed = t
func _on_del(): _delete_called = true


# --- Structure ---

func test_creates_hbox_container():
	var row = EffectRowBuilderScript.create_effect_row(
		_make_effect(), [], _on_var, _on_op, _on_val, _on_del
	)
	add_child_autofree(row)
	assert_true(row is HBoxContainer)

func test_has_four_children():
	var row = EffectRowBuilderScript.create_effect_row(
		_make_effect(), [], _on_var, _on_op, _on_val, _on_del
	)
	add_child_autofree(row)
	assert_eq(row.get_child_count(), 4)

func test_children_types():
	var row = EffectRowBuilderScript.create_effect_row(
		_make_effect(), [], _on_var, _on_op, _on_val, _on_del
	)
	add_child_autofree(row)
	assert_true(row.get_child(0) is LineEdit, "First child is LineEdit (variable)")
	assert_true(row.get_child(1) is OptionButton, "Second child is OptionButton (operation)")
	assert_true(row.get_child(2) is LineEdit, "Third child is LineEdit (value)")
	assert_true(row.get_child(3) is Button, "Fourth child is Button (delete)")


# --- Variable field ---

func test_variable_text_set():
	var row = EffectRowBuilderScript.create_effect_row(
		_make_effect("hp"), [], _on_var, _on_op, _on_val, _on_del
	)
	add_child_autofree(row)
	assert_eq(row.get_child(0).text, "hp")

func test_variable_tooltip_with_names():
	var row = EffectRowBuilderScript.create_effect_row(
		_make_effect(), ["hp", "score"], _on_var, _on_op, _on_val, _on_del
	)
	add_child_autofree(row)
	assert_eq(row.get_child(0).tooltip_text, "hp, score")

func test_variable_tooltip_empty_when_no_names():
	var row = EffectRowBuilderScript.create_effect_row(
		_make_effect(), [], _on_var, _on_op, _on_val, _on_del
	)
	add_child_autofree(row)
	assert_eq(row.get_child(0).tooltip_text, "")


# --- Operation dropdown ---

func test_operation_dropdown_has_all_operations():
	var row = EffectRowBuilderScript.create_effect_row(
		_make_effect(), [], _on_var, _on_op, _on_val, _on_del
	)
	add_child_autofree(row)
	var dropdown = row.get_child(1) as OptionButton
	assert_eq(dropdown.item_count, VariableEffectScript.VALID_OPERATIONS.size())

func test_operation_dropdown_labels():
	var row = EffectRowBuilderScript.create_effect_row(
		_make_effect(), [], _on_var, _on_op, _on_val, _on_del
	)
	add_child_autofree(row)
	var dropdown = row.get_child(1) as OptionButton
	for i in range(VariableEffectScript.OPERATION_LABELS.size()):
		assert_eq(dropdown.get_item_text(i), VariableEffectScript.OPERATION_LABELS[i])

func test_operation_selected_matches_effect():
	var row = EffectRowBuilderScript.create_effect_row(
		_make_effect("", "decrement"), [], _on_var, _on_op, _on_val, _on_del
	)
	add_child_autofree(row)
	var dropdown = row.get_child(1) as OptionButton
	assert_eq(dropdown.selected, 2)  # decrement is index 2

func test_operation_defaults_to_zero_for_unknown():
	var row = EffectRowBuilderScript.create_effect_row(
		_make_effect("", "unknown_op"), [], _on_var, _on_op, _on_val, _on_del
	)
	add_child_autofree(row)
	assert_eq((row.get_child(1) as OptionButton).selected, 0)


# --- Value field ---

func test_value_text_set():
	var row = EffectRowBuilderScript.create_effect_row(
		_make_effect("", "set", "42"), [], _on_var, _on_op, _on_val, _on_del
	)
	add_child_autofree(row)
	assert_eq(row.get_child(2).text, "42")

func test_value_hidden_for_delete():
	var row = EffectRowBuilderScript.create_effect_row(
		_make_effect("", "delete"), [], _on_var, _on_op, _on_val, _on_del
	)
	add_child_autofree(row)
	assert_false(row.get_child(2).visible)

func test_value_visible_for_set():
	var row = EffectRowBuilderScript.create_effect_row(
		_make_effect("", "set"), [], _on_var, _on_op, _on_val, _on_del
	)
	add_child_autofree(row)
	assert_true(row.get_child(2).visible)


# --- Delete button ---

func test_delete_button_text():
	var row = EffectRowBuilderScript.create_effect_row(
		_make_effect(), [], _on_var, _on_op, _on_val, _on_del
	)
	add_child_autofree(row)
	assert_eq(row.get_child(3).text, "×")
