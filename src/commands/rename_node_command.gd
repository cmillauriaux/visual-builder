extends "res://src/commands/base_command.gd"

## Commande de renommage générique.
## Prend un callable setter(name, subtitle) et un callable getter() -> [name, subtitle].

var _setter: Callable
var _new_name: String
var _new_subtitle: String
var _old_name: String
var _old_subtitle: String
var _label: String

func _init(setter: Callable, _getter: Callable, new_name: String, new_subtitle: String,
		old_name: String, old_subtitle: String, node_type: String) -> void:
	_setter = setter
	_new_name = new_name
	_new_subtitle = new_subtitle
	_old_name = old_name
	_old_subtitle = old_subtitle
	_label = "Renommage %s en \"%s\"" % [node_type, new_name]

func execute() -> void:
	_setter.call(_new_name, _new_subtitle)

func undo() -> void:
	_setter.call(_old_name, _old_subtitle)

func get_label() -> String:
	return _label
