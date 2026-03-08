extends GutTest

const SceneDataScript = preload("res://src/models/scene_data.gd")
const ConditionScript = preload("res://src/models/condition.gd")
const RemoveConditionCommand = preload("res://src/commands/remove_condition_command.gd")


func test_execute_removes_condition():
	var scene = SceneDataScript.new()
	var cond = ConditionScript.new()
	cond.condition_name = "Cond A"
	scene.conditions = [cond]
	var cmd = RemoveConditionCommand.new(scene, cond)
	cmd.execute()
	assert_eq(scene.conditions.size(), 0)


func test_undo_restores_condition_at_correct_index():
	var scene = SceneDataScript.new()
	var c1 = ConditionScript.new()
	c1.condition_name = "A"
	var c2 = ConditionScript.new()
	c2.condition_name = "B"
	scene.conditions = [c1, c2]
	var cmd = RemoveConditionCommand.new(scene, c1)
	cmd.execute()
	cmd.undo()
	assert_eq(scene.conditions.size(), 2)
	assert_eq(scene.conditions[0].condition_name, "A")


func test_get_label():
	var scene = SceneDataScript.new()
	var cond = ConditionScript.new()
	cond.condition_name = "Ma Condition"
	scene.conditions = [cond]
	var cmd = RemoveConditionCommand.new(scene, cond)
	assert_string_contains(cmd.get_label(), "Ma Condition")
