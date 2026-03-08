extends GutTest

const SceneDataScript = preload("res://src/models/scene_data.gd")
const AddConditionCommand = preload("res://src/commands/add_condition_command.gd")


func test_execute_adds_condition_to_scene():
	var scene = SceneDataScript.new()
	var cmd = AddConditionCommand.new(scene, "Condition A", Vector2(50, 50))
	cmd.execute()
	assert_eq(scene.conditions.size(), 1)
	assert_eq(scene.conditions[0].condition_name, "Condition A")
	assert_eq(scene.conditions[0].position, Vector2(50, 50))


func test_undo_removes_condition():
	var scene = SceneDataScript.new()
	var cmd = AddConditionCommand.new(scene, "Condition A", Vector2.ZERO)
	cmd.execute()
	cmd.undo()
	assert_eq(scene.conditions.size(), 0)


func test_get_label():
	var scene = SceneDataScript.new()
	var cmd = AddConditionCommand.new(scene, "Ma Condition", Vector2.ZERO)
	assert_string_contains(cmd.get_label(), "Ma Condition")
