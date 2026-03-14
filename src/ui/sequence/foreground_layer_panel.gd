extends VBoxContainer

## Panneau calques — liste les foregrounds du dialogue sélectionné.
## Affiche miniatures, z-order, visibilité, indicateurs d'héritage.

const ForegroundLayerItemScript = preload("res://src/ui/sequence/foreground_layer_item.gd")

var _items: Array = []
var _item_container: VBoxContainer
var _add_btn: Button
var _paste_btn: Button
var _selected_uuid: String = ""

signal foreground_clicked(uuid: String)
signal foreground_visibility_toggled(uuid: String, is_visible: bool)
signal add_foreground_requested()
signal paste_foreground_requested()
signal foreground_drag_to_timeline(fg_data, target_dialogue_index: int)

func _ready() -> void:
	add_theme_constant_override("separation", 4)

	# Header
	var header = HBoxContainer.new()
	add_child(header)

	var title = Label.new()
	title.text = "Calques"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	header.add_child(title)

	var spacer = Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(spacer)

	_add_btn = Button.new()
	_add_btn.text = "+ Ajouter"
	_add_btn.pressed.connect(func(): add_foreground_requested.emit())
	header.add_child(_add_btn)

	# Scrollable item list
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	_item_container = VBoxContainer.new()
	_item_container.size_flags_horizontal = SIZE_EXPAND_FILL
	_item_container.add_theme_constant_override("separation", 2)
	scroll.add_child(_item_container)

	# Bottom buttons
	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 4)
	add_child(btn_row)

	_paste_btn = Button.new()
	_paste_btn.text = "Coller"
	_paste_btn.pressed.connect(func(): paste_foreground_requested.emit())
	btn_row.add_child(_paste_btn)

	# Hint
	var hint = Label.new()
	hint.text = "Drag vers timeline pour copier"
	hint.add_theme_font_size_override("font_size", 9)
	hint.add_theme_color_override("font_color", Color(0.35, 0.35, 0.35))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.size_flags_horizontal = SIZE_EXPAND_FILL
	btn_row.add_child(hint)


func update_layers(foregrounds: Array, is_inherited: bool, inherited_from_index: int = -1) -> void:
	_clear_items()

	for fg in foregrounds:
		var item = ForegroundLayerItemScript.new()
		item.setup(fg, is_inherited, inherited_from_index)
		_item_container.add_child(item)
		_items.append(item)

		item.item_clicked.connect(_on_item_clicked)
		item.visibility_toggled.connect(_on_visibility_toggled)

	# Restore selection
	if _selected_uuid != "":
		_highlight_uuid(_selected_uuid)


func select_foreground(uuid: String) -> void:
	_selected_uuid = uuid
	_highlight_uuid(uuid)


func deselect_all() -> void:
	_selected_uuid = ""
	for item in _items:
		if is_instance_valid(item):
			item.set_selected(false)


func _clear_items() -> void:
	for item in _items:
		if is_instance_valid(item):
			item.queue_free()
	_items.clear()


func _highlight_uuid(uuid: String) -> void:
	for item in _items:
		if is_instance_valid(item):
			item.set_selected(item.get_uuid() == uuid)


func _on_item_clicked(uuid: String) -> void:
	_selected_uuid = uuid
	_highlight_uuid(uuid)
	foreground_clicked.emit(uuid)


func _on_visibility_toggled(uuid: String, is_visible: bool) -> void:
	foreground_visibility_toggled.emit(uuid, is_visible)
