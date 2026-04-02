# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends Control

## Overlay plein écran pour prévisualiser une image.
## Usage simple : appeler show_preview(texture, filename) pour afficher.
## Usage collection : appeler show_collection(items, start_index) pour naviguer.

signal regenerate_requested(index: int)
signal delete_requested(index: int)

var _overlay: ColorRect
var _texture_rect: TextureRect
var _filename_label: Label
var _close_btn: Button

# Navigation bar
var _nav_bar: HBoxContainer
var _prev_btn: Button
var _next_btn: Button
var _counter_label: Label
var _regenerate_btn: Button
var _delete_btn: Button

# Collection mode state
var _collection_items: Array = []  # [{texture, filename, index}]
var _current_collection_index: int = -1
var _collection_mode: bool = false
var _regenerating: bool = false

# Blink alternation
var _blink_timer: Timer
var _showing_source: bool = false

func _ready() -> void:
	visible = false
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
	_texture_rect.set_anchor_and_offset(SIDE_BOTTOM, 1, -100)
	_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_texture_rect)

	# Label nom de fichier
	_filename_label = Label.new()
	_filename_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_filename_label.set_anchors_preset(PRESET_BOTTOM_WIDE)
	_filename_label.set_anchor_and_offset(SIDE_TOP, 1, -95)
	_filename_label.set_anchor_and_offset(SIDE_BOTTOM, 1, -70)
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

	# Navigation bar (hidden by default)
	_nav_bar = HBoxContainer.new()
	_nav_bar.name = "NavBar"
	_nav_bar.set_anchors_preset(PRESET_BOTTOM_WIDE)
	_nav_bar.set_anchor_and_offset(SIDE_TOP, 1, -60)
	_nav_bar.set_anchor_and_offset(SIDE_BOTTOM, 1, -10)
	_nav_bar.set_anchor_and_offset(SIDE_LEFT, 0, 40)
	_nav_bar.set_anchor_and_offset(SIDE_RIGHT, 1, -40)
	_nav_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_nav_bar.add_theme_constant_override("separation", 12)
	_nav_bar.visible = false
	add_child(_nav_bar)

	_prev_btn = Button.new()
	_prev_btn.name = "PrevBtn"
	_prev_btn.text = tr("◀ Précédent")
	_prev_btn.pressed.connect(_on_prev_pressed)
	_nav_bar.add_child(_prev_btn)

	_counter_label = Label.new()
	_counter_label.name = "Counter"
	_counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_counter_label.custom_minimum_size.x = 80
	_nav_bar.add_child(_counter_label)

	_next_btn = Button.new()
	_next_btn.name = "NextBtn"
	_next_btn.text = tr("Suivant ▶")
	_next_btn.pressed.connect(_on_next_pressed)
	_nav_bar.add_child(_next_btn)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size.x = 40
	_nav_bar.add_child(spacer)

	_regenerate_btn = Button.new()
	_regenerate_btn.name = "RegenerateBtn"
	_regenerate_btn.text = tr("Regénérer")
	_regenerate_btn.pressed.connect(_on_regenerate_pressed)
	_nav_bar.add_child(_regenerate_btn)

	_delete_btn = Button.new()
	_delete_btn.name = "DeleteBtn"
	_delete_btn.text = tr("Supprimer")
	_delete_btn.pressed.connect(_on_delete_pressed)
	_nav_bar.add_child(_delete_btn)

	# Blink alternation timer
	_blink_timer = Timer.new()
	_blink_timer.one_shot = false
	_blink_timer.wait_time = 1.5
	_blink_timer.timeout.connect(_on_blink_timer_timeout)
	add_child(_blink_timer)


func show_preview(texture: Texture2D, filename: String) -> void:
	if texture == null:
		return
	_stop_blink_alternation()
	_collection_mode = false
	_collection_items = []
	_current_collection_index = -1
	_nav_bar.visible = false
	_texture_rect.set_anchor_and_offset(SIDE_BOTTOM, 1, -60)
	_filename_label.set_anchor_and_offset(SIDE_TOP, 1, -40)
	_filename_label.set_anchor_and_offset(SIDE_BOTTOM, 1, -10)
	_texture_rect.texture = texture
	_filename_label.text = filename
	_apply_size()
	visible = true


func show_collection(items: Array, start_index: int = 0) -> void:
	if items.is_empty():
		return
	_collection_mode = true
	_collection_items = items
	_current_collection_index = clampi(start_index, 0, items.size() - 1)
	_nav_bar.visible = true
	_texture_rect.set_anchor_and_offset(SIDE_BOTTOM, 1, -100)
	_filename_label.set_anchor_and_offset(SIDE_TOP, 1, -95)
	_filename_label.set_anchor_and_offset(SIDE_BOTTOM, 1, -70)
	_display_current_item()
	_apply_size()
	visible = true


func _apply_size() -> void:
	var parent = get_parent()
	if parent is Window:
		position = Vector2.ZERO
		size = Vector2(parent.size)
	elif parent is Control:
		position = Vector2.ZERO
		size = parent.size


func _display_current_item() -> void:
	if _current_collection_index < 0 or _current_collection_index >= _collection_items.size():
		return
	var item = _collection_items[_current_collection_index]
	_texture_rect.texture = item["texture"]
	_filename_label.text = item["filename"]
	_regenerating = false
	_regenerate_btn.disabled = false
	_delete_btn.disabled = false
	_update_nav_buttons()
	_start_blink_alternation()


func _update_nav_buttons() -> void:
	var total = _collection_items.size()
	_counter_label.text = "%d / %d" % [_current_collection_index + 1, total]
	_prev_btn.disabled = (_current_collection_index <= 0)
	_next_btn.disabled = (_current_collection_index >= total - 1)


func _start_blink_alternation() -> void:
	_showing_source = false
	if _current_collection_index >= 0 and _current_collection_index < _collection_items.size():
		var item = _collection_items[_current_collection_index]
		if item.has("source_texture") and item["source_texture"] != null:
			_regenerate_btn.visible = true
			_delete_btn.visible = true
			_blink_timer.start()
			return
	_blink_timer.stop()


func _stop_blink_alternation() -> void:
	_blink_timer.stop()
	_showing_source = false
	_regenerate_btn.visible = true
	_delete_btn.visible = true


func _on_blink_timer_timeout() -> void:
	if _current_collection_index < 0 or _current_collection_index >= _collection_items.size():
		_blink_timer.stop()
		return
	var item = _collection_items[_current_collection_index]
	if not item.has("source_texture") or item["source_texture"] == null:
		_blink_timer.stop()
		return
	_showing_source = not _showing_source
	if _showing_source:
		_texture_rect.texture = item["source_texture"]
		_filename_label.text = item["filename"] + " — Original"
		_regenerate_btn.visible = false
		_delete_btn.visible = false
	else:
		_texture_rect.texture = item["texture"]
		_filename_label.text = item["filename"]
		_regenerate_btn.visible = true
		_delete_btn.visible = true


func _on_prev_pressed() -> void:
	if _current_collection_index > 0:
		_current_collection_index -= 1
		_display_current_item()


func _on_next_pressed() -> void:
	if _current_collection_index < _collection_items.size() - 1:
		_current_collection_index += 1
		_display_current_item()


func _on_regenerate_pressed() -> void:
	if _current_collection_index < 0 or _current_collection_index >= _collection_items.size():
		return
	_stop_blink_alternation()
	var item = _collection_items[_current_collection_index]
	var original_index = item["index"]
	_regenerating = true
	_texture_rect.texture = null
	_filename_label.text = item["filename"] + tr(" — En cours...")
	_regenerate_btn.disabled = true
	_delete_btn.disabled = true
	regenerate_requested.emit(original_index)


func update_current_image(texture: Texture2D) -> void:
	if not visible or not _collection_mode or _current_collection_index < 0:
		return
	if _current_collection_index >= _collection_items.size():
		return
	_collection_items[_current_collection_index]["texture"] = texture
	_texture_rect.texture = texture
	_filename_label.text = _collection_items[_current_collection_index]["filename"]
	_regenerating = false
	_regenerate_btn.disabled = false
	_delete_btn.disabled = false
	_start_blink_alternation()


func _on_delete_pressed() -> void:
	if _current_collection_index < 0 or _current_collection_index >= _collection_items.size():
		return
	var item = _collection_items[_current_collection_index]
	var original_index = item["index"]
	_collection_items.remove_at(_current_collection_index)

	if _collection_items.is_empty():
		_close()
		delete_requested.emit(original_index)
		return

	# Adjust current index if needed
	if _current_collection_index >= _collection_items.size():
		_current_collection_index = _collection_items.size() - 1
	_display_current_item()
	delete_requested.emit(original_index)


func get_current_queue_index() -> int:
	if not _collection_mode or _current_collection_index < 0 or _current_collection_index >= _collection_items.size():
		return -1
	return _collection_items[_current_collection_index]["index"]


func is_regenerating() -> bool:
	return _regenerating


func _close() -> void:
	_stop_blink_alternation()
	visible = false
	_texture_rect.texture = null
	_collection_mode = false
	_collection_items = []
	_current_collection_index = -1
	_regenerating = false
	_regenerate_btn.disabled = false
	_delete_btn.disabled = false


func _on_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close()


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				_close()
				get_viewport().set_input_as_handled()
			KEY_LEFT:
				if _collection_mode and _current_collection_index > 0:
					_on_prev_pressed()
					get_viewport().set_input_as_handled()
			KEY_RIGHT:
				if _collection_mode and _current_collection_index < _collection_items.size() - 1:
					_on_next_pressed()
					get_viewport().set_input_as_handled()