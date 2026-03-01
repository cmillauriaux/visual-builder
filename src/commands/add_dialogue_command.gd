extends "res://src/commands/base_command.gd"

const DialogueScript = preload("res://src/models/dialogue.gd")

var _sequence
var _dialogue

func _init(sequence, character: String, text: String) -> void:
	_sequence = sequence
	_dialogue = DialogueScript.new()
	_dialogue.character = character
	_dialogue.text = text

func execute() -> void:
	_sequence.dialogues.append(_dialogue)

func undo() -> void:
	_sequence.dialogues.erase(_dialogue)

func get_label() -> String:
	return "Ajout dialogue"
