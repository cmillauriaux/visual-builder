extends Control

## Overlay plein écran pour prévisualiser une image.
## Usage : appeler show_preview(texture, filename) pour afficher.

var _overlay: ColorRect
var _texture_rect: TextureRect
var _filename_label: Label
var _close_btn: Button

func _ready() -> void:
	visible = false
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Overlay sombre
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(PRESET_FULL_RECT)
	_overlay.color = Color(0, 0, 0, 0.7)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.gui_input.connect(_on_overlay_input)
	add_child(_overlay)

	# Image centrée avec marges
	_texture_rect = TextureRect.new()
	_texture_rect.set_anchors_preset(PRESET_FULL_RECT)
	_texture_rect.set_anchor_and_offset(SIDE_LEFT, 0, 40)
	_texture_rect.set_anchor_and_offset(SIDE_RIGHT, 1, -40)
	_texture_rect.set_anchor_and_offset(SIDE_TOP, 0, 40)
	_texture_rect.set_anchor_and_offset(SIDE_BOTTOM, 1, -60)
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_texture_rect)

	# Label nom de fichier en bas
	_filename_label = Label.new()
	_filename_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_filename_label.set_anchors_preset(PRESET_BOTTOM_WIDE)
	_filename_label.set_anchor_and_offset(SIDE_TOP, 1, -40)
	_filename_label.set_anchor_and_offset(SIDE_BOTTOM, 1, -10)
	_filename_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_filename_label)

	# Bouton fermer
	_close_btn = Button.new()
	_close_btn.text = "✕"
	_close_btn.set_anchors_preset(PRESET_TOP_RIGHT)
	_close_btn.set_anchor_and_offset(SIDE_LEFT, 1, -40)
	_close_btn.set_anchor_and_offset(SIDE_RIGHT, 1, -8)
	_close_btn.set_anchor_and_offset(SIDE_TOP, 0, 8)
	_close_btn.set_anchor_and_offset(SIDE_BOTTOM, 0, 40)
	_close_btn.pressed.connect(_close)
	add_child(_close_btn)

func show_preview(texture: Texture2D, filename: String) -> void:
	if texture == null:
		return
	_texture_rect.texture = texture
	_filename_label.text = filename
	# Force size to match parent Window's content area
	var win = get_window()
	if win:
		position = Vector2.ZERO
		size = win.size
	visible = true

func _close() -> void:
	visible = false
	_texture_rect.texture = null

func _on_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close()

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close()
		get_viewport().set_input_as_handled()
