extends GutTest

const SceneDataScript = preload("res://src/models/scene_data.gd")
const SequenceScript = preload("res://src/models/sequence.gd")
const RemoveSequenceCommand = preload("res://src/commands/remove_sequence_command.gd")


func test_execute_removes_sequence():
	var scene = SceneDataScript.new()
	var seq = SequenceScript.new()
	seq.seq_name = "Séq 1"
	scene.sequences = [seq]
	var cmd = RemoveSequenceCommand.new(scene, seq)
	cmd.execute()
	assert_eq(scene.sequences.size(), 0)


func test_undo_restores_sequence_at_correct_index():
	var scene = SceneDataScript.new()
	var s1 = SequenceScript.new()
	s1.seq_name = "A"
	var s2 = SequenceScript.new()
	s2.seq_name = "B"
	scene.sequences = [s1, s2]
	var cmd = RemoveSequenceCommand.new(scene, s1)
	cmd.execute()
	cmd.undo()
	assert_eq(scene.sequences.size(), 2)
	assert_eq(scene.sequences[0].seq_name, "A")


func test_get_label():
	var scene = SceneDataScript.new()
	var seq = SequenceScript.new()
	seq.seq_name = "Ma Séquence"
	scene.sequences = [seq]
	var cmd = RemoveSequenceCommand.new(scene, seq)
	assert_string_contains(cmd.get_label(), "Ma Séquence")
