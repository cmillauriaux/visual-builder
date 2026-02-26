extends VBoxContainer

## Éditeur de condition — UI complète pour configurer les règles et le default.

const ConditionRuleScript = preload("res://src/models/condition_rule.gd")
const ConsequenceScript = preload("res://src/models/consequence.gd")

signal condition_changed

const OPERATOR_TYPES = ["equal", "not_equal", "greater_than", "greater_than_equal", "less_than", "less_than_equal", "exists", "not_exists"]
const OPERATOR_LABELS = ["Equal", "Not Equal", "Greater Than", "Greater Than Equal", "Less Than", "Less Than Equal", "Exists", "Not Exists"]
const CONSEQUENCE_TYPES = ["redirect_sequence", "redirect_condition", "redirect_scene", "redirect_chapter", "game_over", "to_be_continued"]
const CONSEQUENCE_LABELS = ["Séquence", "Condition", "Scène", "Chapitre", "Game Over", "To be continued"]
const REDIRECT_TYPES = ["redirect_sequence", "redirect_condition", "redirect_scene", "redirect_chapter"]

var _condition = null
var _available_sequences: Array = []
var _available_conditions: Array = []
var _available_scenes: Array = []
var _available_chapters: Array = []
var _variable_names: Array = []

# UI references
var _rules_list: VBoxContainer
var _add_rule_btn: Button
var _default_container: VBoxContainer
var _default_type_dropdown: OptionButton
var _default_target_dropdown: OptionButton

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# Rules section
	var rules_label = Label.new()
	rules_label.text = "— Règles —"
	rules_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(rules_label)

	var rules_scroll = ScrollContainer.new()
	rules_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rules_scroll.custom_minimum_size.y = 150
	add_child(rules_scroll)

	_rules_list = VBoxContainer.new()
	_rules_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rules_scroll.add_child(_rules_list)

	_add_rule_btn = Button.new()
	_add_rule_btn.text = "+ Ajouter une règle"
	_add_rule_btn.pressed.connect(_on_add_rule_pressed)
	add_child(_add_rule_btn)

	# Default section
	add_child(HSeparator.new())

	var default_label = Label.new()
	default_label.text = "— Default —"
	default_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(default_label)

	_default_container = VBoxContainer.new()
	add_child(_default_container)

	var default_row = HBoxContainer.new()
	_default_container.add_child(default_row)

	_default_type_dropdown = OptionButton.new()
	for label in CONSEQUENCE_LABELS:
		_default_type_dropdown.add_item(label)
	_default_type_dropdown.item_selected.connect(_on_default_type_changed)
	default_row.add_child(_default_type_dropdown)

	_default_target_dropdown = OptionButton.new()
	_default_target_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_default_target_dropdown.item_selected.connect(_on_default_target_changed)
	default_row.add_child(_default_target_dropdown)

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
	if _available_sequences.size() > 0:
		cons.target = _available_sequences[0]["uuid"]
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
	_available_sequences = sequences
	_available_conditions = conditions
	_available_scenes = scenes
	_available_chapters = chapters
	if _condition:
		_rebuild_rules_list()
		_refresh_default_ui()

func get_available_sequences() -> Array:
	return _available_sequences

func get_available_conditions() -> Array:
	return _available_conditions

func get_available_scenes() -> Array:
	return _available_scenes

func get_available_chapters() -> Array:
	return _available_chapters

func set_variable_names(names: Array) -> void:
	_variable_names = names
	_rebuild_rules_list()

func get_variable_names() -> Array:
	return _variable_names

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
	label.text = "Règle %d" % (index + 1)
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
	var_label.text = "Variable :"
	var_row.add_child(var_label)

	var var_edit = LineEdit.new()
	var_edit.text = rule.variable
	var_edit.placeholder_text = "Nom de la variable..."
	var_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var_edit.name = "VariableEdit"
	var_edit.tooltip_text = "Variables disponibles : " + ", ".join(_variable_names) if _variable_names.size() > 0 else ""
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
	value_edit.placeholder_text = "Valeur..."
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

	# Separator
	container.add_child(HSeparator.new())

	return container

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
	var items = _get_targets_for_type(rule.consequence.type)
	if target_index >= 0 and target_index < items.size():
		rule.consequence.target = items[target_index]["uuid"]
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
		# Créer le default_consequence avec le type par défaut
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
	set_default_consequence(ctype, target)

func _on_default_target_changed(target_index: int) -> void:
	if _condition == null:
		return
	if _condition.default_consequence == null:
		var ctype = CONSEQUENCE_TYPES[_default_type_dropdown.selected]
		var cons = ConsequenceScript.new()
		cons.type = ctype
		_condition.default_consequence = cons
	var items = _get_targets_for_type(_condition.default_consequence.type)
	if target_index >= 0 and target_index < items.size():
		_condition.default_consequence.target = items[target_index]["uuid"]
	condition_changed.emit()

# --- Target dropdowns ---

func _populate_target_dropdown(dropdown: OptionButton, ctype: String) -> void:
	dropdown.clear()
	var items = _get_targets_for_type(ctype)
	for item in items:
		dropdown.add_item(item["name"])
		dropdown.set_item_metadata(dropdown.item_count - 1, item["uuid"])

func _get_targets_for_type(ctype: String) -> Array:
	match ctype:
		"redirect_sequence":
			return _available_sequences
		"redirect_condition":
			return _available_conditions
		"redirect_scene":
			return _available_scenes
		"redirect_chapter":
			return _available_chapters
	return []
