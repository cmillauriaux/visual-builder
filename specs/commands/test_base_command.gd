extends GutTest

var BaseCommandScript

func before_each():
	BaseCommandScript = load("res://src/commands/base_command.gd")

func test_execute_does_nothing():
	var cmd = BaseCommandScript.new()
	cmd.execute()
	assert_true(true)

func test_get_label_empty():
	var cmd = BaseCommandScript.new()
	assert_eq(cmd.get_label(), "")
