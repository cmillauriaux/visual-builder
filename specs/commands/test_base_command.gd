extends GutTest

var BaseCommandScript

func before_each():
	BaseCommandScript = load("res://src/commands/base_command.gd")

func test_execute_does_nothing():
	var cmd = BaseCommandScript.new()
	cmd.execute()
	assert_true(true)

func test_undo_does_not_crash() -> void:
	var cmd = BaseCommandScript.new()
	cmd.undo()
	pass_test("base_command.undo() should not crash")

func test_get_label_returns_empty_string() -> void:
	var cmd = BaseCommandScript.new()
	assert_eq(cmd.get_label(), "")

func test_get_label_empty():
	var cmd = BaseCommandScript.new()
	assert_eq(cmd.get_label(), "")
