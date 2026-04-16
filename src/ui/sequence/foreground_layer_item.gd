# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends PanelContainer

## Item individuel dans le panneau calques.
## Affiche miniature, nom, z-order, visibilité, et indicateur d'héritage.

const TextureLoaderScript = preload("res://src/ui/shared/texture_loader.gd")

var _foreground = null
var _uuid: String = ""
var _is_inherited: bool = false
var _inherited_from_index: int = -1

var _drag_handle: Label
var _visibility_btn: Button
var _thumbnail: TextureRect
var _name_label: Label
var _inherited_label: Label
var _z_order_label: Label
var _color_bar: ColorRect

var _selected: bool = false

signal item_clicked(uuid: String)
signal visibility_toggled(uuid: String, is_visible: bool)
signal drag_started(uuid: String)

func setup(fg, is_inherited: bool = false, inherited_from_index: int = -1) -> void:
	_foreground = fg
	_uuid = fg.uuid
	_is_inherited = is_inherited
	_inherited_from_index = inherited_from_index

func _ready() -> void:
	custom_minimum_size = Vector2(0, 32)
	mouse_filter = MOUSE_FILTER_STOP

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	add_child(hbox)

	# Color bar (left border indicator)
	_color_bar = ColorRect.new()
	_color_bar.custom_minimum_size = Vector2(3, 0)
	_color_bar.size_flags_vertical = SIZE_EXPAND_FILL
	hbox.add_child(_color_bar)

	# Drag handle
	_drag_handle = Label.new()
	_drag_handle.text = "☰"
	_drag_handle.add_theme_font_size_override("font_size", 14)
	hbox.add_child(_drag_handle)

	# Visibility toggle
	_visibility_btn = Button.new()
	_visibility_btn.text = "👁"
	_visibility_btn.toggle_mode = true
	_visibility_btn.button_pressed = true
	_visibility_btn.flat = true
	_visibility_btn.custom_minimum_size = Vector2(24, 0)
	_visibility_btn.toggled.connect(_on_visibility_toggled)
	hbox.add_child(_visibility_btn)

	# Thumbnail
	_thumbnail = TextureRect.new()
	_thumbnail.custom_minimum_size = Vector2(24, 24)
	_thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_thumbnail.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	hbox.add_child(_thumbnail)

	# Name + inheritance info
	var name_vbox = VBoxContainer.new()
	name_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	name_vbox.add_theme_constant_override("separation", 0)
	hbox.add_child(name_vbox)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 12)
	name_vbox.add_child(_name_label)

	_inherited_label = Label.new()
	_inherited_label.add_theme_font_size_override("font_size", 9)
	_inherited_label.add_theme_color_override("font_color", Color("#ffaa00"))
	_inherited_label.visible = false
	name_vbox.add_child(_inherited_label)

	# Z-order
	_z_order_label = Label.new()
	_z_order_label.add_theme_font_size_override("font_size", 11)
	_z_order_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	hbox.add_child(_z_order_label)

	# Apply data
	_apply_data()

	# Click handler
	gui_input.connect(_on_gui_input)


func _apply_data() -> void:
	if _foreground == null:
		return

	if _foreground.fg_name != "" and not _foreground.image.ends_with(".apng"):
		_name_label.text = _foreground.fg_name
	else:
		_name_label.text = _foreground.image.get_file().get_basename()
	_z_order_label.text = "z:%d" % _foreground.z_order

	# Load thumbnail
	if _foreground.image != "":
		var tex = TextureLoaderScript.load_texture(_foreground.image)
		if tex:
			_thumbnail.texture = tex

	# Inheritance styling
	if _is_inherited:
		if _inherited_from_index >= 0:
			_inherited_label.text = tr("hérité du dialogue #%d") % (_inherited_from_index + 1)
		else:
			_inherited_label.text = tr("hérité de la séquence")
		_inherited_label.visible = true
		_name_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_color_bar.color = Color("#ffaa00")
		modulate.a = 0.6
		_drag_handle.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
	else:
		_inherited_label.visible = false
		_color_bar.color = _get_fg_color()
		modulate.a = 1.0


func set_selected(selected: bool) -> void:
	_selected = selected
	if _selected:
		add_theme_stylebox_override("panel", _create_selected_style())
	else:
		remove_theme_stylebox_override("panel")


func _create_selected_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.29, 0.29, 1.0, 0.15)
	style.border_color = Color(0.29, 0.29, 1.0, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	return style


func _get_fg_color() -> Color:
	# Generate a deterministic color from UUID
	var hash_val = _uuid.hash()
	var h = fmod(abs(float(hash_val)) / 1000000.0, 1.0)
	return Color.from_hsv(h, 0.6, 0.8)


func _on_visibility_toggled(pressed: bool) -> void:
	_visibility_btn.text = "👁" if pressed else "⊘"
	visibility_toggled.emit(_uuid, pressed)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		item_clicked.emit(_uuid)


func get_uuid() -> String:
	return _uuid


func is_inherited() -> bool:
	return _is_inherited


func _get_drag_data(_at_position: Vector2):
	if _is_inherited:
		return null
	var preview = Label.new()
	preview.text = _foreground.fg_name
	set_drag_preview(preview)
	return {"type": "foreground_layer", "uuid": _uuid, "foreground": _foreground}