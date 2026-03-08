extends GutTest

const SequenceScript = preload("res://src/models/sequence.gd")
const AddDialogueCommand = preload("res://src/commands/add_dialogue_command.gd")


func test_execute_appends_dialogue():
	var seq = SequenceScript.new()
	var cmd = AddDialogueCommand.new(seq, "Alice", "Bonjour")
	cmd.execute()
	assert_eq(seq.dialogues.size(), 1)
	assert_eq(seq.dialogues[0].character, "Alice")
	assert_eq(seq.dialogues[0].text, "Bonjour")


func test_execute_inserts_at_index():
	var seq = SequenceScript.new()
	var cmd1 = AddDialogueCommand.new(seq, "Alice", "Premier")
	cmd1.execute()
	var cmd2 = AddDialogueCommand.new(seq, "Bob", "Inséré", 0)
	cmd2.execute()
	assert_eq(seq.dialogues.size(), 2)
	assert_eq(seq.dialogues[0].character, "Bob")
	assert_eq(seq.dialogues[1].character, "Alice")


func test_undo_removes_dialogue():
	var seq = SequenceScript.new()
	var cmd = AddDialogueCommand.new(seq, "Alice", "Bonjour")
	cmd.execute()
	cmd.undo()
	assert_eq(seq.dialogues.size(), 0)


func test_get_label():
	var seq = SequenceScript.new()
	var cmd = AddDialogueCommand.new(seq, "Alice", "Bonjour")
	assert_eq(cmd.get_label(), "Ajout dialogue")
