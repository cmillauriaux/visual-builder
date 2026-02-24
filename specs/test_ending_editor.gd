extends GutTest

# Tests pour l'éditeur de terminaison

const EndingEditor = preload("res://src/ui/ending_editor.gd")
const Sequence = preload("res://src/models/sequence.gd")
const Ending = preload("res://src/models/ending.gd")
const Consequence = preload("res://src/models/consequence.gd")

var _editor: Control = null
var _sequence = null

func before_each():
	_editor = Control.new()
	_editor.set_script(EndingEditor)
	add_child_autofree(_editor)
	_sequence = Sequence.new()

func test_load_sequence_without_ending():
	_editor.load_sequence(_sequence)
	assert_eq(_editor.get_ending_type(), "")

func test_set_choices_mode():
	_editor.load_sequence(_sequence)
	_editor.set_ending_type("choices")
	assert_not_null(_sequence.ending)
	assert_eq(_sequence.ending.type, "choices")

func test_set_auto_redirect_mode():
	_editor.load_sequence(_sequence)
	_editor.set_ending_type("auto_redirect")
	assert_not_null(_sequence.ending)
	assert_eq(_sequence.ending.type, "auto_redirect")

func test_add_choice():
	_editor.load_sequence(_sequence)
	_editor.set_ending_type("choices")
	_editor.add_choice("Explorer", "redirect_sequence", "seq-002")
	assert_eq(_sequence.ending.choices.size(), 1)
	assert_eq(_sequence.ending.choices[0].text, "Explorer")
	assert_eq(_sequence.ending.choices[0].consequence.type, "redirect_sequence")
	assert_eq(_sequence.ending.choices[0].consequence.target, "seq-002")

func test_max_8_choices():
	_editor.load_sequence(_sequence)
	_editor.set_ending_type("choices")
	for i in range(8):
		_editor.add_choice("Choix %d" % i, "game_over", "")
	assert_eq(_sequence.ending.choices.size(), 8)
	# Le 9e ne doit pas être ajouté
	_editor.add_choice("Choix 9", "game_over", "")
	assert_eq(_sequence.ending.choices.size(), 8)

func test_remove_choice():
	_editor.load_sequence(_sequence)
	_editor.set_ending_type("choices")
	_editor.add_choice("A", "game_over", "")
	_editor.add_choice("B", "game_over", "")
	_editor.remove_choice(0)
	assert_eq(_sequence.ending.choices.size(), 1)
	assert_eq(_sequence.ending.choices[0].text, "B")

func test_set_auto_consequence():
	_editor.load_sequence(_sequence)
	_editor.set_ending_type("auto_redirect")
	_editor.set_auto_consequence("to_be_continued", "")
	assert_eq(_sequence.ending.auto_consequence.type, "to_be_continued")

func test_conditions_present_on_choices():
	_editor.load_sequence(_sequence)
	_editor.set_ending_type("choices")
	_editor.add_choice("Test", "game_over", "")
	assert_true(_sequence.ending.choices[0].conditions is Dictionary)
	assert_eq(_sequence.ending.choices[0].conditions, {})

func test_all_consequence_types():
	_editor.load_sequence(_sequence)
	_editor.set_ending_type("choices")
	var types = ["redirect_sequence", "redirect_scene", "redirect_chapter", "game_over", "to_be_continued"]
	for t in types:
		_editor.add_choice(t, t, "target-uuid" if t.begins_with("redirect") else "")
	assert_eq(_sequence.ending.choices.size(), 5)

func test_switch_mode_resets():
	_editor.load_sequence(_sequence)
	_editor.set_ending_type("choices")
	_editor.add_choice("Test", "game_over", "")
	_editor.set_ending_type("auto_redirect")
	assert_eq(_sequence.ending.type, "auto_redirect")
	assert_eq(_sequence.ending.choices.size(), 0)
