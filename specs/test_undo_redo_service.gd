extends GutTest

## Tests du service UndoRedoService et de la classe BaseCommand.

const UndoRedoService = preload("res://src/services/undo_redo_service.gd")
const BaseCommand = preload("res://src/commands/base_command.gd")

# Commande de test simple qui incrémente / décrémente un compteur
class CounterCommand:
	extends RefCounted
	var _counter: Array  # Array[int] passé par référence
	var _label: String

	func _init(counter: Array, label: String = "Incrément"):
		_counter = counter
		_label = label

	func execute() -> void:
		_counter[0] += 1

	func undo() -> void:
		_counter[0] -= 1

	func get_label() -> String:
		return _label


var _service: RefCounted

func before_each() -> void:
	_service = UndoRedoService.new()


# --- can_undo / can_redo à vide ---

func test_can_undo_false_when_empty() -> void:
	assert_false(_service.can_undo())

func test_can_redo_false_when_empty() -> void:
	assert_false(_service.can_redo())


# --- push + execute ---

func test_push_executes_command() -> void:
	var counter = [0]
	var cmd = CounterCommand.new(counter)
	_service.push(cmd)
	assert_eq(counter[0], 1)

func test_push_enables_can_undo() -> void:
	var counter = [0]
	_service.push(CounterCommand.new(counter))
	assert_true(_service.can_undo())

func test_push_clears_redo_stack() -> void:
	var counter = [0]
	_service.push(CounterCommand.new(counter))
	_service.undo()
	assert_true(_service.can_redo())
	_service.push(CounterCommand.new(counter))
	assert_false(_service.can_redo())


# --- undo ---

func test_undo_reverses_command() -> void:
	var counter = [0]
	_service.push(CounterCommand.new(counter))
	assert_eq(counter[0], 1)
	_service.undo()
	assert_eq(counter[0], 0)

func test_undo_enables_can_redo() -> void:
	var counter = [0]
	_service.push(CounterCommand.new(counter))
	_service.undo()
	assert_true(_service.can_redo())

func test_undo_disables_can_undo_when_stack_empty() -> void:
	var counter = [0]
	_service.push(CounterCommand.new(counter))
	_service.undo()
	assert_false(_service.can_undo())

func test_undo_does_nothing_when_empty() -> void:
	# Ne doit pas planter
	_service.undo()
	assert_false(_service.can_undo())


# --- redo ---

func test_redo_replays_command() -> void:
	var counter = [0]
	_service.push(CounterCommand.new(counter))
	_service.undo()
	assert_eq(counter[0], 0)
	_service.redo()
	assert_eq(counter[0], 1)

func test_redo_disables_can_redo_when_stack_empty() -> void:
	var counter = [0]
	_service.push(CounterCommand.new(counter))
	_service.undo()
	_service.redo()
	assert_false(_service.can_redo())

func test_redo_does_nothing_when_empty() -> void:
	_service.redo()
	assert_false(_service.can_redo())

func test_redo_reenables_can_undo() -> void:
	var counter = [0]
	_service.push(CounterCommand.new(counter))
	_service.undo()
	_service.redo()
	assert_true(_service.can_undo())


# --- Pile limitée à 50 ---

func test_undo_stack_limited_to_50() -> void:
	var counter = [0]
	for i in range(60):
		_service.push(CounterCommand.new(counter, "cmd_%d" % i))
	# La pile ne doit contenir que 50 entrées
	# Undo 50 fois doit fonctionner
	for i in range(50):
		assert_true(_service.can_undo(), "should be able to undo at step %d" % i)
		_service.undo()
	assert_false(_service.can_undo())

func test_oldest_command_dropped_when_limit_exceeded() -> void:
	var counter = [0]
	for i in range(60):
		_service.push(CounterCommand.new(counter, "cmd_%d" % i))
	# counter vaut 60 ; après 50 undos il doit valoir 10
	for i in range(50):
		_service.undo()
	assert_eq(counter[0], 10)


# --- clear ---

func test_clear_empties_undo_stack() -> void:
	var counter = [0]
	_service.push(CounterCommand.new(counter))
	_service.clear()
	assert_false(_service.can_undo())

func test_clear_empties_redo_stack() -> void:
	var counter = [0]
	_service.push(CounterCommand.new(counter))
	_service.undo()
	_service.clear()
	assert_false(_service.can_redo())


# --- Labels ---

func test_get_undo_label_returns_last_pushed_label() -> void:
	var counter = [0]
	_service.push(CounterCommand.new(counter, "Ajout chapitre"))
	assert_eq(_service.get_undo_label(), "Ajout chapitre")

func test_get_undo_label_empty_when_stack_empty() -> void:
	assert_eq(_service.get_undo_label(), "")

func test_get_redo_label_after_undo() -> void:
	var counter = [0]
	_service.push(CounterCommand.new(counter, "Suppression scène"))
	_service.undo()
	assert_eq(_service.get_redo_label(), "Suppression scène")

func test_get_redo_label_empty_when_stack_empty() -> void:
	assert_eq(_service.get_redo_label(), "")

func test_labels_stack_correctly() -> void:
	var counter = [0]
	_service.push(CounterCommand.new(counter, "Action A"))
	_service.push(CounterCommand.new(counter, "Action B"))
	assert_eq(_service.get_undo_label(), "Action B")
	_service.undo()
	assert_eq(_service.get_undo_label(), "Action A")
	assert_eq(_service.get_redo_label(), "Action B")


# --- BaseCommand interface ---

func test_base_command_has_execute() -> void:
	var cmd = BaseCommand.new()
	assert_true(cmd.has_method("execute"))

func test_base_command_has_undo() -> void:
	var cmd = BaseCommand.new()
	assert_true(cmd.has_method("undo"))

func test_base_command_has_get_label() -> void:
	var cmd = BaseCommand.new()
	assert_true(cmd.has_method("get_label"))

func test_base_command_get_label_returns_string() -> void:
	var cmd = BaseCommand.new()
	assert_true(cmd.get_label() is String)
