extends VBoxContainer

## Section d'édition du dialogue sélectionné (personnage + texte).
## Affichée en haut du panneau droit de l'éditeur de séquence.

var _header_label: Label
var _character_edit: LineEdit
var _text_edit: TextEdit
var _delete_button: Button
var _dialogue_index: int = -1
var _updating: bool = false

signal dialogue_character_changed(index: int, character: String)
signal dialogue_text_changed(index: int, text: String)
signal dialogue_delete_requested(index: int)

func _ready() -> void:
	add_theme_constant_override("separation", 4)

	# Header
	var header_row = HBoxContainer.new()
	add_child(header_row)

	_header_label = Label.new()
	_header_label.text = "Dialogue"
	_header_label.add_theme_font_size_override("font_size", 12)
	_header_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	header_row.add_child(_header_label)

	var spacer = Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	header_row.add_child(spacer)

	_delete_button = Button.new()
	_delete_button.text = "Supprimer"
	_delete_button.pressed.connect(_on_delete_pressed)
	header_row.add_child(_delete_button)

	# Character
	var char_row = HBoxContainer.new()
	add_child(char_row)

	var char_label = Label.new()
	char_label.text = "Personnage"
	char_label.custom_minimum_size = Vector2(80, 0)
	char_row.add_child(char_label)

	_character_edit = LineEdit.new()
	_character_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	_character_edit.placeholder_text = "Nom du personnage"
	_character_edit.text_changed.connect(_on_character_changed)
	char_row.add_child(_character_edit)

	# Text
	var text_label = Label.new()
	text_label.text = "Texte"
	add_child(text_label)

	_text_edit = TextEdit.new()
	_text_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	_text_edit.custom_minimum_size = Vector2(0, 60)
	_text_edit.placeholder_text = "Texte du dialogue..."
	_text_edit.text_changed.connect(_on_text_changed)
	add_child(_text_edit)


func load_dialogue(index: int, dialogue) -> void:
	_updating = true
	_dialogue_index = index
	if dialogue == null:
		_header_label.text = "Aucun dialogue sélectionné"
		_character_edit.text = ""
		_text_edit.text = ""
		_character_edit.editable = false
		_text_edit.editable = false
		_delete_button.visible = false
	else:
		_header_label.text = "Dialogue #%d" % (index + 1)
		_character_edit.text = dialogue.character
		_text_edit.text = dialogue.text
		_character_edit.editable = true
		_text_edit.editable = true
		_delete_button.visible = true
	_updating = false


func clear() -> void:
	load_dialogue(-1, null)


func _on_character_changed(new_text: String) -> void:
	if _updating or _dialogue_index < 0:
		return
	dialogue_character_changed.emit(_dialogue_index, new_text)


func _on_text_changed() -> void:
	if _updating or _dialogue_index < 0:
		return
	dialogue_text_changed.emit(_dialogue_index, _text_edit.text)


func _on_delete_pressed() -> void:
	if _dialogue_index < 0:
		return
	dialogue_delete_requested.emit(_dialogue_index)
