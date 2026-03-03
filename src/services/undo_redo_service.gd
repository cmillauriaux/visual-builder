extends RefCounted

## Service de gestion de l'historique undo/redo.
## Implémente le pattern Command avec une pile limitée à MAX_HISTORY entrées.

class_name UndoRedoService

const MAX_HISTORY: int = 50

var _undo_stack: Array[RefCounted] = []
var _redo_stack: Array[RefCounted] = []


## Pousse une commande, l'exécute, et vide la pile redo.
func push(command: RefCounted) -> void:
	command.execute()
	_undo_redo_internal(command)


func push_and_execute(command: RefCounted) -> void:
	command.execute()
	_undo_redo_internal(command)


func _undo_redo_internal(command: RefCounted) -> void:
	_undo_stack.append(command)
	if _undo_stack.size() > MAX_HISTORY:
		_undo_stack.remove_at(0)
	_redo_stack.clear()


## Annule la dernière action.
func undo() -> void:
	if _undo_stack.is_empty():
		return
	var command = _undo_stack.pop_back()
	command.undo()
	_redo_stack.append(command)


## Rétablit la dernière action annulée.
func redo() -> void:
	if _redo_stack.is_empty():
		return
	var command = _redo_stack.pop_back()
	command.execute()
	_undo_stack.append(command)


## Vide les deux piles.
func clear() -> void:
	_undo_stack.clear()
	_redo_stack.clear()


func can_undo() -> bool:
	return not _undo_stack.is_empty()


func can_redo() -> bool:
	return not _redo_stack.is_empty()


## Retourne le label de la commande qui serait annulée.
func get_undo_label() -> String:
	if _undo_stack.is_empty():
		return ""
	return _undo_stack.back().get_label()


## Retourne le label de la commande qui serait rétablie.
func get_redo_label() -> String:
	if _redo_stack.is_empty():
		return ""
	return _redo_stack.back().get_label()
