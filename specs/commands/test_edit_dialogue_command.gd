extends GutTest

var DialogueScript
var EditDialogueCommandScript

func before_each():
	DialogueScript = load("res://src/models/dialogue.gd")
	EditDialogueCommandScript = load("res://src/commands/edit_dialogue_command.gd")

func test_execute_edits():
	var dialogue = DialogueScript.new()
	var cmd = EditDialogueCommandScript.new(dialogue, "NewH", "NewT", "OldH", "OldT")
	cmd.execute()
	assert_eq(dialogue.character, "NewH")

func test_undo_restores():
	var dialogue = DialogueScript.new()
	var cmd = EditDialogueCommandScript.new(dialogue, "NewH", "NewT", "OldH", "OldT")
	cmd.execute()
	cmd.undo()
	assert_eq(dialogue.character, "OldH")
