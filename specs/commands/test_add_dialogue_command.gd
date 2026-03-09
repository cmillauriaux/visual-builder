extends GutTest

var SequenceScript
var AddDialogueCommandScript

func before_each():
	SequenceScript = load("res://src/models/sequence.gd")
	AddDialogueCommandScript = load("res://src/commands/add_dialogue_command.gd")

func test_execute_appends_dialogue():
	var seq = SequenceScript.new()
	var cmd = AddDialogueCommandScript.new(seq, "Hero", "Hello")
	cmd.execute()
	assert_eq(seq.dialogues.size(), 1)
	assert_eq(seq.dialogues[0].character, "Hero")

func test_execute_inserts_at_index():
	var seq = SequenceScript.new()
	var cmd1 = AddDialogueCommandScript.new(seq, "A", "1")
	cmd1.execute()
	var cmd2 = AddDialogueCommandScript.new(seq, "B", "2", 0)
	cmd2.execute()
	assert_eq(seq.dialogues.size(), 2)
	assert_eq(seq.dialogues[0].character, "B")

func test_undo_removes_dialogue():
	var seq = SequenceScript.new()
	var cmd = AddDialogueCommandScript.new(seq, "Hero", "Hello")
	cmd.execute()
	cmd.undo()
	assert_eq(seq.dialogues.size(), 0)

func test_get_label():
	var seq = SequenceScript.new()
	var cmd = AddDialogueCommandScript.new(seq, "A", "B")
	assert_eq(cmd.get_label(), "Ajout dialogue")
