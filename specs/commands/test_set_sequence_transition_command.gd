extends GutTest

var SequenceScript
var SetSequenceTransitionCommandScript

func before_each():
	SequenceScript = load("res://src/models/sequence.gd")
	SetSequenceTransitionCommandScript = load("res://src/commands/set_sequence_transition_command.gd")

func test_execute_sets_transition():
	var sequence = SequenceScript.new()
	var cmd = SetSequenceTransitionCommandScript.new([sequence], "transition_in_type", "fade")
	cmd.execute()
	assert_eq(sequence.transition_in_type, "fade")

func test_undo_restores_transition():
	var sequence = SequenceScript.new()
	var cmd = SetSequenceTransitionCommandScript.new([sequence], "transition_in_type", "fade")
	cmd.execute()
	cmd.undo()
	assert_eq(sequence.transition_in_type, "none")
