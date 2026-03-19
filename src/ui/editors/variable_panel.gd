extends VBoxContainer

## Panneau de gestion des variables de l'histoire.

const VariableDefinitionScript = preload("res://src/models/variable_definition.gd")

signal variables_changed

var _story = null
var _story_base_path: String = ""

@onready var _vars_list: VBoxContainer = $Scroll/VarsList
@onready var _add_btn: Button = $AddBtn

func _ready() -> void:
	_add_btn.pressed.connect(_on_add_pressed)

# --- Public API ---

func load_story(story, story_base_path: String = "") -> void:
	_story = story
	_story_base_path = story_base_path
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

func update_show_on_main(index: int, value: bool) -> void:
	if _story == null or index < 0 or index >= _story.variables.size():
		return
	_story.variables[index].show_on_main = value
	variables_changed.emit()

func update_show_on_details(index: int, value: bool) -> void:
	if _story == null or index < 0 or index >= _story.variables.size():
		return
	_story.variables[index].show_on_details = value
	variables_changed.emit()

func update_visibility_mode(index: int, mode: String) -> void:
	if _story == null or index < 0 or index >= _story.variables.size():
		return
	_story.variables[index].visibility_mode = mode
	variables_changed.emit()

func update_visibility_variable(index: int, var_name: String) -> void:
	if _story == null or index < 0 or index >= _story.variables.size():
		return
	_story.variables[index].visibility_variable = var_name
	variables_changed.emit()

func update_image(index: int, image_path: String) -> void:
	if _story == null or index < 0 or index >= _story.variables.size():
		return
	_story.variables[index].image = image_path
	variables_changed.emit()

func update_description(index: int, desc: String) -> void:
	if _story == null or index < 0 or index >= _story.variables.size():
		return
	_story.variables[index].description = desc
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
		var block = _create_var_block(i, _story.variables[i])
		_vars_list.add_child(block)

func _create_var_block(index: int, var_def) -> VBoxContainer:
	var block = VBoxContainer.new()
	block.add_theme_constant_override("separation", 4)

	# Ligne 1 : nom = valeur [×]
	var row1 = HBoxContainer.new()
	var name_edit = LineEdit.new()
	name_edit.text = var_def.var_name
	name_edit.placeholder_text = tr("Nom...")
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(_on_name_changed.bind(index))
	row1.add_child(name_edit)

	var eq_label = Label.new()
	eq_label.text = " = "
	row1.add_child(eq_label)

	var value_edit = LineEdit.new()
	value_edit.text = var_def.initial_value
	value_edit.placeholder_text = tr("Valeur initiale...")
	value_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_edit.text_changed.connect(_on_value_changed.bind(index))
	row1.add_child(value_edit)

	var delete_btn = Button.new()
	delete_btn.text = "×"
	delete_btn.pressed.connect(_on_delete_pressed.bind(index))
	row1.add_child(delete_btn)
	block.add_child(row1)

	# Ligne 2 : checkboxes affichage
	var row2 = HBoxContainer.new()
	row2.add_theme_constant_override("separation", 12)

	var main_cb = CheckBox.new()
	main_cb.text = tr("Interface principale")
	main_cb.button_pressed = var_def.show_on_main
	row2.add_child(main_cb)

	var details_cb = CheckBox.new()
	details_cb.text = tr("Page de détails")
	details_cb.button_pressed = var_def.show_on_details
	row2.add_child(details_cb)
	block.add_child(row2)

	# Ligne 3 : mode de visibilité (visible seulement si au moins une checkbox cochée)
	var row3 = HBoxContainer.new()
	row3.add_theme_constant_override("separation", 8)
	var is_displayed = var_def.show_on_main or var_def.show_on_details
	row3.visible = is_displayed

	var vis_label = Label.new()
	vis_label.text = tr("Visibilité :")
	row3.add_child(vis_label)

	var vis_mode = OptionButton.new()
	vis_mode.add_item(tr("Toujours visible"), 0)
	vis_mode.add_item(tr("Conditionnelle"), 1)
	vis_mode.selected = 1 if var_def.visibility_mode == "variable" else 0
	row3.add_child(vis_mode)

	var vis_var_option = OptionButton.new()
	vis_var_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vis_var_option.visible = (var_def.visibility_mode == "variable")
	_populate_variable_options(vis_var_option, index, var_def.visibility_variable)
	vis_var_option.item_selected.connect(func(idx):
		if idx >= 0 and idx < vis_var_option.item_count:
			update_visibility_variable(index, vis_var_option.get_item_text(idx))
	)
	row3.add_child(vis_var_option)

	vis_mode.item_selected.connect(func(idx):
		var mode = "variable" if idx == 1 else "always"
		update_visibility_mode(index, mode)
		vis_var_option.visible = (mode == "variable")
	)

	block.add_child(row3)

	# Ligne 4 : image + description (visible seulement si au moins une checkbox cochée)
	var row4 = HBoxContainer.new()
	row4.add_theme_constant_override("separation", 8)
	row4.visible = is_displayed

	# Connecter les checkboxes pour montrer/cacher les lignes 3 et 4
	main_cb.toggled.connect(func(pressed):
		update_show_on_main(index, pressed)
		var show = pressed or details_cb.button_pressed
		row3.visible = show
		row4.visible = show
	)
	details_cb.toggled.connect(func(pressed):
		update_show_on_details(index, pressed)
		var show = main_cb.button_pressed or pressed
		row3.visible = show
		row4.visible = show
	)

	var img_btn = Button.new()
	img_btn.text = tr("Image…")
	img_btn.pressed.connect(_on_image_btn_pressed.bind(index))
	row4.add_child(img_btn)

	var img_label = Label.new()
	img_label.text = var_def.image.get_file() if var_def.image != "" else tr("Aucune image")
	img_label.clip_text = true
	img_label.custom_minimum_size.x = 80
	row4.add_child(img_label)

	var desc_edit = LineEdit.new()
	desc_edit.text = var_def.description
	desc_edit.placeholder_text = tr("Description…")
	desc_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_edit.text_changed.connect(func(text): update_description(index, text))
	row4.add_child(desc_edit)

	block.add_child(row4)

	# Séparateur
	var sep = HSeparator.new()
	block.add_child(sep)

	return block

func _populate_variable_options(option_btn: OptionButton, current_index: int, selected_var: String) -> void:
	option_btn.clear()
	if _story == null:
		return
	var sel_idx := -1
	for i in range(_story.variables.size()):
		if i == current_index:
			continue
		var vname = _story.variables[i].var_name
		if vname == "":
			continue
		option_btn.add_item(vname)
		if vname == selected_var:
			sel_idx = option_btn.item_count - 1
	if sel_idx >= 0:
		option_btn.selected = sel_idx

func _on_image_btn_pressed(index: int) -> void:
	var ImagePickerDialog = load("res://src/ui/dialogs/image_picker_dialog.gd")
	var dialog = Window.new()
	dialog.set_script(ImagePickerDialog)
	# Trouver le noeud racine pour ajouter le dialog
	var root = get_tree().root if get_tree() else self
	root.add_child(dialog)
	dialog.setup(ImagePickerDialog.Mode.FOREGROUND, _story_base_path, _story)
	dialog.image_selected.connect(func(path):
		update_image(index, path)
		_rebuild_list()
	)
	dialog.popup_centered()

func _on_name_changed(new_text: String, index: int) -> void:
	var accepted = update_variable_name(index, new_text)
	if not accepted:
		var block = _vars_list.get_child(index) if index < _vars_list.get_child_count() else null
		if block:
			var row1 = block.get_child(0)
			if row1:
				var name_edit = row1.get_child(0)
				if name_edit is LineEdit:
					name_edit.add_theme_color_override("font_color", Color.RED)
	else:
		var block = _vars_list.get_child(index) if index < _vars_list.get_child_count() else null
		if block:
			var row1 = block.get_child(0)
			if row1:
				var name_edit = row1.get_child(0)
				if name_edit is LineEdit:
					name_edit.remove_theme_color_override("font_color")

func _on_value_changed(new_text: String, index: int) -> void:
	update_variable_value(index, new_text)

func _on_delete_pressed(index: int) -> void:
	remove_variable(index)
