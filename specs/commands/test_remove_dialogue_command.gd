extends GutTest

const SequenceScript = preload("res://src/models/sequence.gd")
const DialogueScript = preload("res://src/models/dialogue.gd")
const RemoveDialogueCommand = preload("res://src/commands/remove_dialogue_command.gd")


func test_execute_removes_dialogue_at_index():
	var seq = SequenceScript.new()
	var d1 = DialogueScript.new()
	d1.character = "Alice"
	var d2 = DialogueScript.new()
	d2.character = "Bob"
	seq.dialogues = [d1, d2]
	var cmd = RemoveDialogueCommand.new(seq, 0)
	cmd.execute()
	assert_eq(seq.dialogues.size(), 1)
	assert_eq(seq.dialogues[0].character, "Bob")


func test_undo_restores_dialogue_at_index():
	var seq = SequenceScript.new()
	var d1 = DialogueScript.new()
	d1.character = "Alice"
	var d2 = DialogueScript.new()
	d2.character = "Bob"
	seq.dialogues = [d1, d2]
	var cmd = RemoveDialogueCommand.new(seq, 0)
	cmd.execute()
	cmd.undo()
	assert_eq(seq.dialogues.size(), 2)
	assert_eq(seq.dialogues[0].character, "Alice")


func test_get_label():
	var seq = SequenceScript.new()
	var d = DialogueScript.new()
	seq.dialogues = [d]
	var cmd = RemoveDialogueCommand.new(seq, 0)
	assert_eq(cmd.get_label(), "Suppression dialogue")
