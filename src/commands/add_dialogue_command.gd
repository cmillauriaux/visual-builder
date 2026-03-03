extends "res://src/commands/base_command.gd"

const DialogueScript = preload("res://src/models/dialogue.gd")

var _sequence
var _dialogue
var _index: int

func _init(sequence, character: String, text: String, index: int = -1) -> void:
	_sequence = sequence
	_dialogue = DialogueScript.new()
	_dialogue.character = character
	_dialogue.text = text
	_index = index

func execute() -> void:
	if _index >= 0 and _index <= _sequence.dialogues.size():
		_sequence.dialogues.insert(_index, _dialogue)
	else:
		_index = _sequence.dialogues.size()
		_sequence.dialogues.append(_dialogue)

func undo() -> void:
	_sequence.dialogues.erase(_dialogue)

func get_label() -> String:
	return "Ajout dialogue"
