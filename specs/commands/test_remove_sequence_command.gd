extends GutTest

var SceneDataScript
var SequenceScript
var RemoveSequenceCommandScript

func before_each():
	SceneDataScript = load("res://src/models/scene_data.gd")
	SequenceScript = load("res://src/models/sequence.gd")
	RemoveSequenceCommandScript = load("res://src/commands/remove_sequence_command.gd")

func test_execute_removes_sequence():
	var scene = SceneDataScript.new()
	var sequence = SequenceScript.new()
	scene.sequences.append(sequence)
	var cmd = RemoveSequenceCommandScript.new(scene, sequence)
	cmd.execute()
	assert_eq(scene.sequences.size(), 0)

func test_undo_restores_sequence():
	var scene = SceneDataScript.new()
	var sequence = SequenceScript.new()
	scene.sequences.append(sequence)
	var cmd = RemoveSequenceCommandScript.new(scene, sequence)
	cmd.execute()
	cmd.undo()
	assert_eq(scene.sequences.size(), 1)
