extends GutTest

var SceneDataScript
var AddConditionCommandScript

func before_each():
	SceneDataScript = load("res://src/models/scene_data.gd")
	AddConditionCommandScript = load("res://src/commands/add_condition_command.gd")

func test_execute_adds_condition_to_scene():
	var scene = SceneDataScript.new()
	var cmd = AddConditionCommandScript.new(scene, "Nouvelle Condition", Vector2(10, 10))
	cmd.execute()
	assert_eq(scene.conditions.size(), 1)
	assert_eq(scene.conditions[0].condition_name, "Nouvelle Condition")

func test_undo_removes_condition():
	var scene = SceneDataScript.new()
	var cmd = AddConditionCommandScript.new(scene, "Nouvelle Condition", Vector2(10, 10))
	cmd.execute()
	cmd.undo()
	assert_eq(scene.conditions.size(), 0)

func test_get_label():
	var scene = SceneDataScript.new()
	var cmd = AddConditionCommandScript.new(scene, "Ma Cond", Vector2.ZERO)
	assert_string_contains(cmd.get_label(), "Ma Cond")
