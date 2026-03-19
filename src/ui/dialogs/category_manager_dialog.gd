extends Window

## Dialog modal de gestion des catégories d'images.
## Permet d'ajouter, renommer et supprimer des catégories.

signal categories_changed

var _service: RefCounted = null

# Références UI
var _item_list: ItemList
var _add_input: LineEdit
var _add_button: Button
var _rename_button: Button
var _remove_button: Button
var _close_button: Button


func _ready() -> void:
	title = tr("Gérer les catégories")
	size = Vector2i(400, 350)
	exclusive = true
	close_requested.connect(_on_close)
	_build_ui()


func setup(service: RefCounted) -> void:
	_service = service
	_refresh_list()


func _build_ui() -> void:
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Liste des catégories
	_item_list = ItemList.new()
	_item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_item_list.item_selected.connect(_on_item_selected)
	vbox.add_child(_item_list)

	# Zone d'ajout
	var add_hbox = HBoxContainer.new()
	add_hbox.add_theme_constant_override("separation", 4)
	vbox.add_child(add_hbox)

	_add_input = LineEdit.new()
	_add_input.placeholder_text = tr("Nouvelle catégorie...")
	_add_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add_input.text_submitted.connect(func(_t): _on_add_pressed())
	add_hbox.add_child(_add_input)

	_add_button = Button.new()
	_add_button.text = tr("Ajouter")
	_add_button.pressed.connect(_on_add_pressed)
	add_hbox.add_child(_add_button)

	# Boutons d'action
	var action_hbox = HBoxContainer.new()
	action_hbox.add_theme_constant_override("separation", 4)
	vbox.add_child(action_hbox)

	_rename_button = Button.new()
	_rename_button.text = tr("Renommer")
	_rename_button.disabled = true
	_rename_button.pressed.connect(_on_rename_pressed)
	action_hbox.add_child(_rename_button)

	_remove_button = Button.new()
	_remove_button.text = tr("Supprimer")
	_remove_button.disabled = true
	_remove_button.pressed.connect(_on_remove_pressed)
	action_hbox.add_child(_remove_button)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_hbox.add_child(spacer)

	_close_button = Button.new()
	_close_button.text = tr("Fermer")
	_close_button.pressed.connect(_on_close)
	action_hbox.add_child(_close_button)


func _refresh_list() -> void:
	_item_list.clear()
	if _service == null:
		return
	for cat in _service.get_categories():
		_item_list.add_item(cat)
	_rename_button.disabled = true
	_remove_button.disabled = true


func _on_item_selected(_index: int) -> void:
	_rename_button.disabled = false
	_remove_button.disabled = false


func _on_add_pressed() -> void:
	var name = _add_input.text.strip_edges()
	if name == "" or _service == null:
		return
	_service.add_category(name)
	_add_input.text = ""
	_refresh_list()
	categories_changed.emit()


func _on_rename_pressed() -> void:
	var selected = _item_list.get_selected_items()
	if selected.is_empty() or _service == null:
		return
	var old_name = _item_list.get_item_text(selected[0])

	var rename_dialog = AcceptDialog.new()
	rename_dialog.title = tr("Renommer la catégorie")
	rename_dialog.dialog_text = tr("Nouveau nom :")
	var input = LineEdit.new()
	input.text = old_name
	rename_dialog.add_child(input)
	rename_dialog.confirmed.connect(func():
		var new_name = input.text.strip_edges()
		if new_name != "" and new_name != old_name:
			_service.rename_category(old_name, new_name)
			_refresh_list()
			categories_changed.emit()
	)
	add_child(rename_dialog)
	rename_dialog.popup_centered()


func _on_remove_pressed() -> void:
	var selected = _item_list.get_selected_items()
	if selected.is_empty() or _service == null:
		return
	var cat_name = _item_list.get_item_text(selected[0])
	var count = _service.get_assigned_image_count(cat_name)

	if count > 0:
		var confirm = ConfirmationDialog.new()
		confirm.dialog_text = tr("%d image(s) assignée(s) à « %s ». Supprimer quand même ?") % [count, cat_name]
		confirm.confirmed.connect(func():
			_service.remove_category(cat_name)
			_refresh_list()
			categories_changed.emit()
		)
		add_child(confirm)
		confirm.popup_centered()
	else:
		_service.remove_category(cat_name)
		_refresh_list()
		categories_changed.emit()


func _on_close() -> void:
	hide()
