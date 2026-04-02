# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends VBoxContainer

## Éditeur de condition — UI complète pour configurer les règles et le default.

class_name ConditionEditor

const ConditionRuleScript = preload("res://src/models/condition_rule.gd")
const ConsequenceScript = preload("res://src/models/consequence.gd")
const VariableEffectScript = preload("res://src/models/variable_effect.gd")
const ConsequenceTargetHelperScript = preload("res://src/ui/shared/consequence_target_helper.gd")
const EffectRowBuilderScript = preload("res://src/ui/shared/effect_row_builder.gd")
const EditorState = preload("res://src/controllers/editor_state.gd")

signal condition_changed
signal new_target_requested(ctype: String, callback: Callable)

const OPERATOR_TYPES = ["equal", "not_equal", "greater_than", "greater_than_equal", "less_than", "less_than_equal", "exists", "not_exists"]
const OPERATOR_LABELS = ["Equal", "Not Equal", "Greater Than", "Greater Than Equal", "Less Than", "Less Than Equal", "Exists", "Not Exists"]

var CONSEQUENCE_TYPES: Array:
	get: return ConsequenceTargetHelperScript.CONSEQUENCE_TYPES
var CONSEQUENCE_LABELS: Array:
	get: return ConsequenceTargetHelperScript.CONSEQUENCE_LABELS
var REDIRECT_TYPES: Array:
	get: return ConsequenceTargetHelperScript.REDIRECT_TYPES

var _condition = null
var _target_helper = ConsequenceTargetHelperScript.new()

# UI references
@onready var _rules_list: VBoxContainer = %RulesList
@onready var _add_rule_btn: Button = %AddRuleBtn
@onready var _default_container: VBoxContainer = %DefaultContainer
@onready var _default_type_dropdown: OptionButton = %DefaultTypeDropdown
@onready var _default_target_dropdown: OptionButton = %DefaultTargetDropdown
@onready var _default_effects_list: VBoxContainer = %DefaultEffectsList
@onready var _add_default_effect_btn: Button = %AddDefaultEffectBtn

func _ready() -> void:
	# Initialiser les dropdowns statiques
	_default_type_dropdown.clear()
	for label in CONSEQUENCE_LABELS:
		_default_type_dropdown.add_item(label)
	
	# Connecter les signaux
	_add_rule_btn.pressed.connect(_on_add_rule_pressed)
	_default_type_dropdown.item_selected.connect(_on_default_type_changed)
	_default_target_dropdown.item_selected.connect(_on_default_target_changed)
	_add_default_effect_btn.pressed.connect(_on_add_default_effect_pressed)

	EventBus.story_loaded.connect(_on_story_loaded)
	EventBus.story_modified.connect(_on_story_modified)
	EventBus.targets_updated.connect(set_available_targets)


func _on_story_loaded(story: StoryModel) -> void:
	set_variable_names(story.get_variable_names())


func _on_story_modified() -> void:
	# Note: On ne peut pas récupérer la story ici facilement sans référence
	# Mais NavigationController appelle set_variable_names s'il a la main.
	# L'idéal serait d'avoir la story dans l'EventBus.story_modified(story)
	pass

# --- Public API ---

func load_condition(condition) -> void:
	_condition = condition
	_refresh_ui()

func add_rule() -> void:
	if _condition == null:
		return
	var rule = ConditionRuleScript.new()
	rule.variable = ""
	rule.operator = "equal"
	rule.value = ""
	var cons = ConsequenceScript.new()
	cons.type = "redirect_sequence"
	# Set first available target if any
	if _target_helper.available_sequences.size() > 0:
		cons.target = _target_helper.available_sequences[0]["uuid"]
	rule.consequence = cons
	_condition.rules.append(rule)
	_rebuild_rules_list()
	condition_changed.emit()

func remove_rule(index: int) -> void:
	if _condition == null:
		return
	if index < 0 or index >= _condition.rules.size():
		return
	_condition.rules.remove_at(index)
	_rebuild_rules_list()
	condition_changed.emit()

func set_default_consequence(type: String, target: String) -> void:
	if _condition == null:
		return
	var cons = ConsequenceScript.new()
	cons.type = type
	cons.target = target
	_condition.default_consequence = cons
	condition_changed.emit()

func get_rule_count_ui() -> int:
	if _condition == null:
		return 0
	return _condition.rules.size()

func set_available_targets(sequences: Array, scenes: Array, chapters: Array, conditions: Array = []) -> void:
	_target_helper.set_available_targets(sequences, scenes, chapters, conditions)
	if _condition:
		_rebuild_rules_list()
		_refresh_default_ui()

func get_available_sequences() -> Array:
	return _target_helper.available_sequences

func get_available_conditions() -> Array:
	return _target_helper.available_conditions

func get_available_scenes() -> Array:
	return _target_helper.available_scenes

func get_available_chapters() -> Array:
	return _target_helper.available_chapters

func set_variable_names(names: Array) -> void:
	_target_helper.variable_names = names
	_rebuild_rules_list()

func get_variable_names() -> Array:
	return _target_helper.variable_names

# --- Effects API ---

func add_rule_effect(rule_index: int) -> void:
	if _condition == null or rule_index >= _condition.rules.size():
		return
	var rule = _condition.rules[rule_index]
	if rule.consequence == null:
		rule.consequence = ConsequenceScript.new()
	var e = VariableEffectScript.new()
	e.operation = "set"
	rule.consequence.effects.append(e)
	_rebuild_rules_list()
	condition_changed.emit()

func remove_rule_effect(rule_index: int, effect_index: int) -> void:
	if _condition == null or rule_index >= _condition.rules.size():
		return
	var rule = _condition.rules[rule_index]
	if rule.consequence == null or effect_index >= rule.consequence.effects.size():
		return
	rule.consequence.effects.remove_at(effect_index)
	_rebuild_rules_list()
	condition_changed.emit()

func update_rule_effect(rule_index: int, effect_index: int, field: String, value: String) -> void:
	if _condition == null or rule_index >= _condition.rules.size():
		return
	var rule = _condition.rules[rule_index]
	if rule.consequence == null or effect_index >= rule.consequence.effects.size():
		return
	var e = rule.consequence.effects[effect_index]
	match field:
		"variable":
			e.variable = value
		"operation":
			e.operation = value
		"value":
			e.value = value
	condition_changed.emit()

func add_default_effect() -> void:
	if _condition == null:
		return
	if _condition.default_consequence == null:
		_condition.default_consequence = ConsequenceScript.new()
	var e = VariableEffectScript.new()
	e.operation = "set"
	_condition.default_consequence.effects.append(e)
	_refresh_default_ui()
	condition_changed.emit()

func remove_default_effect(effect_index: int) -> void:
	if _condition == null or _condition.default_consequence == null:
		return
	if effect_index >= _condition.default_consequence.effects.size():
		return
	_condition.default_consequence.effects.remove_at(effect_index)
	_refresh_default_ui()
	condition_changed.emit()

func update_default_effect(effect_index: int, field: String, value: String) -> void:
	if _condition == null or _condition.default_consequence == null:
		return
	if effect_index >= _condition.default_consequence.effects.size():
		return
	var e = _condition.default_consequence.effects[effect_index]
	match field:
		"variable":
			e.variable = value
		"operation":
			e.operation = value
		"value":
			e.value = value
	condition_changed.emit()

# --- Private ---

func _on_add_rule_pressed() -> void:
	add_rule()

func _refresh_ui() -> void:
	_rebuild_rules_list()
	_refresh_default_ui()

func _rebuild_rules_list() -> void:
	if _rules_list == null:
		return
	for child in _rules_list.get_children():
		child.queue_free()
	if _condition == null:
		return
	for i in range(_condition.rules.size()):
		var row = _create_rule_row(i, _condition.rules[i])
		_rules_list.add_child(row)

func _create_rule_row(index: int, rule) -> VBoxContainer:
	var container = VBoxContainer.new()

	# Header row: label + delete
	var header = HBoxContainer.new()
	container.add_child(header)

	var label = Label.new()
	label.text = tr("Règle %d") % (index + 1)
	header.add_child(label)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var delete_btn = Button.new()
	delete_btn.text = "×"
	delete_btn.pressed.connect(_on_delete_rule.bind(index))
	header.add_child(delete_btn)

	# Variable row
	var var_row = HBoxContainer.new()
	container.add_child(var_row)

	var var_label = Label.new()
	var_label.text = tr("Variable :")
	var_row.add_child(var_label)

	var var_edit = LineEdit.new()
	var_edit.text = rule.variable
	var_edit.placeholder_text = tr("Nom de la variable...")
	var_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var_edit.name = "VariableEdit"
	var_edit.tooltip_text = tr("Variables disponibles : ") + ", ".join(_target_helper.variable_names) if _target_helper.variable_names.size() > 0 else ""
	var_edit.text_changed.connect(_on_rule_variable_changed.bind(index))
	var_row.add_child(var_edit)

	# Operator + value row
	var op_row = HBoxContainer.new()
	container.add_child(op_row)

	var op_dropdown = OptionButton.new()
	for lbl in OPERATOR_LABELS:
		op_dropdown.add_item(lbl)
	var op_idx = OPERATOR_TYPES.find(rule.operator)
	if op_idx < 0:
		op_idx = 0
	op_dropdown.selected = op_idx
	op_dropdown.item_selected.connect(_on_rule_operator_changed.bind(index))
	op_row.add_child(op_dropdown)

	var value_edit = LineEdit.new()
	value_edit.text = rule.value
	value_edit.placeholder_text = tr("Valeur...")
	value_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_edit.name = "ValueEdit"
	# Masquer si exists/not_exists
	value_edit.visible = rule.operator not in ["exists", "not_exists"]
	value_edit.text_changed.connect(_on_rule_value_changed.bind(index))
	op_row.add_child(value_edit)

	# Consequence row
	var cons_row = HBoxContainer.new()
	container.add_child(cons_row)

	var cons_label = Label.new()
	cons_label.text = "→"
	cons_row.add_child(cons_label)

	var type_dropdown = OptionButton.new()
	for lbl in CONSEQUENCE_LABELS:
		type_dropdown.add_item(lbl)
	var type_idx = CONSEQUENCE_TYPES.find(rule.consequence.type) if rule.consequence else 0
	if type_idx < 0:
		type_idx = 0
	type_dropdown.selected = type_idx
	type_dropdown.item_selected.connect(_on_rule_cons_type_changed.bind(index))
	cons_row.add_child(type_dropdown)

	var target_dropdown = OptionButton.new()
	target_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ctype = CONSEQUENCE_TYPES[type_idx]
	_populate_target_dropdown(target_dropdown, ctype)
	target_dropdown.visible = ctype in REDIRECT_TYPES
	# Select current target
	if rule.consequence and rule.consequence.target != "":
		for t in range(target_dropdown.item_count):
			if target_dropdown.get_item_metadata(t) == rule.consequence.target:
				target_dropdown.selected = t
				break
	target_dropdown.item_selected.connect(_on_rule_cons_target_changed.bind(index))
	cons_row.add_child(target_dropdown)

	# Effects section for this rule
	var effects_label = Label.new()
	effects_label.text = tr("Effets sur les variables :")
	container.add_child(effects_label)

	var effects_list = VBoxContainer.new()
	effects_list.name = "EffectsList"
	container.add_child(effects_list)
	if rule.consequence:
		for ei in range(rule.consequence.effects.size()):
			var effect_row = _create_effect_row(rule.consequence.effects[ei], "rule", index, ei)
			effects_list.add_child(effect_row)

	var add_effect_btn = Button.new()
	add_effect_btn.text = tr("+ Ajouter un effet")
	add_effect_btn.pressed.connect(func(): add_rule_effect(index))
	container.add_child(add_effect_btn)

	# Separator
	container.add_child(HSeparator.new())

	return container

func _create_effect_row(effect, context: String, rule_index: int, effect_index: int) -> HBoxContainer:
	if context == "rule":
		return EffectRowBuilderScript.create_effect_row(
			effect, _target_helper.variable_names,
			func(t): update_rule_effect(rule_index, effect_index, "variable", t),
			func(op): update_rule_effect(rule_index, effect_index, "operation", op); _rebuild_rules_list(),
			func(t): update_rule_effect(rule_index, effect_index, "value", t),
			func(): remove_rule_effect(rule_index, effect_index)
		)
	else:
		return EffectRowBuilderScript.create_effect_row(
			effect, _target_helper.variable_names,
			func(t): update_default_effect(effect_index, "variable", t),
			func(op): update_default_effect(effect_index, "operation", op); _refresh_default_ui(),
			func(t): update_default_effect(effect_index, "value", t),
			func(): remove_default_effect(effect_index)
		)

func _on_delete_rule(index: int) -> void:
	remove_rule(index)

func _on_rule_variable_changed(new_text: String, rule_index: int) -> void:
	if _condition == null or rule_index >= _condition.rules.size():
		return
	_condition.rules[rule_index].variable = new_text
	condition_changed.emit()

func _on_rule_operator_changed(op_index: int, rule_index: int) -> void:
	if _condition == null or rule_index >= _condition.rules.size():
		return
	_condition.rules[rule_index].operator = OPERATOR_TYPES[op_index]
	_rebuild_rules_list()
	condition_changed.emit()

func _on_rule_value_changed(new_text: String, rule_index: int) -> void:
	if _condition == null or rule_index >= _condition.rules.size():
		return
	_condition.rules[rule_index].value = new_text
	condition_changed.emit()

func _on_rule_cons_type_changed(type_index: int, rule_index: int) -> void:
	if _condition == null or rule_index >= _condition.rules.size():
		return
	var rule = _condition.rules[rule_index]
	var ctype = CONSEQUENCE_TYPES[type_index]
	if rule.consequence == null:
		rule.consequence = ConsequenceScript.new()
	rule.consequence.type = ctype
	if ctype not in REDIRECT_TYPES:
		rule.consequence.target = ""
	else:
		var items = _get_targets_for_type(ctype)
		rule.consequence.target = items[0]["uuid"] if items.size() > 0 else ""
	_rebuild_rules_list()
	condition_changed.emit()

func _on_rule_cons_target_changed(target_index: int, rule_index: int) -> void:
	if _condition == null or rule_index >= _condition.rules.size():
		return
	var rule = _condition.rules[rule_index]
	if rule.consequence == null:
		return
	# Find the target dropdown in the rule row
	var rule_row = _rules_list.get_child(rule_index)
	var target_dropdown = _find_target_dropdown_in_rule(rule_row)
	if target_dropdown and target_index >= 0 and target_index < target_dropdown.item_count:
		var meta = target_dropdown.get_item_metadata(target_index)
		if ConsequenceTargetHelperScript.is_new_target_meta(meta):
			var ctype = rule.consequence.type
			new_target_requested.emit(ctype, func(new_uuid: String) -> void:
				rule.consequence.target = new_uuid
				_rebuild_rules_list()
				condition_changed.emit()
			)
			return
		rule.consequence.target = meta
	condition_changed.emit()

# --- Default consequence ---

func _refresh_default_ui() -> void:
	if _default_type_dropdown == null:
		return
	if _condition == null:
		_default_type_dropdown.selected = 0
		_populate_target_dropdown(_default_target_dropdown, CONSEQUENCE_TYPES[0])
		_default_target_dropdown.visible = true
		return
	if _condition.default_consequence == null:
		var ctype = CONSEQUENCE_TYPES[0]
		var target = ""
		if ctype in REDIRECT_TYPES:
			var items = _get_targets_for_type(ctype)
			target = items[0]["uuid"] if items.size() > 0 else ""
		var cons = ConsequenceScript.new()
		cons.type = ctype
		cons.target = target
		_condition.default_consequence = cons
		_default_type_dropdown.selected = 0
		_populate_target_dropdown(_default_target_dropdown, ctype)
		_default_target_dropdown.visible = ctype in REDIRECT_TYPES
		if ctype in REDIRECT_TYPES:
			var first_real = _find_first_real_target_index(_default_target_dropdown)
			if first_real >= 0:
				_default_target_dropdown.selected = first_real
		return
	var idx = CONSEQUENCE_TYPES.find(_condition.default_consequence.type)
	if idx < 0:
		idx = 0
	_default_type_dropdown.selected = idx
	var ctype = CONSEQUENCE_TYPES[idx]
	_populate_target_dropdown(_default_target_dropdown, ctype)
	_default_target_dropdown.visible = ctype in REDIRECT_TYPES
	if ctype in REDIRECT_TYPES and _condition.default_consequence.target != "":
		for t in range(_default_target_dropdown.item_count):
			if _default_target_dropdown.get_item_metadata(t) == _condition.default_consequence.target:
				_default_target_dropdown.selected = t
				break
	
	_rebuild_default_effects()

func _rebuild_default_effects() -> void:
	if _default_effects_list == null:
		return
	for child in _default_effects_list.get_children():
		child.queue_free()
	if _condition == null or _condition.default_consequence == null:
		return
	for i in range(_condition.default_consequence.effects.size()):
		var row = _create_effect_row(_condition.default_consequence.effects[i], "default", -1, i)
		_default_effects_list.add_child(row)

func _on_add_default_effect_pressed() -> void:
	add_default_effect()

func _on_default_type_changed(type_index: int) -> void:
	if _condition == null:
		return
	var ctype = CONSEQUENCE_TYPES[type_index]
	_populate_target_dropdown(_default_target_dropdown, ctype)
	_default_target_dropdown.visible = ctype in REDIRECT_TYPES
	var target = ""
	if ctype in REDIRECT_TYPES:
		var items = _get_targets_for_type(ctype)
		target = items[0]["uuid"] if items.size() > 0 else ""
		var first_real = _find_first_real_target_index(_default_target_dropdown)
		if first_real >= 0:
			_default_target_dropdown.selected = first_real
	set_default_consequence(ctype, target)

func _on_default_target_changed(target_index: int) -> void:
	if _condition == null:
		return
	if _condition.default_consequence == null:
		var ctype = CONSEQUENCE_TYPES[_default_type_dropdown.selected]
		var cons = ConsequenceScript.new()
		cons.type = ctype
		_condition.default_consequence = cons
	if target_index >= 0 and target_index < _default_target_dropdown.item_count:
		var meta = _default_target_dropdown.get_item_metadata(target_index)
		if ConsequenceTargetHelperScript.is_new_target_meta(meta):
			var ctype = _condition.default_consequence.type
			new_target_requested.emit(ctype, func(new_uuid: String) -> void:
				_condition.default_consequence.target = new_uuid
				_refresh_default_ui()
				condition_changed.emit()
			)
			return
		_condition.default_consequence.target = meta
	condition_changed.emit()

# --- Target dropdowns ---

func _populate_target_dropdown(dropdown: OptionButton, ctype: String) -> void:
	_target_helper.populate_target_dropdown(dropdown, ctype)

func _get_targets_for_type(ctype: String) -> Array:
	return _target_helper.get_targets_for_type(ctype)

func _find_target_dropdown_in_rule(rule_row) -> OptionButton:
	if rule_row == null:
		return null
	for child in rule_row.get_children():
		if child is HBoxContainer:
			for sub in child.get_children():
				if sub is OptionButton and sub.size_flags_horizontal == Control.SIZE_EXPAND_FILL:
					return sub
	return null

func _find_first_real_target_index(dropdown: OptionButton) -> int:
	for i in range(dropdown.item_count):
		if not ConsequenceTargetHelperScript.is_new_target_meta(dropdown.get_item_metadata(i)):
			return i
	return -1