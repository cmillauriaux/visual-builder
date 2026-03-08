extends GutTest

const SceneDataScript = preload("res://src/models/scene_data.gd")
const AddSequenceCommand = preload("res://src/commands/add_sequence_command.gd")


func test_execute_adds_sequence_to_scene():
	var scene = SceneDataScript.new()
	var cmd = AddSequenceCommand.new(scene, "Séquence 1", Vector2(30, 40))
	cmd.execute()
	assert_eq(scene.sequences.size(), 1)
	assert_eq(scene.sequences[0].seq_name, "Séquence 1")
	assert_eq(scene.sequences[0].position, Vector2(30, 40))


func test_undo_removes_sequence():
	var scene = SceneDataScript.new()
	var cmd = AddSequenceCommand.new(scene, "Séquence 1", Vector2.ZERO)
	cmd.execute()
	cmd.undo()
	assert_eq(scene.sequences.size(), 0)


func test_get_label():
	var scene = SceneDataScript.new()
	var cmd = AddSequenceCommand.new(scene, "Ma Séquence", Vector2.ZERO)
	assert_string_contains(cmd.get_label(), "Ma Séquence")
