extends Control

## Éditeur de terminaison pour une séquence.

const EndingScript = preload("res://src/models/ending.gd")
const ConsequenceScript = preload("res://src/models/consequence.gd")
const ChoiceScript = preload("res://src/models/choice.gd")

var _sequence = null

func load_sequence(sequence) -> void:
	_sequence = sequence

func get_ending_type() -> String:
	if _sequence == null or _sequence.ending == null:
		return ""
	return _sequence.ending.type

func set_ending_type(type: String) -> void:
	if _sequence == null:
		return
	var ending = EndingScript.new()
	ending.type = type
	_sequence.ending = ending

func add_choice(text: String, consequence_type: String, target: String) -> void:
	if _sequence == null or _sequence.ending == null:
		return
	if _sequence.ending.choices.size() >= 8:
		return
	var choice = ChoiceScript.new()
	choice.text = text
	var consequence = ConsequenceScript.new()
	consequence.type = consequence_type
	consequence.target = target
	choice.consequence = consequence
	_sequence.ending.choices.append(choice)

func remove_choice(index: int) -> void:
	if _sequence == null or _sequence.ending == null:
		return
	if index < 0 or index >= _sequence.ending.choices.size():
		return
	_sequence.ending.choices.remove_at(index)

func set_auto_consequence(type: String, target: String) -> void:
	if _sequence == null or _sequence.ending == null:
		return
	var consequence = ConsequenceScript.new()
	consequence.type = type
	consequence.target = target
	_sequence.ending.auto_consequence = consequence
