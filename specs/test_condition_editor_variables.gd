extends GutTest

const ConditionEditorScript = preload("res://src/ui/condition_editor.gd")

var _editor: VBoxContainer

func before_each():
	_editor = VBoxContainer.new()
	_editor.set_script(ConditionEditorScript)
	add_child(_editor)

func after_each():
	_editor.queue_free()

func test_set_variable_names():
	_editor.set_variable_names(["score", "hp", "level"])
	assert_eq(_editor.get_variable_names(), ["score", "hp", "level"])

func test_set_variable_names_empty():
	_editor.set_variable_names([])
	assert_eq(_editor.get_variable_names(), [])

func test_tooltip_updated_with_variable_names():
	_editor.set_variable_names(["score", "hp"])
	assert_true(_editor._variable_edit.tooltip_text.contains("score"))
	assert_true(_editor._variable_edit.tooltip_text.contains("hp"))
