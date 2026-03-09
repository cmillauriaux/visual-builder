extends GutTest

var RenameNodeCommandScript

func before_each():
	RenameNodeCommandScript = load("res://src/commands/rename_node_command.gd")

func test_execute_renames():
	var name_container = ["Old"]
	var setter = func(n, s): name_container[0] = n
	var getter = func(): return [name_container[0], ""]
	var cmd = RenameNodeCommandScript.new(setter, getter, "New", "", "Old", "", "type")
	cmd.execute()
	assert_eq(name_container[0], "New")

func test_undo_restores_name():
	var name_container = ["Old"]
	var setter = func(n, s): name_container[0] = n
	var getter = func(): return [name_container[0], ""]
	var cmd = RenameNodeCommandScript.new(setter, getter, "New", "", "Old", "", "type")
	cmd.execute()
	cmd.undo()
	assert_eq(name_container[0], "Old")
