extends Control

## Éditeur visuel de séquence — gère le background, les foregrounds et le système d'ancrage.
## Fournit à la fois le contrôleur data et la couche visuelle (zoom/pan, background, foregrounds interactifs).

const ForegroundScript = preload("res://src/models/foreground.gd")

var _sequence = null

# --- Visual layer ---
var _canvas: Control
var _bg_rect: TextureRect
var _fg_container: Control
var _zoom: float = 1.0
var _pan_offset: Vector2 = Vector2.ZERO
var _is_panning: bool = false

# --- Foreground interaction ---
var _fg_visual_map: Dictionary = {}   # uuid → Control wrapper
var _selected_fg_uuid: String = ""
var _dragging_fg: bool = false
var _resizing_fg: bool = false
var _drag_start_pos: Vector2 = Vector2.ZERO
var _drag_start_wrapper_pos: Vector2 = Vector2.ZERO
var _resize_start_pos: Vector2 = Vector2.ZERO
var _resize_start_scale: float = 1.0

signal foreground_selected(uuid: String)
signal foreground_deselected()

func _ready() -> void:
	clip_contents = true

	_canvas = Control.new()
	_canvas.name = "Canvas"
	add_child(_canvas)

	_bg_rect = TextureRect.new()
	_bg_rect.name = "BackgroundRect"
	_bg_rect.visible = false
	_bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_bg_rect)

	_fg_container = Control.new()
	_fg_container.name = "ForegroundContainer"
	_fg_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_fg_container)

	_apply_transform()

# --- Zoom / Pan ---

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom(_zoom * 1.1, mb.position)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom(_zoom / 1.1, mb.position)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_is_panning = mb.pressed
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			# Click on empty space → deselect
			_deselect_foreground()
	elif event is InputEventMouseMotion and _is_panning:
		var mm := event as InputEventMouseMotion
		_pan_offset += mm.relative
		_apply_transform()
		accept_event()

func _set_zoom(new_zoom: float, pivot: Vector2 = Vector2.ZERO) -> void:
	var old_zoom = _zoom
	_zoom = clampf(new_zoom, 0.1, 5.0)
	# Zoom towards pivot point
	if old_zoom != _zoom:
		_pan_offset = pivot - (pivot - _pan_offset) * (_zoom / old_zoom)
		_apply_transform()

func _apply_transform() -> void:
	if _canvas == null:
		return
	_canvas.position = _pan_offset
	_canvas.scale = Vector2(_zoom, _zoom)

# --- Input for Delete key ---

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_DELETE:
		if _selected_fg_uuid != "":
			remove_foreground(_selected_fg_uuid)
			_deselect_foreground()
			get_viewport().set_input_as_handled()

# --- Background visual ---

func _update_visual() -> void:
	if _bg_rect == null:
		return
	if _sequence == null or _sequence.background == "":
		_bg_rect.visible = false
		return
	var tex = _load_texture(_sequence.background)
	if tex:
		_bg_rect.texture = tex
		_bg_rect.visible = true
	else:
		_bg_rect.visible = false

func _load_texture(path: String):
	if path == "":
		return null
	# Try as Godot resource first
	if ResourceLoader.exists(path):
		return load(path)
	# Try as external file
	if not FileAccess.file_exists(path):
		return null
	var img = Image.new()
	var err = img.load(path)
	if err != OK:
		return null
	return ImageTexture.create_from_image(img)

# --- Foreground visuals ---

func _update_foreground_visuals() -> void:
	if _fg_container == null:
		return

	if _sequence == null:
		# Clear all visuals
		for key in _fg_visual_map.keys():
			if is_instance_valid(_fg_visual_map[key]):
				_fg_visual_map[key].queue_free()
		_fg_visual_map.clear()
		return

	# Collect current UUIDs
	var current_uuids := {}
	for fg in _sequence.foregrounds:
		current_uuids[fg.uuid] = fg

	# Remove orphan wrappers
	for uuid in _fg_visual_map.keys():
		if not current_uuids.has(uuid):
			if is_instance_valid(_fg_visual_map[uuid]):
				_fg_visual_map[uuid].queue_free()
			_fg_visual_map.erase(uuid)

	# Create or update wrappers
	for fg in _sequence.foregrounds:
		if not _fg_visual_map.has(fg.uuid):
			_create_fg_visual(fg)
		_update_single_fg_visual(fg)

func _create_fg_visual(fg) -> void:
	var wrapper = Control.new()
	wrapper.name = "FG_" + fg.uuid.left(8)
	wrapper.mouse_filter = Control.MOUSE_FILTER_STOP
	wrapper.gui_input.connect(_on_fg_gui_input.bind(fg.uuid))

	var tex_rect = TextureRect.new()
	tex_rect.name = "Texture"
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.add_child(tex_rect)

	var border = ColorRect.new()
	border.name = "SelectionBorder"
	border.color = Color(0.2, 0.6, 1.0, 0.5)
	border.visible = false
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.add_child(border)

	var handle = ColorRect.new()
	handle.name = "ResizeHandle"
	handle.custom_minimum_size = Vector2(20, 20)
	handle.size = Vector2(20, 20)
	handle.color = Color(1.0, 1.0, 1.0, 0.9)
	handle.visible = false
	handle.mouse_filter = Control.MOUSE_FILTER_STOP
	handle.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	handle.gui_input.connect(_on_resize_handle_input.bind(fg.uuid))
	wrapper.add_child(handle)

	_fg_container.add_child(wrapper)
	_fg_visual_map[fg.uuid] = wrapper

func _update_single_fg_visual(fg) -> void:
	if not _fg_visual_map.has(fg.uuid):
		return
	var wrapper: Control = _fg_visual_map[fg.uuid]
	if not is_instance_valid(wrapper):
		return

	# Load texture
	var tex_rect: TextureRect = wrapper.get_node("Texture")
	var tex = _load_texture(fg.image)
	if tex:
		tex_rect.texture = tex
		var fg_size = tex.get_size() * fg.scale
		tex_rect.size = fg_size
		tex_rect.flip_h = fg.flip_h
		tex_rect.flip_v = fg.flip_v
		wrapper.size = fg_size
	else:
		# Placeholder size for testing / missing images
		var fg_size = Vector2(100, 100) * fg.scale
		tex_rect.size = fg_size
		wrapper.size = fg_size

	# Position via anchor system
	var bg_size = Vector2(1920, 1080)  # default
	if _bg_rect and _bg_rect.texture:
		bg_size = _bg_rect.texture.get_size()
	var fg_size = wrapper.size
	wrapper.position = fg.anchor_bg * bg_size - fg.anchor_fg * fg_size

	# Opacity
	wrapper.modulate.a = fg.opacity

	# Selection border
	var border: ColorRect = wrapper.get_node("SelectionBorder")
	border.visible = (_selected_fg_uuid == fg.uuid)
	border.size = wrapper.size

	# Resize handle
	var handle: ColorRect = wrapper.get_node("ResizeHandle")
	handle.visible = (_selected_fg_uuid == fg.uuid)
	handle.position = wrapper.size - Vector2(20, 20)

# --- Foreground interaction ---

func _select_foreground(uuid: String) -> void:
	_selected_fg_uuid = uuid
	foreground_selected.emit(uuid)
	_update_foreground_visuals()

func _deselect_foreground() -> void:
	if _selected_fg_uuid != "":
		_selected_fg_uuid = ""
		foreground_deselected.emit()
		_update_foreground_visuals()

func _on_fg_gui_input(event: InputEvent, uuid: String) -> void:
	# Ne pas démarrer le drag si on est en train de resize
	if _resizing_fg:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_select_foreground(uuid)
				_dragging_fg = true
				_drag_start_pos = mb.global_position
				var wrapper = _fg_visual_map.get(uuid)
				if wrapper:
					_drag_start_wrapper_pos = wrapper.position
				accept_event()
			else:
				_dragging_fg = false
	elif event is InputEventMouseMotion and _dragging_fg and _selected_fg_uuid == uuid:
		var mm := event as InputEventMouseMotion
		var wrapper = _fg_visual_map.get(uuid)
		if wrapper:
			var delta = (mm.global_position - _drag_start_pos) / _zoom
			wrapper.position = _drag_start_wrapper_pos + delta
			# Recompute anchor_bg from new position
			var fg = find_foreground(uuid)
			if fg:
				var bg_size = Vector2(1920, 1080)
				if _bg_rect and _bg_rect.texture:
					bg_size = _bg_rect.texture.get_size()
				var fg_size = wrapper.size
				fg.anchor_bg = (wrapper.position + fg.anchor_fg * fg_size) / bg_size
		accept_event()

func _on_resize_handle_input(event: InputEvent, uuid: String) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_resizing_fg = true
				_dragging_fg = false  # Empêcher le drag pendant le resize
				_resize_start_pos = mb.global_position
				var fg = find_foreground(uuid)
				if fg:
					_resize_start_scale = fg.scale
			else:
				_resizing_fg = false
			accept_event()
	elif event is InputEventMouseMotion and _resizing_fg:
		var mm := event as InputEventMouseMotion
		var fg = find_foreground(uuid)
		if fg:
			var delta_x = (mm.global_position.x - _resize_start_pos.x) / _zoom
			var base_width = 100.0
			var tex_rect_node = _fg_visual_map.get(uuid)
			if tex_rect_node:
				var tex = tex_rect_node.get_node("Texture").texture
				if tex:
					base_width = tex.get_size().x
			fg.scale = maxf(0.1, _resize_start_scale + delta_x / base_width)
			_update_foreground_visuals()
		accept_event()

# --- Data controller (existing API, unchanged) ---

func load_sequence(sequence) -> void:
	_sequence = sequence
	_update_visual()
	_update_foreground_visuals()

func get_sequence():
	return _sequence

func get_background() -> String:
	if _sequence == null:
		return ""
	return _sequence.background

func set_background(path: String) -> void:
	if _sequence == null:
		return
	_sequence.background = path
	_update_visual()

func add_foreground(fg_name: String, image: String) -> void:
	if _sequence == null:
		return
	var fg = ForegroundScript.new()
	fg.fg_name = fg_name
	fg.image = image
	_sequence.foregrounds.append(fg)
	_update_foreground_visuals()

func remove_foreground(uuid: String) -> void:
	if _sequence == null:
		return
	for i in range(_sequence.foregrounds.size()):
		if _sequence.foregrounds[i].uuid == uuid:
			_sequence.foregrounds.remove_at(i)
			break
	# Clean up visual
	if _fg_visual_map.has(uuid):
		if is_instance_valid(_fg_visual_map[uuid]):
			_fg_visual_map[uuid].queue_free()
		_fg_visual_map.erase(uuid)

func get_foreground_count() -> int:
	if _sequence == null:
		return 0
	return _sequence.foregrounds.size()

func find_foreground(uuid: String):
	if _sequence == null:
		return null
	for fg in _sequence.foregrounds:
		if fg.uuid == uuid:
			return fg
	return null

func update_foreground_property(uuid: String, property: String, value) -> void:
	var fg = find_foreground(uuid)
	if fg == null:
		return
	fg.set(property, value)

func set_foreground_anchor_bg(uuid: String, anchor: Vector2) -> void:
	var fg = find_foreground(uuid)
	if fg == null:
		return
	fg.anchor_bg = anchor

func set_foreground_anchor_fg(uuid: String, anchor: Vector2) -> void:
	var fg = find_foreground(uuid)
	if fg == null:
		return
	fg.anchor_fg = anchor

func compute_foreground_position(uuid: String, bg_size: Vector2, fg_size: Vector2) -> Vector2:
	var fg = find_foreground(uuid)
	if fg == null:
		return Vector2.ZERO
	return fg.anchor_bg * bg_size - fg.anchor_fg * fg_size

func get_foreground_node(uuid: String):
	if _fg_visual_map.has(uuid) and is_instance_valid(_fg_visual_map[uuid]):
		return _fg_visual_map[uuid]
	return null

func get_foregrounds_sorted() -> Array:
	if _sequence == null:
		return []
	var sorted = _sequence.foregrounds.duplicate()
	sorted.sort_custom(func(a, b): return a.z_order < b.z_order)
	return sorted
