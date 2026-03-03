extends VBoxContainer

## Éditeur de terminaison pour une séquence — avec UI complète.

class_name EndingEditor

const EndingScript = preload("res://src/models/ending.gd")
const ConsequenceScript = preload("res://src/models/consequence.gd")
const ChoiceScript = preload("res://src/models/choice.gd")
const VariableEffectScript = preload("res://src/models/variable_effect.gd")
const ConsequenceTargetHelperScript = preload("res://src/ui/shared/consequence_target_helper.gd")
const EffectRowBuilderScript = preload("res://src/ui/shared/effect_row_builder.gd")
const EditorState = preload("res://src/controllers/editor_state.gd")

const OPERATION_TYPES = VariableEffectScript.VALID_OPERATIONS
const OPERATION_LABELS = VariableEffectScript.OPERATION_LABELS

signal ending_changed
signal new_target_requested(ctype: String, callback: Callable)

var _sequence = null
var _target_helper = ConsequenceTargetHelperScript.new()

# UI references
@onready var _mode_none_btn: Button = %NoneBtn
@onready var _mode_redirect_btn: Button = %RedirectBtn
@onready var _mode_choices_btn: Button = %ChoicesBtn
@onready var _redirect_container: VBoxContainer = %RedirectContainer
@onready var _choices_container: VBoxContainer = %ChoicesContainer
@onready var _redirect_type_dropdown: OptionButton = %TypeDropdown
@onready var _redirect_target_dropdown: OptionButton = %TargetDropdown
@onready var _redirect_summary: Label = %Summary
@onready var _choices_list: VBoxContainer = %ChoicesList
@onready var _add_choice_btn: Button = %AddChoiceBtn
@onready var _redirect_effects_list: VBoxContainer = %RedirectEffectsList
@onready var _add_redirect_effect_btn: Button = %AddRedirectEffectBtn

# Consequence type labels (delegated to helper)
var CONSEQUENCE_TYPES: Array:
	get: return ConsequenceTargetHelperScript.CONSEQUENCE_TYPES
var CONSEQUENCE_LABELS: Array:
	get: return ConsequenceTargetHelperScript.CONSEQUENCE_LABELS
var REDIRECT_TYPES: Array:
	get: return ConsequenceTargetHelperScript.REDIRECT_TYPES

func _ready() -> void:
	# Initialiser les dropdowns statiques
	_redirect_type_dropdown.clear()
	for label in CONSEQUENCE_LABELS:
		_redirect_type_dropdown.add_item(label)
	
	# Connecter les signaux
	_mode_none_btn.pressed.connect(_on_mode_none)
	_mode_redirect_btn.pressed.connect(_on_mode_redirect)
	_mode_choices_btn.pressed.connect(_on_mode_choices)
	_redirect_type_dropdown.item_selected.connect(_on_redirect_type_changed)
	_redirect_target_dropdown.item_selected.connect(_on_redirect_target_changed)
	_add_redirect_effect_btn.pressed.connect(_on_add_redirect_effect_pressed)
	_add_choice_btn.pressed.connect(_on_add_choice_pressed)

	EventBus.story_loaded.connect(_on_story_loaded)
	EventBus.story_modified.connect(_on_story_modified)
	EventBus.editor_mode_changed.connect(_on_editor_mode_changed)
	EventBus.targets_updated.connect(set_available_targets)


func _on_story_loaded(story: StoryModel) -> void:
	set_variable_names(story.get_variable_names())


func _on_story_modified() -> void:
	# Note: On ne peut pas récupérer la story ici facilement sans référence
	pass


func _on_editor_mode_changed(mode: int, context: Dictionary) -> void:
	if mode == EditorState.Mode.SEQUENCE_EDIT:
		# On rafraîchit les cibles disponibles quand on entre dans l'éditeur de séquence
		_request_target_refresh()


func _request_target_refresh() -> void:
	pass

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
	_notify_change()

func remove_redirect_effect(index: int) -> void:
	if _sequence == null or _sequence.ending == null or _sequence.ending.auto_consequence == null:
		return
	if index < 0 or index >= _sequence.ending.auto_consequence.effects.size():
		return
	_sequence.ending.auto_consequence.effects.remove_at(index)
	if _redirect_container.visible:
		_rebuild_redirect_effects()
	_notify_change()

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
	_notify_change()

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
	_notify_change()

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
	_notify_change()

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
	_notify_change()

# --- Mode handlers ---

func _on_mode_none() -> void:
	if _sequence == null:
		return
	_sequence.ending = null
	_update_mode_buttons("none")
	_redirect_container.visible = false
	_choices_container.visible = false
	_notify_change()

func _on_mode_redirect() -> void:
	if _sequence == null:
		return
	set_ending_type("auto_redirect")
	_update_mode_buttons("auto_redirect")
	_redirect_container.visible = true
	_choices_container.visible = false
	_redirect_type_dropdown.selected = 0
	_apply_redirect_type(0)
	_notify_change()

func _on_mode_choices() -> void:
	if _sequence == null:
		return
	set_ending_type("choices")
	_update_mode_buttons("choices")
	_redirect_container.visible = false
	_choices_container.visible = true
	_rebuild_choices_list()
	_notify_change()

func _update_mode_buttons(mode: String) -> void:
	_mode_none_btn.button_pressed = (mode == "none")
	_mode_redirect_btn.button_pressed = (mode == "auto_redirect")
	_mode_choices_btn.button_pressed = (mode == "choices")

# --- Redirect handlers ---

func _on_redirect_type_changed(index: int) -> void:
	_apply_redirect_type(index)
	_notify_change()

func _apply_redirect_type(index: int) -> void:
	if _sequence == null or _sequence.ending == null:
		return
	var ctype = CONSEQUENCE_TYPES[index]
	_populate_redirect_target()
	var needs_target = ctype in REDIRECT_TYPES
	_redirect_target_dropdown.visible = needs_target
	if needs_target:
		var target = ""
		var first_real = _find_first_real_target_index(_redirect_target_dropdown)
		if first_real >= 0:
			target = _redirect_target_dropdown.get_item_metadata(first_real)
			_redirect_target_dropdown.selected = first_real
		set_auto_consequence(ctype, target)
	else:
		set_auto_consequence(ctype, "")
	_update_redirect_summary()

func _on_redirect_target_changed(index: int) -> void:
	if _sequence == null or _sequence.ending == null or _sequence.ending.auto_consequence == null:
		return
	if index >= 0 and index < _redirect_target_dropdown.item_count:
		var meta = _redirect_target_dropdown.get_item_metadata(index)
		if ConsequenceTargetHelperScript.is_new_target_meta(meta):
			var ctype = _sequence.ending.auto_consequence.type
			new_target_requested.emit(ctype, func(new_uuid: String) -> void:
				_sequence.ending.auto_consequence.target = new_uuid
				_populate_redirect_target()
				_select_target_in_dropdown(_redirect_target_dropdown, new_uuid)
				_update_redirect_summary()
				_notify_change()
			)
			return
		_sequence.ending.auto_consequence.target = meta
	_update_redirect_summary()
	_notify_change()

func _populate_redirect_target() -> void:
	var type_index = _redirect_type_dropdown.selected
	if type_index < 0 or type_index >= CONSEQUENCE_TYPES.size():
		_redirect_target_dropdown.clear()
		return
	var ctype = CONSEQUENCE_TYPES[type_index]
	_target_helper.populate_target_dropdown(_redirect_target_dropdown, ctype)

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
	_notify_change()

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
	_notify_change()

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
		var items = _get_targets_for_type(ctype)
		choice.consequence.target = items[0]["uuid"] if items.size() > 0 else ""
	_rebuild_choices_list()
	_notify_change()

func _on_choice_target_changed(target_index: int, choice_index: int) -> void:
	if _sequence == null or _sequence.ending == null:
		return
	if choice_index < 0 or choice_index >= _sequence.ending.choices.size():
		return
	var choice = _sequence.ending.choices[choice_index]
	if choice.consequence == null:
		return
	# Find the target dropdown in the choice row
	var choice_row = _choices_list.get_child(choice_index)
	var target_dropdown = _find_target_dropdown_in_choice(choice_row)
	if target_dropdown and target_index >= 0 and target_index < target_dropdown.item_count:
		var meta = target_dropdown.get_item_metadata(target_index)
		if ConsequenceTargetHelperScript.is_new_target_meta(meta):
			var ctype = choice.consequence.type
			new_target_requested.emit(ctype, func(new_uuid: String) -> void:
				choice.consequence.target = new_uuid
				_rebuild_choices_list()
				_notify_change()
			)
			return
		choice.consequence.target = meta
	_notify_change()

func _find_target_dropdown_in_choice(choice_row) -> OptionButton:
	if choice_row == null:
		return null
	for child in choice_row.get_children():
		if child is HBoxContainer:
			for sub in child.get_children():
				if sub is OptionButton and sub.size_flags_horizontal == Control.SIZE_EXPAND_FILL:
					return sub
	return null

func _select_target_in_dropdown(dropdown: OptionButton, uuid: String) -> void:
	for i in range(dropdown.item_count):
		if dropdown.get_item_metadata(i) == uuid:
			dropdown.selected = i
			return

func _find_first_real_target_index(dropdown: OptionButton) -> int:
	for i in range(dropdown.item_count):
		if not ConsequenceTargetHelperScript.is_new_target_meta(dropdown.get_item_metadata(i)):
			return i
	return -1

func _on_delete_choice(index: int) -> void:
	remove_choice(index)
	_rebuild_choices_list()
	_notify_change()

func _notify_change() -> void:
	ending_changed.emit()
	EventBus.story_modified.emit()

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
