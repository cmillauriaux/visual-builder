extends VBoxContainer

## Panneau de gestion des variables de l'histoire.

const VariableDefinitionScript = preload("res://src/models/variable_definition.gd")

signal variables_changed

var _story = null
var _vars_list: VBoxContainer
var _add_btn: Button

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var title = Label.new()
	title.text = "Variables de l'histoire"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(300, 200)
	add_child(scroll)

	_vars_list = VBoxContainer.new()
	_vars_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_vars_list)

	_add_btn = Button.new()
	_add_btn.text = "+ Ajouter une variable"
	_add_btn.pressed.connect(_on_add_pressed)
	add_child(_add_btn)

# --- Public API ---

func load_story(story) -> void:
	_story = story
	_rebuild_list()

func get_variable_count() -> int:
	if _story == null:
		return 0
	return _story.variables.size()

func add_variable() -> void:
	if _story == null:
		return
	var v = VariableDefinitionScript.new()
	v.var_name = ""
	v.initial_value = ""
	_story.variables.append(v)
	_rebuild_list()
	variables_changed.emit()

func remove_variable(index: int) -> void:
	if _story == null:
		return
	if index < 0 or index >= _story.variables.size():
		return
	_story.variables.remove_at(index)
	_rebuild_list()
	variables_changed.emit()

func update_variable_name(index: int, new_name: String) -> bool:
	if _story == null or index < 0 or index >= _story.variables.size():
		return false
	# Vérifier les doublons (sauf soi-même)
	for i in range(_story.variables.size()):
		if i != index and _story.variables[i].var_name == new_name:
			return false
	_story.variables[index].var_name = new_name
	variables_changed.emit()
	return true

func update_variable_value(index: int, new_value: String) -> void:
	if _story == null or index < 0 or index >= _story.variables.size():
		return
	_story.variables[index].initial_value = new_value
	variables_changed.emit()

# --- Private ---

func _on_add_pressed() -> void:
	add_variable()

func _rebuild_list() -> void:
	if _vars_list == null:
		return
	for child in _vars_list.get_children():
		child.queue_free()
	if _story == null:
		return
	for i in range(_story.variables.size()):
		var row = _create_var_row(i, _story.variables[i])
		_vars_list.add_child(row)

func _create_var_row(index: int, var_def) -> HBoxContainer:
	var row = HBoxContainer.new()

	var name_edit = LineEdit.new()
	name_edit.text = var_def.var_name
	name_edit.placeholder_text = "Nom..."
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(_on_name_changed.bind(index))
	row.add_child(name_edit)

	var eq_label = Label.new()
	eq_label.text = " = "
	row.add_child(eq_label)

	var value_edit = LineEdit.new()
	value_edit.text = var_def.initial_value
	value_edit.placeholder_text = "Valeur initiale..."
	value_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_edit.text_changed.connect(_on_value_changed.bind(index))
	row.add_child(value_edit)

	var delete_btn = Button.new()
	delete_btn.text = "×"
	delete_btn.pressed.connect(_on_delete_pressed.bind(index))
	row.add_child(delete_btn)

	return row

func _on_name_changed(new_text: String, index: int) -> void:
	var accepted = update_variable_name(index, new_text)
	if not accepted:
		# Signaler visuellement le doublon
		var row = _vars_list.get_child(index) if index < _vars_list.get_child_count() else null
		if row:
			var name_edit = row.get_child(0)
			if name_edit is LineEdit:
				name_edit.add_theme_color_override("font_color", Color.RED)
	else:
		var row = _vars_list.get_child(index) if index < _vars_list.get_child_count() else null
		if row:
			var name_edit = row.get_child(0)
			if name_edit is LineEdit:
				name_edit.remove_theme_color_override("font_color")

func _on_value_changed(new_text: String, index: int) -> void:
	update_variable_value(index, new_text)

func _on_delete_pressed(index: int) -> void:
	remove_variable(index)
