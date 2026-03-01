extends "res://src/commands/base_command.gd"

var _sequence
var _dialogue
var _index: int

func _init(sequence, index: int) -> void:
	_sequence = sequence
	_index = index
	_dialogue = sequence.dialogues[index]

func execute() -> void:
	_sequence.dialogues.remove_at(_index)

func undo() -> void:
	_sequence.dialogues.insert(_index, _dialogue)

func get_label() -> String:
	return "Suppression dialogue"
