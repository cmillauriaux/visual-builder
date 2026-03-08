extends GutTest

const DialogueScript = preload("res://src/models/dialogue.gd")
const EditDialogueCommand = preload("res://src/commands/edit_dialogue_command.gd")


func test_execute_changes_character_and_text():
	var dlg = DialogueScript.new()
	dlg.character = "Alice"
	dlg.text = "Ancien"
	var cmd = EditDialogueCommand.new(dlg, "Bob", "Nouveau", "Alice", "Ancien")
	cmd.execute()
	assert_eq(dlg.character, "Bob")
	assert_eq(dlg.text, "Nouveau")


func test_undo_restores_character_and_text():
	var dlg = DialogueScript.new()
	dlg.character = "Alice"
	dlg.text = "Ancien"
	var cmd = EditDialogueCommand.new(dlg, "Bob", "Nouveau", "Alice", "Ancien")
	cmd.execute()
	cmd.undo()
	assert_eq(dlg.character, "Alice")
	assert_eq(dlg.text, "Ancien")


func test_get_label():
	var dlg = DialogueScript.new()
	var cmd = EditDialogueCommand.new(dlg, "B", "N", "A", "O")
	assert_eq(cmd.get_label(), "Modification dialogue")
