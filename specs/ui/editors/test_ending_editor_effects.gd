extends GutTest

const EndingEditorScene = preload("res://src/ui/editors/ending_editor.tscn")
const SequenceScript = preload("res://src/models/sequence.gd")
const EndingScript = preload("res://src/models/ending.gd")
const ConsequenceScript = preload("res://src/models/consequence.gd")
const ChoiceScript = preload("res://src/models/choice.gd")
const VariableEffectScript = preload("res://src/models/variable_effect.gd")

var _editor = null

func before_each():
	_editor = EndingEditorScene.instantiate()
	add_child(_editor)

func after_each():
	if _editor:
		_editor.queue_free()
		_editor = null

# --- Effets sur auto_redirect ---

func test_add_redirect_effect():
	var seq = _make_seq_with_redirect()
	_editor.load_sequence(seq)
	_editor.add_redirect_effect()
	assert_eq(seq.ending.auto_consequence.effects.size(), 1)

func test_remove_redirect_effect():
	var seq = _make_seq_with_redirect()
	var e = VariableEffectScript.new()
	e.variable = "score"
	e.operation = "set"
	e.value = "10"
	seq.ending.auto_consequence.effects.append(e)
	_editor.load_sequence(seq)
	_editor.remove_redirect_effect(0)
	assert_eq(seq.ending.auto_consequence.effects.size(), 0)

func test_update_redirect_effect_variable():
	var seq = _make_seq_with_redirect()
	var e = VariableEffectScript.new()
	e.variable = "old"
	e.operation = "set"
	e.value = "1"
	seq.ending.auto_consequence.effects.append(e)
	_editor.load_sequence(seq)
	_editor.update_redirect_effect(0, "variable", "new_var")
	assert_eq(seq.ending.auto_consequence.effects[0].variable, "new_var")

func test_update_redirect_effect_operation():
	var seq = _make_seq_with_redirect()
	var e = VariableEffectScript.new()
	e.variable = "x"
	e.operation = "set"
	e.value = "1"
	seq.ending.auto_consequence.effects.append(e)
	_editor.load_sequence(seq)
	_editor.update_redirect_effect(0, "operation", "increment")
	assert_eq(seq.ending.auto_consequence.effects[0].operation, "increment")

func test_update_redirect_effect_value():
	var seq = _make_seq_with_redirect()
	var e = VariableEffectScript.new()
	e.variable = "x"
	e.operation = "set"
	e.value = "old"
	seq.ending.auto_consequence.effects.append(e)
	_editor.load_sequence(seq)
	_editor.update_redirect_effect(0, "value", "new_val")
	assert_eq(seq.ending.auto_consequence.effects[0].value, "new_val")

# --- Effets sur choix ---

func test_add_choice_effect():
	var seq = _make_seq_with_choices()
	_editor.load_sequence(seq)
	_editor.add_choice_effect(0)
	assert_eq(seq.ending.choices[0].effects.size(), 1)

func test_remove_choice_effect():
	var seq = _make_seq_with_choices()
	var e = VariableEffectScript.new()
	e.variable = "score"
	e.operation = "increment"
	e.value = "5"
	seq.ending.choices[0].effects.append(e)
	_editor.load_sequence(seq)
	_editor.remove_choice_effect(0, 0)
	assert_eq(seq.ending.choices[0].effects.size(), 0)

func test_update_choice_effect():
	var seq = _make_seq_with_choices()
	var e = VariableEffectScript.new()
	e.variable = "x"
	e.operation = "set"
	e.value = "1"
	seq.ending.choices[0].effects.append(e)
	_editor.load_sequence(seq)
	_editor.update_choice_effect(0, 0, "variable", "y")
	assert_eq(seq.ending.choices[0].effects[0].variable, "y")

# --- Signal emitted ---

func test_signal_emitted_on_add_redirect_effect():
	var seq = _make_seq_with_redirect()
	_editor.load_sequence(seq)
	watch_signals(_editor)
	_editor.add_redirect_effect()
	assert_signal_emitted(_editor, "ending_changed")

func test_signal_emitted_on_add_choice_effect():
	var seq = _make_seq_with_choices()
	_editor.load_sequence(seq)
	watch_signals(_editor)
	_editor.add_choice_effect(0)
	assert_signal_emitted(_editor, "ending_changed")

# --- Variable names ---

func test_set_variable_names():
	var seq = _make_seq_with_redirect()
	_editor.load_sequence(seq)
	_editor.set_variable_names(["score", "hp", "level"])
	assert_eq(_editor.get_variable_names(), ["score", "hp", "level"])

# --- Helpers ---

func _make_seq_with_redirect():
	var seq = SequenceScript.new()
	seq.ending = EndingScript.new()
	seq.ending.type = "auto_redirect"
	seq.ending.auto_consequence = ConsequenceScript.new()
	seq.ending.auto_consequence.type = "redirect_sequence"
	seq.ending.auto_consequence.target = "uuid-1"
	return seq

func _make_seq_with_choices():
	var seq = SequenceScript.new()
	seq.ending = EndingScript.new()
	seq.ending.type = "choices"
	var choice = ChoiceScript.new()
	choice.text = "Go"
	choice.consequence = ConsequenceScript.new()
	choice.consequence.type = "redirect_sequence"
	choice.consequence.target = "uuid-1"
	seq.ending.choices.append(choice)
	return seq
