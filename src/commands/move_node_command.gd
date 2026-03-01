extends "res://src/commands/base_command.gd"

## Commande de déplacement générique.
## Prend un callable setter(position: Vector2).

var _setter: Callable
var _old_position: Vector2
var _new_position: Vector2

func _init(setter: Callable, old_position: Vector2, new_position: Vector2) -> void:
	_setter = setter
	_old_position = old_position
	_new_position = new_position

func execute() -> void:
	_setter.call(_new_position)

func undo() -> void:
	_setter.call(_old_position)

func get_label() -> String:
	return "Déplacement nœud"
