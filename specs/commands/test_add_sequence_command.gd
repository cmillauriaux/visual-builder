extends GutTest

var SceneDataScript
var AddSequenceCommandScript

func before_each():
	SceneDataScript = load("res://src/models/scene_data.gd")
	AddSequenceCommandScript = load("res://src/commands/add_sequence_command.gd")

func test_execute_adds_sequence_to_scene():
	var scene = SceneDataScript.new()
	var cmd = AddSequenceCommandScript.new(scene, "Nouvelle Séquence", Vector2(10, 10))
	cmd.execute()
	assert_eq(scene.sequences.size(), 1)
	assert_eq(scene.sequences[0].seq_name, "Nouvelle Séquence")

func test_undo_removes_sequence():
	var scene = SceneDataScript.new()
	var cmd = AddSequenceCommandScript.new(scene, "Nouvelle Séquence", Vector2(10, 10))
	cmd.execute()
	cmd.undo()
	assert_eq(scene.sequences.size(), 0)

func test_get_label():
	var scene = SceneDataScript.new()
	var cmd = AddSequenceCommandScript.new(scene, "Ma Seq", Vector2.ZERO)
	assert_string_contains(cmd.get_label(), "Ma Seq")
