extends "res://src/commands/base_command.gd"

var _scene
var _sequence
var _index: int
var _label: String

func _init(scene, sequence) -> void:
	_scene = scene
	_sequence = sequence
	_index = scene.sequences.find(sequence)
	_label = "Suppression séquence \"%s\"" % sequence.seq_name

func execute() -> void:
	_scene.sequences.erase(_sequence)

func undo() -> void:
	_scene.sequences.insert(_index, _sequence)

func get_label() -> String:
	return _label
