extends GutTest

const SequenceScript = preload("res://src/models/sequence.gd")
const SetSequenceTransitionCommand = preload("res://src/commands/set_sequence_transition_command.gd")

var _seq1
var _seq2

func before_each() -> void:
	_seq1 = SequenceScript.new()
	_seq1.seq_name = "Seq 1"
	_seq1.transition_in_type = "none"
	_seq1.transition_out_type = "none"
	
	_seq2 = SequenceScript.new()
	_seq2.seq_name = "Seq 2"
	_seq2.transition_in_type = "none"
	_seq2.transition_out_type = "none"

func test_set_transition_in_execute() -> void:
	var cmd = SetSequenceTransitionCommand.new([_seq1, _seq2], "transition_in_type", "fade")
	cmd.execute()
	assert_eq(_seq1.transition_in_type, "fade")
	assert_eq(_seq2.transition_in_type, "fade")

func test_set_transition_in_undo() -> void:
	_seq1.transition_in_type = "pixelate"
	var cmd = SetSequenceTransitionCommand.new([_seq1, _seq2], "transition_in_type", "fade")
	cmd.execute()
	cmd.undo()
	assert_eq(_seq1.transition_in_type, "pixelate")
	assert_eq(_seq2.transition_in_type, "none")

func test_set_transition_out_execute() -> void:
	var cmd = SetSequenceTransitionCommand.new([_seq1], "transition_out_type", "pixelate")
	cmd.execute()
	assert_eq(_seq1.transition_out_type, "pixelate")

func test_set_transition_out_undo() -> void:
	var cmd = SetSequenceTransitionCommand.new([_seq1], "transition_out_type", "pixelate")
	cmd.execute()
	cmd.undo()
	assert_eq(_seq1.transition_out_type, "none")

func test_label_single() -> void:
	var cmd = SetSequenceTransitionCommand.new([_seq1], "transition_in_type", "fade")
	assert_eq(cmd.get_label(), "Modifier Transition d'entrée : Fondu")

func test_label_multiple() -> void:
	var cmd = SetSequenceTransitionCommand.new([_seq1, _seq2], "transition_out_type", "pixelate")
	assert_eq(cmd.get_label(), "Modifier Transition de sortie : Pixellisation (2 séquences)")
