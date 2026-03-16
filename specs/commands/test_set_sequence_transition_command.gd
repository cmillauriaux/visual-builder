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


# --- get_label ---

func test_get_label_fade_transition_in_single():
	var seq = SequenceScript.new()
	var cmd = SetSequenceTransitionCommandScript.new([seq], "transition_in_type", "fade")
	assert_eq(cmd.get_label(), "Modifier Transition d'entrée : Fondu")

func test_get_label_pixelate_transition_in_single():
	var seq = SequenceScript.new()
	var cmd = SetSequenceTransitionCommandScript.new([seq], "transition_in_type", "pixelate")
	assert_eq(cmd.get_label(), "Modifier Transition d'entrée : Pixellisation")

func test_get_label_none_value_transition_in():
	var seq = SequenceScript.new()
	var cmd = SetSequenceTransitionCommandScript.new([seq], "transition_in_type", "none")
	assert_eq(cmd.get_label(), "Modifier Transition d'entrée : Aucune")

func test_get_label_fade_transition_out_single():
	var seq = SequenceScript.new()
	var cmd = SetSequenceTransitionCommandScript.new([seq], "transition_out_type", "fade")
	assert_eq(cmd.get_label(), "Modifier Transition de sortie : Fondu")

func test_get_label_pixelate_transition_out_single():
	var seq = SequenceScript.new()
	var cmd = SetSequenceTransitionCommandScript.new([seq], "transition_out_type", "pixelate")
	assert_eq(cmd.get_label(), "Modifier Transition de sortie : Pixellisation")

func test_get_label_multiple_sequences():
	var seq1 = SequenceScript.new()
	var seq2 = SequenceScript.new()
	var cmd = SetSequenceTransitionCommandScript.new([seq1, seq2], "transition_in_type", "fade")
	assert_eq(cmd.get_label(), "Modifier Transition d'entrée : Fondu (2 séquences)")

func test_get_label_multiple_sequences_out():
	var seq1 = SequenceScript.new()
	var seq2 = SequenceScript.new()
	var seq3 = SequenceScript.new()
	var cmd = SetSequenceTransitionCommandScript.new([seq1, seq2, seq3], "transition_out_type", "pixelate")
	assert_eq(cmd.get_label(), "Modifier Transition de sortie : Pixellisation (3 séquences)")


# --- Multi-sequence execute/undo ---

func test_execute_multiple_sequences():
	var seq1 = SequenceScript.new()
	var seq2 = SequenceScript.new()
	var cmd = SetSequenceTransitionCommandScript.new([seq1, seq2], "transition_out_type", "pixelate")
	cmd.execute()
	assert_eq(seq1.transition_out_type, "pixelate")
	assert_eq(seq2.transition_out_type, "pixelate")

func test_undo_multiple_sequences_restores_individual_values():
	var seq1 = SequenceScript.new()
	var seq2 = SequenceScript.new()
	seq1.transition_out_type = "fade"
	seq2.transition_out_type = "none"
	var cmd = SetSequenceTransitionCommandScript.new([seq1, seq2], "transition_out_type", "pixelate")
	cmd.execute()
	cmd.undo()
	assert_eq(seq1.transition_out_type, "fade")
	assert_eq(seq2.transition_out_type, "none")
