extends GutTest

var SequenceScript
var DialogueScript
var RemoveDialogueCommandScript

func before_each():
	SequenceScript = load("res://src/models/sequence.gd")
	DialogueScript = load("res://src/models/dialogue.gd")
	RemoveDialogueCommandScript = load("res://src/commands/remove_dialogue_command.gd")

func test_execute_removes_dialogue():
	var sequence = SequenceScript.new()
	var dialogue = DialogueScript.new()
	sequence.dialogues.append(dialogue)
	var cmd = RemoveDialogueCommandScript.new(sequence, 0)
	cmd.execute()
	assert_eq(sequence.dialogues.size(), 0)

func test_undo_restores_dialogue():
	var sequence = SequenceScript.new()
	var dialogue = DialogueScript.new()
	sequence.dialogues.append(dialogue)
	var cmd = RemoveDialogueCommandScript.new(sequence, 0)
	cmd.execute()
	cmd.undo()
	assert_eq(sequence.dialogues.size(), 1)

func test_get_label():
	var sequence = SequenceScript.new()
	var dialogue = DialogueScript.new()
	sequence.dialogues.append(dialogue)
	var cmd = RemoveDialogueCommandScript.new(sequence, 0)
	assert_eq(cmd.get_label(), "Suppression dialogue")
