extends GutTest

const RenameNodeCommand = preload("res://src/commands/rename_node_command.gd")

var _name: String
var _subtitle: String


func _set_name_subtitle(n: String, s: String) -> void:
	_name = n
	_subtitle = s


func _get_name_subtitle() -> Array:
	return [_name, _subtitle]


func test_execute_sets_new_name_and_subtitle():
	_name = "Ancien"
	_subtitle = "Sous-ancien"
	var cmd = RenameNodeCommand.new(
		_set_name_subtitle, _get_name_subtitle,
		"Nouveau", "Sous-nouveau", "Ancien", "Sous-ancien", "chapitre"
	)
	cmd.execute()
	assert_eq(_name, "Nouveau")
	assert_eq(_subtitle, "Sous-nouveau")


func test_undo_restores_old_name_and_subtitle():
	_name = "Ancien"
	_subtitle = "Sous-ancien"
	var cmd = RenameNodeCommand.new(
		_set_name_subtitle, _get_name_subtitle,
		"Nouveau", "Sous-nouveau", "Ancien", "Sous-ancien", "chapitre"
	)
	cmd.execute()
	cmd.undo()
	assert_eq(_name, "Ancien")
	assert_eq(_subtitle, "Sous-ancien")


func test_get_label():
	var cmd = RenameNodeCommand.new(
		_set_name_subtitle, _get_name_subtitle,
		"Nouveau", "", "Ancien", "", "scène"
	)
	assert_string_contains(cmd.get_label(), "Nouveau")
	assert_string_contains(cmd.get_label(), "scène")
