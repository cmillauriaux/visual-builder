extends GraphNode

## Noeud de graphe réutilisable pour chapitres, scènes et séquences.

signal double_clicked(uuid: String)
signal rename_requested(uuid: String)
signal delete_requested(uuid: String)
signal entry_point_toggled(uuid: String, checked: bool)

var _uuid: String = ""
var _item_name: String = ""
var _subtitle: String = ""
var _is_entry_point: bool = false
var _is_terminal: bool = false
var _is_choice_sequence: bool = false
var _choice_count: int = 0
var _popup_menu: PopupMenu

func setup(uuid: String, item_name: String, pos: Vector2, subtitle: String = "", is_terminal: bool = false) -> void:
	_uuid = uuid
	_item_name = item_name
	_subtitle = subtitle
	_is_terminal = is_terminal
	title = item_name
	position_offset = pos
	name = uuid

	# Ajouter un label comme contenu (requis pour avoir un slot)
	var label = Label.new()
	label.text = subtitle if subtitle != "" else item_name
	label.name = "ContentLabel"
	add_child(label)

	# Activer le port d'entrée (gauche) toujours
	set_slot_enabled_left(0, true)
	set_slot_color_left(0, Color.WHITE)

	if not is_terminal:
		# Port de sortie (droite) uniquement pour les nœuds non-terminaux
		set_slot_enabled_right(0, true)
		set_slot_color_right(0, Color.WHITE)

		# Menu contextuel
		_popup_menu = PopupMenu.new()
		_popup_menu.name = "ContextMenu"
		_popup_menu.add_item("Renommer", 0)
		_popup_menu.add_check_item("Point d'entrée", 1)
		_popup_menu.add_separator()
		_popup_menu.add_item("Supprimer", 2)
		_popup_menu.id_pressed.connect(_on_popup_id_pressed)
		add_child(_popup_menu)

func setup_as_choice_sequence(uuid: String, item_name: String, pos: Vector2, subtitle: String, choices: Array) -> void:
	_uuid = uuid
	_item_name = item_name
	_subtitle = subtitle
	_is_choice_sequence = true
	_choice_count = choices.size()
	title = item_name
	position_offset = pos
	name = uuid

	# Slot 0 : entrée uniquement, pas de sortie
	var label = Label.new()
	label.text = subtitle if subtitle != "" else ""
	label.name = "ContentLabel"
	add_child(label)
	set_slot_enabled_left(0, true)
	set_slot_color_left(0, Color.WHITE)
	set_slot_enabled_right(0, false)

	# Un slot de sortie par choix
	for i in range(choices.size()):
		var text = choices[i].text if choices[i].text != "" else "Choix %d" % (i + 1)
		if text.length() > 35:
			text = text.left(33) + "…"
		var clabel = Label.new()
		clabel.text = text
		clabel.name = "ChoiceLabel_%d" % i
		add_child(clabel)
		set_slot_enabled_left(i + 1, false)
		set_slot_enabled_right(i + 1, true)
		set_slot_color_right(i + 1, Color(0.0, 0.9, 0.2))

	# Menu contextuel
	_popup_menu = PopupMenu.new()
	_popup_menu.name = "ContextMenu"
	_popup_menu.add_item("Renommer", 0)
	_popup_menu.add_check_item("Point d'entrée", 1)
	_popup_menu.add_separator()
	_popup_menu.add_item("Supprimer", 2)
	_popup_menu.id_pressed.connect(_on_popup_id_pressed)
	add_child(_popup_menu)

func is_choice_sequence_node() -> bool:
	return _is_choice_sequence

func get_choice_count() -> int:
	return _choice_count

func get_item_uuid() -> String:
	return _uuid

func get_item_name() -> String:
	return _item_name

func get_subtitle() -> String:
	return _subtitle

func set_subtitle(value: String) -> void:
	_subtitle = value
	if has_node("ContentLabel"):
		get_node("ContentLabel").text = value if value != "" else _item_name

func set_item_name(new_name: String) -> void:
	_item_name = new_name
	_update_title_display()
	if has_node("ContentLabel"):
		get_node("ContentLabel").text = _subtitle if _subtitle != "" else new_name

func set_item_name_and_subtitle(new_name: String, new_subtitle: String) -> void:
	_item_name = new_name
	_subtitle = new_subtitle
	_update_title_display()
	if has_node("ContentLabel"):
		get_node("ContentLabel").text = new_subtitle if new_subtitle != "" else new_name

func is_entry_point() -> bool:
	return _is_entry_point

func set_entry_point(value: bool) -> void:
	_is_entry_point = value
	_popup_menu.set_item_checked(_popup_menu.get_item_index(1), value)
	_update_title_display()

func _update_title_display() -> void:
	if _is_entry_point:
		title = "▶ " + _item_name
	else:
		title = _item_name

func get_item_position() -> Vector2:
	return position_offset

func _gui_input(event: InputEvent) -> void:
	if _is_terminal:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
		double_clicked.emit(_uuid)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_popup_menu.position = Vector2i(event.global_position)
		_popup_menu.reset_size()
		_popup_menu.popup()
		accept_event()

func _on_popup_id_pressed(id: int) -> void:
	if id == 0:
		rename_requested.emit(_uuid)
	elif id == 1:
		var new_checked = not _is_entry_point
		set_entry_point(new_checked)
		entry_point_toggled.emit(_uuid, new_checked)
	elif id == 2:
		delete_requested.emit(_uuid)
