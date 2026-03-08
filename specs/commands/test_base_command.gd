extends GutTest

const BaseCommand = preload("res://src/commands/base_command.gd")


func test_execute_does_nothing_by_default():
	var cmd = BaseCommand.new()
	cmd.execute()
	assert_true(true, "execute() should not crash")


func test_undo_does_nothing_by_default():
	var cmd = BaseCommand.new()
	cmd.undo()
	assert_true(true, "undo() should not crash")


func test_get_label_returns_empty_string():
	var cmd = BaseCommand.new()
	assert_eq(cmd.get_label(), "")
