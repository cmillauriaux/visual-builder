extends GutTest

var ConditionEditorScene = load("res://src/ui/editors/condition_editor.tscn")
var ConditionScript = load("res://src/models/condition.gd")
var ConditionRuleScript = load("res://src/models/condition_rule.gd")
var ConsequenceScript = load("res://src/models/consequence.gd")

var _editor = null
var _condition: Object

func before_each():
	_editor = ConditionEditorScene.instantiate()
	add_child(_editor)

	_condition = ConditionScript.new()
	_condition.condition_name = "Test Condition"

func after_each():
	if _editor:
		_editor.queue_free()
		_editor = null

func _make_targets() -> void:
	_editor.set_available_targets(
		[{"uuid": "s1", "name": "Seq1"}, {"uuid": "s2", "name": "Seq2"}],
		[{"uuid": "sc1", "name": "Scene1"}],
		[{"uuid": "ch1", "name": "Chapter1"}]
	)

# --- Chargement ---

func test_load_condition():
	_editor.load_condition(_condition)
	assert_eq(_editor.get_rule_count_ui(), 0)

func test_load_condition_null():
	_editor.load_condition(null)
	assert_eq(_editor.get_rule_count_ui(), 0)

# --- Règles ---

func test_add_rule():
	_editor.load_condition(_condition)
	_make_targets()
	_editor.add_rule()
	assert_eq(_condition.rules.size(), 1)
	assert_eq(_condition.rules[0].operator, "equal")
	assert_eq(_condition.rules[0].variable, "")

func test_rule_variable_is_per_rule():
	_editor.load_condition(_condition)
	_make_targets()
	_editor.add_rule()
	_editor.add_rule()
	_condition.rules[0].variable = "score"
	_condition.rules[1].variable = "health"
	assert_eq(_condition.rules[0].variable, "score")
	assert_eq(_condition.rules[1].variable, "health")

func test_add_multiple_rules():
	_editor.load_condition(_condition)
	_make_targets()
	_editor.add_rule()
	_editor.add_rule()
	_editor.add_rule()
	assert_eq(_condition.rules.size(), 3)

func test_remove_rule():
	_editor.load_condition(_condition)
	_make_targets()
	_editor.add_rule()
	_editor.add_rule()
	_editor.remove_rule(0)
	assert_eq(_condition.rules.size(), 1)

func test_remove_rule_invalid_index():
	_editor.load_condition(_condition)
	_editor.remove_rule(-1)
	_editor.remove_rule(99)
	assert_eq(_condition.rules.size(), 0, "Pas de crash, rules inchangées")

# --- Signal ---

func test_condition_changed_signal_on_add_rule():
	_editor.load_condition(_condition)
	_make_targets()
	watch_signals(_editor)
	_editor.add_rule()
	assert_signal_emitted(_editor, "condition_changed")

func test_condition_changed_signal_on_remove_rule():
	_editor.load_condition(_condition)
	_make_targets()
	_editor.add_rule()
	watch_signals(_editor)
	_editor.remove_rule(0)
	assert_signal_emitted(_editor, "condition_changed")

func test_condition_changed_signal_on_variable_change():
	_editor.load_condition(_condition)
	_make_targets()
	_editor.add_rule()
	watch_signals(_editor)
	# Simulate variable change on the rule via the handler
	_editor._on_rule_variable_changed("new_var", 0)
	assert_signal_emitted(_editor, "condition_changed")
	assert_eq(_condition.rules[0].variable, "new_var")

# --- Cibles disponibles ---

func test_set_available_targets():
	_editor.set_available_targets(
		[{"uuid": "s1", "name": "Seq1"}],
		[{"uuid": "sc1", "name": "Scene1"}],
		[{"uuid": "ch1", "name": "Chapter1"}]
	)
	assert_eq(_editor.get_available_sequences().size(), 1)
	assert_eq(_editor.get_available_scenes().size(), 1)
	assert_eq(_editor.get_available_chapters().size(), 1)

# --- Default consequence ---

func test_load_condition_creates_default_consequence():
	_make_targets()
	assert_null(_condition.default_consequence)
	_editor.load_condition(_condition)
	assert_not_null(_condition.default_consequence, "Le default_consequence doit être créé automatiquement au chargement")
	assert_eq(_condition.default_consequence.type, "redirect_sequence")
	assert_eq(_condition.default_consequence.target, "s1")

func test_load_condition_preserves_existing_default():
	var def_cons = ConsequenceScript.new()
	def_cons.type = "game_over"
	_condition.default_consequence = def_cons
	_make_targets()
	_editor.load_condition(_condition)
	assert_eq(_condition.default_consequence.type, "game_over", "Le type existant doit être conservé")

func test_set_default_consequence():
	_editor.load_condition(_condition)
	_make_targets()
	_editor.set_default_consequence("redirect_sequence", "s1")
	assert_not_null(_condition.default_consequence)
	assert_eq(_condition.default_consequence.type, "redirect_sequence")
	assert_eq(_condition.default_consequence.target, "s1")

func test_set_default_consequence_game_over():
	_editor.load_condition(_condition)
	_make_targets()
	_editor.set_default_consequence("game_over", "")
	assert_eq(_condition.default_consequence.type, "game_over")
	assert_eq(_condition.default_consequence.target, "")

# --- Chargement avec règles existantes ---

func test_load_condition_with_existing_rules():
	var rule = ConditionRuleScript.new()
	rule.variable = "score"
	rule.operator = "greater_than"
	rule.value = "50"
	var cons = ConsequenceScript.new()
	cons.type = "redirect_sequence"
	cons.target = "s1"
	rule.consequence = cons
	_condition.rules.append(rule)

	var def_cons = ConsequenceScript.new()
	def_cons.type = "game_over"
	_condition.default_consequence = def_cons

	_editor.load_condition(_condition)
	_make_targets()
	assert_eq(_condition.rules.size(), 1)
	assert_eq(_condition.rules[0].variable, "score")

# --- Opérateur exists masque la valeur ---

func test_operator_labels():
	# Use preload to access static constants if needed, or via the instance
	# Since it's a scene, we might need to access the script
	var script = _editor.get_script()
	assert_eq(script.OPERATOR_TYPES.size(), 8)
	assert_eq(script.OPERATOR_LABELS.size(), 8)

# === "Nouveau..." signal tests ===

func test_new_target_requested_signal_exists():
	assert_has_signal(_editor, "new_target_requested")

func test_default_nouveau_emits_new_target_requested():
	_make_targets()
	_editor.load_condition(_condition)
	watch_signals(_editor)
	# Select index 0 which is "Nouveau..." in the default target dropdown
	_editor._on_default_target_changed(0)
	assert_signal_emitted(_editor, "new_target_requested")

func test_default_nouveau_callback_updates_model():
	_make_targets()
	_editor.load_condition(_condition)
	var received = [{"ctype": ""}]
	_editor.new_target_requested.connect(func(ctype, callback):
		received[0]["ctype"] = ctype
		_editor.set_available_targets(
			[{"uuid": "s1", "name": "Seq1"}, {"uuid": "s2", "name": "Seq2"}, {"uuid": "new-uuid", "name": "Seq3"}],
			[{"uuid": "sc1", "name": "Scene1"}],
			[{"uuid": "ch1", "name": "Chapter1"}]
		)
		callback.call("new-uuid")
	)
	_editor._on_default_target_changed(0)
	assert_eq(received[0]["ctype"], "redirect_sequence")
	assert_eq(_condition.default_consequence.target, "new-uuid")

# --- Effects API tests ---

var VariableEffectScript = load("res://src/models/variable_effect.gd")

func test_add_rule_effect():
	_editor.load_condition(_condition)
	_make_targets()
	_editor.add_rule()
	_editor.add_rule_effect(0)
	var rule = _condition.rules[0]
	assert_eq(rule.consequence.effects.size(), 1)
	assert_eq(rule.consequence.effects[0].operation, "set")

func test_add_rule_effect_invalid_index():
	_editor.load_condition(_condition)
	_editor.add_rule_effect(99)
	assert_true(true, "No crash on invalid index")

func test_add_rule_effect_emits_signal():
	_editor.load_condition(_condition)
	_make_targets()
	_editor.add_rule()
	watch_signals(_editor)
	_editor.add_rule_effect(0)
	assert_signal_emitted(_editor, "condition_changed")

func test_remove_rule_effect():
	_editor.load_condition(_condition)
	_make_targets()
	_editor.add_rule()
	_editor.add_rule_effect(0)
	assert_eq(_condition.rules[0].consequence.effects.size(), 1)
	_editor.remove_rule_effect(0, 0)
	assert_eq(_condition.rules[0].consequence.effects.size(), 0)

func test_remove_rule_effect_invalid():
	_editor.load_condition(_condition)
	_make_targets()
	_editor.add_rule()
	_editor.remove_rule_effect(99, 0)
	_editor.remove_rule_effect(0, 99)
	assert_true(true, "No crash on invalid indices")

func test_update_rule_effect_variable():
	_editor.load_condition(_condition)
	_make_targets()
	_editor.add_rule()
	_editor.add_rule_effect(0)
	_editor.update_rule_effect(0, 0, "variable", "my_var")
	assert_eq(_condition.rules[0].consequence.effects[0].variable, "my_var")

func test_update_rule_effect_operation():
	_editor.load_condition(_condition)
	_make_targets()
	_editor.add_rule()
	_editor.add_rule_effect(0)
	_editor.update_rule_effect(0, 0, "operation", "add")
	assert_eq(_condition.rules[0].consequence.effects[0].operation, "add")

func test_update_rule_effect_value():
	_editor.load_condition(_condition)
	_make_targets()
	_editor.add_rule()
	_editor.add_rule_effect(0)
	_editor.update_rule_effect(0, 0, "value", "42")
	assert_eq(_condition.rules[0].consequence.effects[0].value, "42")

func test_update_rule_effect_invalid():
	_editor.load_condition(_condition)
	_make_targets()
	_editor.add_rule()
	_editor.update_rule_effect(99, 0, "variable", "x")
	_editor.update_rule_effect(0, 99, "variable", "x")
	assert_true(true, "No crash on invalid indices")

func test_add_default_effect():
	_editor.load_condition(_condition)
	_make_targets()
	_condition.default_consequence = ConsequenceScript.new()
	_editor.add_default_effect()
	assert_eq(_condition.default_consequence.effects.size(), 1)
	assert_eq(_condition.default_consequence.effects[0].operation, "set")

func test_add_default_effect_creates_consequence():
	_editor.load_condition(_condition)
	_make_targets()
	_condition.default_consequence = null
	_editor.add_default_effect()
	assert_not_null(_condition.default_consequence)
	assert_eq(_condition.default_consequence.effects.size(), 1)

func test_remove_default_effect():
	_editor.load_condition(_condition)
	_make_targets()
	_condition.default_consequence = ConsequenceScript.new()
	_editor.add_default_effect()
	assert_eq(_condition.default_consequence.effects.size(), 1)
	_editor.remove_default_effect(0)
	assert_eq(_condition.default_consequence.effects.size(), 0)

func test_remove_default_effect_invalid():
	_editor.load_condition(_condition)
	_make_targets()
	_editor.remove_default_effect(99)
	assert_true(true, "No crash on invalid index")

func test_update_default_effect_variable():
	_editor.load_condition(_condition)
	_make_targets()
	_condition.default_consequence = ConsequenceScript.new()
	_editor.add_default_effect()
	_editor.update_default_effect(0, "variable", "hp")
	assert_eq(_condition.default_consequence.effects[0].variable, "hp")

func test_update_default_effect_operation():
	_editor.load_condition(_condition)
	_make_targets()
	_condition.default_consequence = ConsequenceScript.new()
	_editor.add_default_effect()
	_editor.update_default_effect(0, "operation", "subtract")
	assert_eq(_condition.default_consequence.effects[0].operation, "subtract")

func test_update_default_effect_value():
	_editor.load_condition(_condition)
	_make_targets()
	_condition.default_consequence = ConsequenceScript.new()
	_editor.add_default_effect()
	_editor.update_default_effect(0, "value", "100")
	assert_eq(_condition.default_consequence.effects[0].value, "100")

func test_get_available_conditions():
	var conditions = [{"uuid": "c1", "name": "Cond1"}, {"uuid": "c2", "name": "Cond2"}]
	_editor.set_available_targets(
		[{"uuid": "s1", "name": "Seq1"}],
		[{"uuid": "sc1", "name": "Scene1"}],
		[{"uuid": "ch1", "name": "Chapter1"}],
		conditions
	)
	var result = _editor.get_available_conditions()
	assert_eq(result.size(), 2)
	assert_eq(result[0]["uuid"], "c1")
	assert_eq(result[1]["name"], "Cond2")
