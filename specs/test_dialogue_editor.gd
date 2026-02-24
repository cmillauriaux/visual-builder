extends GutTest

# Tests pour l'éditeur de dialogues

const DialogueEditor = preload("res://src/ui/dialogue_editor.gd")
const Sequence = preload("res://src/models/sequence.gd")
const Dialogue = preload("res://src/models/dialogue.gd")

var _editor: Control = null
var _sequence = null

func before_each():
	_editor = Control.new()
	_editor.set_script(DialogueEditor)
	add_child_autofree(_editor)
	_sequence = Sequence.new()
	_sequence.seq_name = "Test"

func test_load_empty_sequence():
	_editor.load_sequence(_sequence)
	assert_eq(_editor.get_dialogue_count(), 0)

func test_add_dialogue():
	_editor.load_sequence(_sequence)
	_editor.add_dialogue("Héros", "Bonjour !")
	assert_eq(_sequence.dialogues.size(), 1)
	assert_eq(_sequence.dialogues[0].character, "Héros")
	assert_eq(_sequence.dialogues[0].text, "Bonjour !")

func test_modify_dialogue():
	_editor.load_sequence(_sequence)
	_editor.add_dialogue("Héros", "Ancien texte")
	_editor.modify_dialogue(0, "Narrateur", "Nouveau texte")
	assert_eq(_sequence.dialogues[0].character, "Narrateur")
	assert_eq(_sequence.dialogues[0].text, "Nouveau texte")

func test_remove_dialogue():
	_editor.load_sequence(_sequence)
	_editor.add_dialogue("A", "Texte A")
	_editor.add_dialogue("B", "Texte B")
	_editor.remove_dialogue(0)
	assert_eq(_sequence.dialogues.size(), 1)
	assert_eq(_sequence.dialogues[0].character, "B")

func test_reorder_dialogue():
	_editor.load_sequence(_sequence)
	_editor.add_dialogue("A", "Premier")
	_editor.add_dialogue("B", "Deuxième")
	_editor.add_dialogue("C", "Troisième")
	_editor.move_dialogue(2, 0)  # Déplace le 3e au début
	assert_eq(_sequence.dialogues[0].character, "C")
	assert_eq(_sequence.dialogues[1].character, "A")
	assert_eq(_sequence.dialogues[2].character, "B")

func test_dialogues_saved_in_order():
	_editor.load_sequence(_sequence)
	for i in range(5):
		_editor.add_dialogue("P%d" % i, "Texte %d" % i)
	for i in range(5):
		assert_eq(_sequence.dialogues[i].character, "P%d" % i)

func test_get_dialogue_count():
	_editor.load_sequence(_sequence)
	_editor.add_dialogue("A", "1")
	_editor.add_dialogue("B", "2")
	assert_eq(_editor.get_dialogue_count(), 2)
