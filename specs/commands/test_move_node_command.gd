extends GutTest

const MoveNodeCommand = preload("res://src/commands/move_node_command.gd")

var _position: Vector2


func _set_position(pos: Vector2) -> void:
	_position = pos


func test_execute_calls_setter_with_new_position():
	_position = Vector2(10, 20)
	var cmd = MoveNodeCommand.new(_set_position, Vector2(10, 20), Vector2(100, 200))
	cmd.execute()
	assert_eq(_position, Vector2(100, 200))


func test_undo_calls_setter_with_old_position():
	_position = Vector2(10, 20)
	var cmd = MoveNodeCommand.new(_set_position, Vector2(10, 20), Vector2(100, 200))
	cmd.execute()
	cmd.undo()
	assert_eq(_position, Vector2(10, 20))


func test_get_label():
	var cmd = MoveNodeCommand.new(_set_position, Vector2.ZERO, Vector2.ONE)
	assert_eq(cmd.get_label(), "Déplacement nœud")
