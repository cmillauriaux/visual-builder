extends "res://src/commands/base_command.gd"

var _scene
var _condition
var _index: int
var _label: String

func _init(scene, condition) -> void:
	_scene = scene
	_condition = condition
	_index = scene.conditions.find(condition)
	_label = "Suppression condition \"%s\"" % condition.condition_name

func execute() -> void:
	_scene.conditions.erase(_condition)

func undo() -> void:
	_scene.conditions.insert(_index, _condition)

func get_label() -> String:
	return _label
