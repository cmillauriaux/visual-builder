extends GutTest

var MoveNodeCommandScript

func before_each():
	MoveNodeCommandScript = load("res://src/commands/move_node_command.gd")

func test_execute_moves():
	var pos_container = [Vector2.ZERO]
	var pos_setter = func(p): pos_container[0] = p
	var cmd = MoveNodeCommandScript.new(pos_setter, Vector2.ZERO, Vector2.ONE)
	cmd.execute()
	assert_eq(pos_container[0], Vector2.ONE)

func test_undo_moves_back():
	var pos_container = [Vector2.ZERO]
	var pos_setter = func(p): pos_container[0] = p
	var cmd = MoveNodeCommandScript.new(pos_setter, Vector2.ZERO, Vector2.ONE)
	cmd.execute()
	cmd.undo()
	assert_eq(pos_container[0], Vector2.ZERO)
