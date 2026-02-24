extends VBoxContainer

## Éditeur de terminaison pour une séquence — avec UI complète.

const EndingScript = preload("res://src/models/ending.gd")
const ConsequenceScript = preload("res://src/models/consequence.gd")
const ChoiceScript = preload("res://src/models/choice.gd")

signal ending_changed

var _sequence = null
var _available_sequences: Array = []  # [{uuid, name}]
var _available_scenes: Array = []     # [{uuid, name}]
var _available_chapters: Array = []   # [{uuid, name}]

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

# Consequence type labels
const CONSEQUENCE_TYPES = ["redirect_sequence", "redirect_scene", "redirect_chapter", "game_over", "to_be_continued"]
const CONSEQUENCE_LABELS = ["Séquence", "Scène", "Chapitre", "Game Over", "To be continued"]
const REDIRECT_TYPES = ["redirect_sequence", "redirect_scene", "redirect_chapter"]

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

func set_available_targets(sequences: Array, scenes: Array, chapters: Array) -> void:
	_available_sequences = sequences
	_available_scenes = scenes
	_available_chapters = chapters
	# Refresh dropdowns if already showing
	if _redirect_container.visible:
		_populate_redirect_target()
	if _choices_container.visible:
		_rebuild_choices_list()

func get_available_sequences() -> Array:
	return _available_sequences

func get_available_scenes() -> Array:
	return _available_scenes

func get_available_chapters() -> Array:
	return _available_chapters

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
	match ctype:
		"redirect_sequence":
			return _available_sequences
		"redirect_scene":
			return _available_scenes
		"redirect_chapter":
			return _available_chapters
	return []

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

	# Add a separator
	var sep = HSeparator.new()
	container.add_child(sep)

	return container

func _populate_target_dropdown(dropdown: OptionButton, ctype: String) -> void:
	dropdown.clear()
	var items = _get_targets_for_type(ctype)
	for item in items:
		dropdown.add_item(item["name"])
		dropdown.set_item_metadata(dropdown.item_count - 1, item["uuid"])

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
	elif etype == "choices":
		_redirect_container.visible = false
		_choices_container.visible = true
		_rebuild_choices_list()
	else:
		_redirect_container.visible = false
		_choices_container.visible = false
