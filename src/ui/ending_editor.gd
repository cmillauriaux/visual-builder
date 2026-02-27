extends VBoxContainer

## Éditeur de terminaison pour une séquence — avec UI complète.

const EndingScript = preload("res://src/models/ending.gd")
const ConsequenceScript = preload("res://src/models/consequence.gd")
const ChoiceScript = preload("res://src/models/choice.gd")
const VariableEffectScript = preload("res://src/models/variable_effect.gd")
const ConsequenceTargetHelperScript = preload("res://src/ui/consequence_target_helper.gd")
const EffectRowBuilderScript = preload("res://src/ui/effect_row_builder.gd")

const OPERATION_TYPES = VariableEffectScript.VALID_OPERATIONS
const OPERATION_LABELS = VariableEffectScript.OPERATION_LABELS

signal ending_changed

var _sequence = null
var _target_helper = ConsequenceTargetHelperScript.new()

# UI references
var _mode_none_btn: Button
var _mode_redirect_btn: Button
var _mode_choices_btn: Button
var _redirect_container: VBoxContainer
var _choices_container: VBoxContainer
var _redirect_type_dropdown: OptionButton
var _redirect_target_dropdown: OptionButton
var _redirect_summary: Label
var _choices_list: VBoxContainer
var _add_choice_btn: Button
var _redirect_effects_list: VBoxContainer
var _add_redirect_effect_btn: Button

# Consequence type labels (delegated to helper)
var CONSEQUENCE_TYPES: Array:
	get: return ConsequenceTargetHelperScript.CONSEQUENCE_TYPES
var CONSEQUENCE_LABELS: Array:
	get: return ConsequenceTargetHelperScript.CONSEQUENCE_LABELS
var REDIRECT_TYPES: Array:
	get: return ConsequenceTargetHelperScript.REDIRECT_TYPES

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# Separator label
	var sep = Label.new()
	sep.text = "— Terminaison —"
	sep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sep)

	# Mode selector
	var mode_bar = HBoxContainer.new()
	add_child(mode_bar)

	_mode_none_btn = Button.new()
	_mode_none_btn.text = "Aucune"
	_mode_none_btn.toggle_mode = true
	_mode_none_btn.button_pressed = true
	_mode_none_btn.pressed.connect(_on_mode_none)
	mode_bar.add_child(_mode_none_btn)

	_mode_redirect_btn = Button.new()
	_mode_redirect_btn.text = "Redirection"
	_mode_redirect_btn.toggle_mode = true
	_mode_redirect_btn.pressed.connect(_on_mode_redirect)
	mode_bar.add_child(_mode_redirect_btn)

	_mode_choices_btn = Button.new()
	_mode_choices_btn.text = "Choix"
	_mode_choices_btn.toggle_mode = true
	_mode_choices_btn.pressed.connect(_on_mode_choices)
	mode_bar.add_child(_mode_choices_btn)

	# --- Redirect container ---
	_redirect_container = VBoxContainer.new()
	_redirect_container.visible = false
	add_child(_redirect_container)

	_redirect_type_dropdown = OptionButton.new()
	for label in CONSEQUENCE_LABELS:
		_redirect_type_dropdown.add_item(label)
	_redirect_type_dropdown.item_selected.connect(_on_redirect_type_changed)
	_redirect_container.add_child(_redirect_type_dropdown)

	_redirect_target_dropdown = OptionButton.new()
	_redirect_target_dropdown.item_selected.connect(_on_redirect_target_changed)
	_redirect_container.add_child(_redirect_target_dropdown)

	_redirect_summary = Label.new()
	_redirect_summary.text = ""
	_redirect_container.add_child(_redirect_summary)

	# Redirect effects section
	var redirect_effects_label = Label.new()
	redirect_effects_label.text = "Effets sur les variables :"
	_redirect_container.add_child(redirect_effects_label)

	_redirect_effects_list = VBoxContainer.new()
	_redirect_effects_list.name = "RedirectEffectsList"
	_redirect_container.add_child(_redirect_effects_list)

	_add_redirect_effect_btn = Button.new()
	_add_redirect_effect_btn.text = "+ Ajouter un effet"
	_add_redirect_effect_btn.pressed.connect(_on_add_redirect_effect_pressed)
	_redirect_container.add_child(_add_redirect_effect_btn)

	# --- Choices container ---
	_choices_container = VBoxContainer.new()
	_choices_container.visible = false
	add_child(_choices_container)

	var choices_scroll = ScrollContainer.new()
	choices_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	choices_scroll.custom_minimum_size.y = 100
	_choices_container.add_child(choices_scroll)

	_choices_list = VBoxContainer.new()
	_choices_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices_scroll.add_child(_choices_list)

	_add_choice_btn = Button.new()
	_add_choice_btn.text = "+ Ajouter un choix"
	_add_choice_btn.pressed.connect(_on_add_choice_pressed)
	_choices_container.add_child(_add_choice_btn)

# --- Public API ---

func load_sequence(sequence) -> void:
	_sequence = sequence
	_refresh_ui()

func get_ending_type() -> String:
	if _sequence == null or _sequence.ending == null:
		return ""
	return _sequence.ending.type

func set_ending_type(type: String) -> void:
	if _sequence == null:
		return
	var ending = EndingScript.new()
	ending.type = type
	_sequence.ending = ending

func add_choice(text: String, consequence_type: String, target: String) -> void:
	if _sequence == null or _sequence.ending == null:
		return
	if _sequence.ending.choices.size() >= 8:
		return
	var choice = ChoiceScript.new()
	choice.text = text
	var consequence = ConsequenceScript.new()
	consequence.type = consequence_type
	consequence.target = target
	choice.consequence = consequence
	_sequence.ending.choices.append(choice)

func remove_choice(index: int) -> void:
	if _sequence == null or _sequence.ending == null:
		return
	if index < 0 or index >= _sequence.ending.choices.size():
		return
	_sequence.ending.choices.remove_at(index)

func set_auto_consequence(type: String, target: String) -> void:
	if _sequence == null or _sequence.ending == null:
		return
	var consequence = ConsequenceScript.new()
	consequence.type = type
	consequence.target = target
	_sequence.ending.auto_consequence = consequence

func set_available_targets(sequences: Array, scenes: Array, chapters: Array, conditions: Array = []) -> void:
	_target_helper.set_available_targets(sequences, scenes, chapters, conditions)
	# Refresh dropdowns if already showing
	if _redirect_container.visible:
		_populate_redirect_target()
	if _choices_container.visible:
		_rebuild_choices_list()

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

func get_variable_names() -> Array:
	return _target_helper.variable_names

# --- Effects API ---

func add_redirect_effect() -> void:
	if _sequence == null or _sequence.ending == null or _sequence.ending.auto_consequence == null:
		return
	var e = VariableEffectScript.new()
	e.operation = "set"
	_sequence.ending.auto_consequence.effects.append(e)
	if _redirect_container.visible:
		_rebuild_redirect_effects()
	ending_changed.emit()

func remove_redirect_effect(index: int) -> void:
	if _sequence == null or _sequence.ending == null or _sequence.ending.auto_consequence == null:
		return
	if index < 0 or index >= _sequence.ending.auto_consequence.effects.size():
		return
	_sequence.ending.auto_consequence.effects.remove_at(index)
	if _redirect_container.visible:
		_rebuild_redirect_effects()
	ending_changed.emit()

func update_redirect_effect(index: int, field: String, value: String) -> void:
	if _sequence == null or _sequence.ending == null or _sequence.ending.auto_consequence == null:
		return
	if index < 0 or index >= _sequence.ending.auto_consequence.effects.size():
		return
	var e = _sequence.ending.auto_consequence.effects[index]
	match field:
		"variable":
			e.variable = value
		"operation":
			e.operation = value
		"value":
			e.value = value
	ending_changed.emit()

func add_choice_effect(choice_index: int) -> void:
	if _sequence == null or _sequence.ending == null:
		return
	if choice_index < 0 or choice_index >= _sequence.ending.choices.size():
		return
	var e = VariableEffectScript.new()
	e.operation = "set"
	_sequence.ending.choices[choice_index].effects.append(e)
	if _choices_container.visible:
		_rebuild_choices_list()
	ending_changed.emit()

func remove_choice_effect(choice_index: int, effect_index: int) -> void:
	if _sequence == null or _sequence.ending == null:
		return
	if choice_index < 0 or choice_index >= _sequence.ending.choices.size():
		return
	var choice = _sequence.ending.choices[choice_index]
	if effect_index < 0 or effect_index >= choice.effects.size():
		return
	choice.effects.remove_at(effect_index)
	if _choices_container.visible:
		_rebuild_choices_list()
	ending_changed.emit()

func update_choice_effect(choice_index: int, effect_index: int, field: String, value: String) -> void:
	if _sequence == null or _sequence.ending == null:
		return
	if choice_index < 0 or choice_index >= _sequence.ending.choices.size():
		return
	var choice = _sequence.ending.choices[choice_index]
	if effect_index < 0 or effect_index >= choice.effects.size():
		return
	var e = choice.effects[effect_index]
	match field:
		"variable":
			e.variable = value
		"operation":
			e.operation = value
		"value":
			e.value = value
	ending_changed.emit()

# --- Mode handlers ---

func _on_mode_none() -> void:
	if _sequence == null:
		return
	_sequence.ending = null
	_update_mode_buttons("none")
	_redirect_container.visible = false
	_choices_container.visible = false
	ending_changed.emit()

func _on_mode_redirect() -> void:
	if _sequence == null:
		return
	set_ending_type("auto_redirect")
	_update_mode_buttons("auto_redirect")
	_redirect_container.visible = true
	_choices_container.visible = false
	_redirect_type_dropdown.selected = 0
	_apply_redirect_type(0)
	ending_changed.emit()

func _on_mode_choices() -> void:
	if _sequence == null:
		return
	set_ending_type("choices")
	_update_mode_buttons("choices")
	_redirect_container.visible = false
	_choices_container.visible = true
	_rebuild_choices_list()
	ending_changed.emit()

func _update_mode_buttons(mode: String) -> void:
	_mode_none_btn.button_pressed = (mode == "none")
	_mode_redirect_btn.button_pressed = (mode == "auto_redirect")
	_mode_choices_btn.button_pressed = (mode == "choices")

# --- Redirect handlers ---

func _on_redirect_type_changed(index: int) -> void:
	_apply_redirect_type(index)
	ending_changed.emit()

func _apply_redirect_type(index: int) -> void:
	if _sequence == null or _sequence.ending == null:
		return
	var ctype = CONSEQUENCE_TYPES[index]
	_populate_redirect_target()
	var needs_target = ctype in REDIRECT_TYPES
	_redirect_target_dropdown.visible = needs_target
	if needs_target:
		var target = ""
		if _redirect_target_dropdown.item_count > 0:
			target = _redirect_target_dropdown.get_item_metadata(0) if _redirect_target_dropdown.item_count > 0 else ""
			_redirect_target_dropdown.selected = 0
		set_auto_consequence(ctype, target)
	else:
		set_auto_consequence(ctype, "")
	_update_redirect_summary()

func _on_redirect_target_changed(index: int) -> void:
	if _sequence == null or _sequence.ending == null or _sequence.ending.auto_consequence == null:
		return
	if index >= 0 and index < _redirect_target_dropdown.item_count:
		var target_uuid = _redirect_target_dropdown.get_item_metadata(index)
		_sequence.ending.auto_consequence.target = target_uuid
	_update_redirect_summary()
	ending_changed.emit()

func _populate_redirect_target() -> void:
	_redirect_target_dropdown.clear()
	var type_index = _redirect_type_dropdown.selected
	if type_index < 0 or type_index >= CONSEQUENCE_TYPES.size():
		return
	var ctype = CONSEQUENCE_TYPES[type_index]
	var items = _get_targets_for_type(ctype)
	for item in items:
		_redirect_target_dropdown.add_item(item["name"])
		_redirect_target_dropdown.set_item_metadata(_redirect_target_dropdown.item_count - 1, item["uuid"])

func _get_targets_for_type(ctype: String) -> Array:
	return _target_helper.get_targets_for_type(ctype)

func _on_add_redirect_effect_pressed() -> void:
	add_redirect_effect()

func _rebuild_redirect_effects() -> void:
	if _redirect_effects_list == null:
		return
	for child in _redirect_effects_list.get_children():
		child.queue_free()
	if _sequence == null or _sequence.ending == null or _sequence.ending.auto_consequence == null:
		return
	for i in range(_sequence.ending.auto_consequence.effects.size()):
		var row = _create_effect_row(_sequence.ending.auto_consequence.effects[i], "redirect", -1, i)
		_redirect_effects_list.add_child(row)

func _create_effect_row(effect, context: String, choice_index: int, effect_index: int) -> HBoxContainer:
	if context == "redirect":
		return EffectRowBuilderScript.create_effect_row(
			effect, _target_helper.variable_names,
			func(t): update_redirect_effect(effect_index, "variable", t),
			func(op): update_redirect_effect(effect_index, "operation", op); _rebuild_redirect_effects(),
			func(t): update_redirect_effect(effect_index, "value", t),
			func(): remove_redirect_effect(effect_index)
		)
	else:
		return EffectRowBuilderScript.create_effect_row(
			effect, _target_helper.variable_names,
			func(t): update_choice_effect(choice_index, effect_index, "variable", t),
			func(op): update_choice_effect(choice_index, effect_index, "operation", op); _rebuild_choices_list(),
			func(t): update_choice_effect(choice_index, effect_index, "value", t),
			func(): remove_choice_effect(choice_index, effect_index)
		)

func _update_redirect_summary() -> void:
	if _sequence == null or _sequence.ending == null or _sequence.ending.auto_consequence == null:
		_redirect_summary.text = ""
		return
	var cons = _sequence.ending.auto_consequence
	var type_label = ""
	var idx = CONSEQUENCE_TYPES.find(cons.type)
	if idx >= 0:
		type_label = CONSEQUENCE_LABELS[idx]
	if cons.type in REDIRECT_TYPES:
		var target_name = _find_target_name(cons.type, cons.target)
		_redirect_summary.text = "→ %s : %s" % [type_label, target_name]
	else:
		_redirect_summary.text = "→ %s" % type_label

func _find_target_name(ctype: String, uuid: String) -> String:
	var items = _get_targets_for_type(ctype)
	for item in items:
		if item["uuid"] == uuid:
			return item["name"]
	return uuid

# --- Choices handlers ---

func _on_add_choice_pressed() -> void:
	if _sequence == null or _sequence.ending == null:
		return
	add_choice("", "redirect_sequence", "")
	_rebuild_choices_list()
	ending_changed.emit()

func _rebuild_choices_list() -> void:
	# Clear existing UI
	for child in _choices_list.get_children():
		child.queue_free()

	if _sequence == null or _sequence.ending == null:
		return

	for i in range(_sequence.ending.choices.size()):
		var choice = _sequence.ending.choices[i]
		var row = _create_choice_row(i, choice)
		_choices_list.add_child(row)

	_add_choice_btn.disabled = _sequence.ending.choices.size() >= 8

func _create_choice_row(index: int, choice) -> VBoxContainer:
	var container = VBoxContainer.new()

	var header = HBoxContainer.new()
	container.add_child(header)

	var label = Label.new()
	label.text = "Choix %d" % (index + 1)
	header.add_child(label)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var delete_btn = Button.new()
	delete_btn.text = "×"
	delete_btn.pressed.connect(_on_delete_choice.bind(index))
	header.add_child(delete_btn)

	# Text field
	var text_edit = LineEdit.new()
	text_edit.text = choice.text
	text_edit.placeholder_text = "Texte du choix..."
	text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_edit.text_changed.connect(_on_choice_text_changed.bind(index))
	container.add_child(text_edit)

	# Type + target row
	var type_row = HBoxContainer.new()
	container.add_child(type_row)

	var type_dropdown = OptionButton.new()
	for lbl in CONSEQUENCE_LABELS:
		type_dropdown.add_item(lbl)
	# Set current type
	var type_idx = CONSEQUENCE_TYPES.find(choice.consequence.type) if choice.consequence else 0
	if type_idx < 0:
		type_idx = 0
	type_dropdown.selected = type_idx
	type_dropdown.item_selected.connect(_on_choice_type_changed.bind(index))
	type_row.add_child(type_dropdown)

	var target_dropdown = OptionButton.new()
	target_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ctype = CONSEQUENCE_TYPES[type_idx]
	_populate_target_dropdown(target_dropdown, ctype)
	# Select current target
	if choice.consequence and choice.consequence.target != "":
		for t in range(target_dropdown.item_count):
			if target_dropdown.get_item_metadata(t) == choice.consequence.target:
				target_dropdown.selected = t
				break
	target_dropdown.visible = ctype in REDIRECT_TYPES
	target_dropdown.item_selected.connect(_on_choice_target_changed.bind(index))
	type_row.add_child(target_dropdown)

	# Effects section for this choice
	var effects_label = Label.new()
	effects_label.text = "Effets sur les variables :"
	container.add_child(effects_label)

	var effects_list = VBoxContainer.new()
	effects_list.name = "EffectsList"
	container.add_child(effects_list)
	for ei in range(choice.effects.size()):
		var effect_row = _create_effect_row(choice.effects[ei], "choice", index, ei)
		effects_list.add_child(effect_row)

	var add_effect_btn = Button.new()
	add_effect_btn.text = "+ Ajouter un effet"
	add_effect_btn.pressed.connect(func(): add_choice_effect(index))
	container.add_child(add_effect_btn)

	# Add a separator
	var sep = HSeparator.new()
	container.add_child(sep)

	return container

func _populate_target_dropdown(dropdown: OptionButton, ctype: String) -> void:
	_target_helper.populate_target_dropdown(dropdown, ctype)

func _on_choice_text_changed(new_text: String, index: int) -> void:
	if _sequence == null or _sequence.ending == null:
		return
	if index < 0 or index >= _sequence.ending.choices.size():
		return
	_sequence.ending.choices[index].text = new_text
	ending_changed.emit()

func _on_choice_type_changed(type_index: int, choice_index: int) -> void:
	if _sequence == null or _sequence.ending == null:
		return
	if choice_index < 0 or choice_index >= _sequence.ending.choices.size():
		return
	var ctype = CONSEQUENCE_TYPES[type_index]
	var choice = _sequence.ending.choices[choice_index]
	if choice.consequence == null:
		choice.consequence = ConsequenceScript.new()
	choice.consequence.type = ctype
	if ctype not in REDIRECT_TYPES:
		choice.consequence.target = ""
	else:
		# Reset target to first available
		var items = _get_targets_for_type(ctype)
		choice.consequence.target = items[0]["uuid"] if items.size() > 0 else ""
	_rebuild_choices_list()
	ending_changed.emit()

func _on_choice_target_changed(target_index: int, choice_index: int) -> void:
	if _sequence == null or _sequence.ending == null:
		return
	if choice_index < 0 or choice_index >= _sequence.ending.choices.size():
		return
	var choice = _sequence.ending.choices[choice_index]
	if choice.consequence == null:
		return
	# Find the target dropdown in the choice row
	var ctype = choice.consequence.type
	var items = _get_targets_for_type(ctype)
	if target_index >= 0 and target_index < items.size():
		choice.consequence.target = items[target_index]["uuid"]
	ending_changed.emit()

func _on_delete_choice(index: int) -> void:
	remove_choice(index)
	_rebuild_choices_list()
	ending_changed.emit()

# --- Refresh UI from model ---

func _refresh_ui() -> void:
	if _sequence == null or _sequence.ending == null:
		_update_mode_buttons("none")
		_redirect_container.visible = false
		_choices_container.visible = false
		return

	var etype = _sequence.ending.type
	_update_mode_buttons(etype)

	if etype == "auto_redirect":
		_redirect_container.visible = true
		_choices_container.visible = false
		# Set type dropdown
		if _sequence.ending.auto_consequence:
			var idx = CONSEQUENCE_TYPES.find(_sequence.ending.auto_consequence.type)
			if idx >= 0:
				_redirect_type_dropdown.selected = idx
			_populate_redirect_target()
			var needs_target = _sequence.ending.auto_consequence.type in REDIRECT_TYPES
			_redirect_target_dropdown.visible = needs_target
			if needs_target and _sequence.ending.auto_consequence.target != "":
				for t in range(_redirect_target_dropdown.item_count):
					if _redirect_target_dropdown.get_item_metadata(t) == _sequence.ending.auto_consequence.target:
						_redirect_target_dropdown.selected = t
						break
			_update_redirect_summary()
		_rebuild_redirect_effects()
	elif etype == "choices":
		_redirect_container.visible = false
		_choices_container.visible = true
		_rebuild_choices_list()
	else:
		_redirect_container.visible = false
		_choices_container.visible = false
