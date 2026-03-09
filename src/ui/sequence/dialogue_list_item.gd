extends PanelContainer

## Item de dialogue dans la liste — supporte le drag & drop.

var _index: int = -1
var _dialogue = null
var _seq_editor = null
var _list_panel = null
var _highlighted: bool = false
var _char_edit: LineEdit = null
var _text_edit: LineEdit = null

func setup(index: int, dialogue, seq_editor, list_panel) -> void:
	_index = index
	_dialogue = dialogue
	_seq_editor = seq_editor
	_list_panel = list_panel
	_build_ui()

func _build_ui() -> void:
	custom_minimum_size.y = 60

	var hbox = HBoxContainer.new()
	add_child(hbox)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)

	_char_edit = LineEdit.new()
	_char_edit.text = _dialogue.character
	_char_edit.placeholder_text = "Personnage"
	_char_edit.text_changed.connect(_on_character_changed)
	vbox.add_child(_char_edit)

	_text_edit = LineEdit.new()
	_text_edit.text = _dialogue.text
	_text_edit.placeholder_text = "Texte du dialogue"
	_text_edit.text_changed.connect(_on_text_changed)
	vbox.add_child(_text_edit)

	var select_btn = Button.new()
	select_btn.text = "→"
	select_btn.pressed.connect(func(): _list_panel.select_item(_index))
	hbox.add_child(select_btn)

	var delete_btn = Button.new()
	delete_btn.text = "🗑"
	delete_btn.pressed.connect(func(): _list_panel.request_delete(_index))
	hbox.add_child(delete_btn)

func _on_character_changed(new_text: String) -> void:
	if _seq_editor and _dialogue:
		_seq_editor.modify_dialogue(_index, new_text, _dialogue.text)
		_dialogue.character = new_text

func _on_text_changed(new_text: String) -> void:
	if _seq_editor and _dialogue:
		_seq_editor.modify_dialogue(_index, _dialogue.character, new_text)
		_dialogue.text = new_text

# --- Accesseurs ---

func get_character_text() -> String:
	return _dialogue.character if _dialogue else ""

func get_dialogue_text() -> String:
	return _dialogue.text if _dialogue else ""

func set_character_text(value: String) -> void:
	if _char_edit:
		_char_edit.text = value
		_on_character_changed(value)

func set_dialogue_text(value: String) -> void:
	if _text_edit:
		_text_edit.text = value
		_on_text_changed(value)

func is_highlighted() -> bool:
	return _highlighted

func set_highlighted(value: bool) -> void:
	_highlighted = value
	if _highlighted:
		modulate = Color(0.8, 0.9, 1.0)
	else:
		modulate = Color.WHITE

# --- Drag & Drop ---

func _get_drag_data(_at_position: Vector2):
	var preview = Label.new()
	preview.text = _dialogue.character if _dialogue else "?"
	if get_viewport() and get_viewport().gui_is_dragging():
		set_drag_preview(preview)
	return {"type": "dialogue_reorder", "index": _index}

func _can_drop_data(_at_position: Vector2, data) -> bool:
	if data is Dictionary and data.get("type") == "dialogue_reorder":
		return true
	return false

func _drop_data(_at_position: Vector2, data) -> void:
	if data is Dictionary and data.get("type") == "dialogue_reorder":
		var from_index = data["index"]
		if _list_panel:
			_list_panel.on_drop_reorder(from_index, _index)

# --- Click to select ---

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _list_panel:
			_list_panel.select_item(_index)
