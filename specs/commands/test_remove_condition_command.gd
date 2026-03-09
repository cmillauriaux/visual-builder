extends GutTest

var SceneDataScript
var ConditionScript
var RemoveConditionCommandScript

func before_each():
	SceneDataScript = load("res://src/models/scene_data.gd")
	ConditionScript = load("res://src/models/condition.gd")
	RemoveConditionCommandScript = load("res://src/commands/remove_condition_command.gd")

func test_execute_removes_condition():
	var scene = SceneDataScript.new()
	var condition = ConditionScript.new()
	scene.conditions.append(condition)
	var cmd = RemoveConditionCommandScript.new(scene, condition)
	cmd.execute()
	assert_eq(scene.conditions.size(), 0)

func test_undo_restores_condition():
	var scene = SceneDataScript.new()
	var condition = ConditionScript.new()
	scene.conditions.append(condition)
	var cmd = RemoveConditionCommandScript.new(scene, condition)
	cmd.execute()
	cmd.undo()
	assert_eq(scene.conditions.size(), 1)
