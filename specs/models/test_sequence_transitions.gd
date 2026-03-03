extends "res://addons/gut/test.gd"

const SequenceModel = preload("res://src/models/sequence.gd")

func test_sequence_transitions_default_values():
	var seq = SequenceModel.new()
	assert_eq(seq.transition_in_type, "none")
	assert_eq(seq.transition_in_duration, 0.5)
	assert_eq(seq.transition_out_type, "none")
	assert_eq(seq.transition_out_duration, 0.5)

func test_to_from_dict_with_transitions():
	var seq = SequenceModel.new()
	seq.transition_in_type = "fade"
	seq.transition_in_duration = 1.0
	seq.transition_out_type = "pixelate"
	seq.transition_out_duration = 2.0
	
	var d = seq.to_dict()
	assert_eq(d["transition_in_type"], "fade")
	assert_eq(d["transition_in_duration"], 1.0)
	assert_eq(d["transition_out_type"], "pixelate")
	assert_eq(d["transition_out_duration"], 2.0)
	
	var seq2 = SequenceModel.from_dict(d)
	assert_eq(seq2.transition_in_type, "fade")
	assert_eq(seq2.transition_in_duration, 1.0)
	assert_eq(seq2.transition_out_type, "pixelate")
	assert_eq(seq2.transition_out_duration, 2.0)
