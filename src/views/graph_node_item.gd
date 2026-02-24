extends GraphNode

## Noeud de graphe réutilisable pour chapitres, scènes et séquences.

signal double_clicked(uuid: String)
signal rename_requested(uuid: String)

var _uuid: String = ""
var _item_name: String = ""
var _subtitle: String = ""
var _popup_menu: PopupMenu

func setup(uuid: String, item_name: String, pos: Vector2, subtitle: String = "") -> void:
	_uuid = uuid
	_item_name = item_name
	_subtitle = subtitle
	title = item_name
	position_offset = pos
	name = uuid

	# Ajouter un label comme contenu (requis pour avoir un slot)
	var label = Label.new()
	label.text = subtitle if subtitle != "" else item_name
	label.name = "ContentLabel"
	add_child(label)

	# Activer les ports d'entrée (gauche) et de sortie (droite)
	set_slot_enabled_left(0, true)
	set_slot_color_left(0, Color.WHITE)
	set_slot_enabled_right(0, true)
	set_slot_color_right(0, Color.WHITE)

	# Menu contextuel
	_popup_menu = PopupMenu.new()
	_popup_menu.name = "ContextMenu"
	_popup_menu.add_item("Renommer", 0)
	_popup_menu.id_pressed.connect(_on_popup_id_pressed)
	add_child(_popup_menu)

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
	title = new_name
	if has_node("ContentLabel"):
		get_node("ContentLabel").text = _subtitle if _subtitle != "" else new_name

func set_item_name_and_subtitle(new_name: String, new_subtitle: String) -> void:
	_item_name = new_name
	_subtitle = new_subtitle
	title = new_name
	if has_node("ContentLabel"):
		get_node("ContentLabel").text = new_subtitle if new_subtitle != "" else new_name

func get_item_position() -> Vector2:
	return position_offset

func _gui_input(event: InputEvent) -> void:
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
