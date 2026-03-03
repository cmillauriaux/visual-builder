extends Control

## Éditeur visuel de séquence — gère le background, les foregrounds et le système d'ancrage.
## Fournit à la fois le contrôleur data et la couche visuelle (zoom/pan, background, foregrounds interactifs).

const ForegroundScript = preload("res://src/models/foreground.gd")
const PlacementGridScript = preload("res://src/ui/visual/placement_grid.gd")
const ForegroundClipboardScript = preload("res://src/ui/visual/foreground_clipboard.gd")
const TextureLoaderScript = preload("res://src/ui/shared/texture_loader.gd")

const DESIGN_RESOLUTION = Vector2(1920, 1080)

var _sequence = null

# --- Visual layer ---
var _letterbox_bg: ColorRect
var _canvas: Control
var _bg_color_rect: ColorRect
var _bg_rect: TextureRect
var _grid_overlay: Control
var _fg_container: Control
var _overlay_container: Control
var _zoom: float = 1.0
var _pan_offset: Vector2 = Vector2.ZERO
var _is_panning: bool = false
var _auto_fit_enabled: bool = true

# --- Grid & Snapping ---
var _placement_grid = PlacementGridScript.new()
var _grid_visible: bool = false
var _snap_enabled: bool = false

# --- Foreground clipboard ---
var _fg_clipboard = ForegroundClipboardScript.new()

# --- Foreground interaction ---
var _fg_visual_map: Dictionary = {}   # uuid → Control wrapper
var _selected_fg_uuid: String = ""
var _dragging_fg: bool = false
var _resizing_fg: bool = false
var _drag_start_pos: Vector2 = Vector2.ZERO
var _drag_start_wrapper_pos: Vector2 = Vector2.ZERO
var _resize_start_pos: Vector2 = Vector2.ZERO
var _resize_start_scale: float = 1.0

# --- Context menu ---
var _context_menu: PopupMenu = null
var _context_menu_uuid: String = ""

signal foreground_selected(uuid: String)
signal foreground_deselected()

func _ready() -> void:
	clip_contents = true

	# Letterbox background — black rect covering entire editor area
	_letterbox_bg = ColorRect.new()
	_letterbox_bg.name = "LetterboxBackground"
	_letterbox_bg.color = Color(0, 0, 0, 1)
	_letterbox_bg.set_anchors_preset(PRESET_FULL_RECT)
	_letterbox_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_letterbox_bg)

	_canvas = Control.new()
	_canvas.name = "Canvas"
	_canvas.size = DESIGN_RESOLUTION
	add_child(_canvas)

	_bg_color_rect = ColorRect.new()
	_bg_color_rect.name = "BackgroundColorRect"
	_bg_color_rect.color = Color(0, 0, 0, 0)
	_bg_color_rect.set_anchors_preset(PRESET_FULL_RECT)
	_bg_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_bg_color_rect)

	_bg_rect = TextureRect.new()
	_bg_rect.name = "BackgroundRect"
	_bg_rect.visible = false
	_bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg_rect.set_anchors_preset(PRESET_FULL_RECT)
	_canvas.add_child(_bg_rect)

	_grid_overlay = Control.new()
	_grid_overlay.name = "GridOverlay"
	_grid_overlay.visible = false
	_grid_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid_overlay.set_anchors_preset(PRESET_FULL_RECT)
	_grid_overlay.draw.connect(_on_grid_draw)
	_canvas.add_child(_grid_overlay)

	_fg_container = Control.new()
	_fg_container.name = "ForegroundContainer"
	_fg_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fg_container.size = DESIGN_RESOLUTION
	_canvas.add_child(_fg_container)

	# Overlay container — positioned/sized to match the canvas screen rect
	_overlay_container = Control.new()
	_overlay_container.name = "OverlayContainer"
	_overlay_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay_container)

	_context_menu = PopupMenu.new()
	_context_menu.name = "ForegroundContextMenu"
	_context_menu.add_item("Supprimer", 0)
	_context_menu.add_item("Copier les paramètres", 1)
	_context_menu.add_item("Coller les paramètres", 2)
	_context_menu.id_pressed.connect(_on_context_menu_id_pressed)
	_update_context_menu_state()
	add_child(_context_menu)

	EventBus.play_started.connect(_on_play_started)

	resized.connect(_on_resized)
	_apply_transform()

func _on_play_started(_mode: String) -> void:
	_deselect_foreground()

# --- Auto-fit ---

func compute_auto_fit() -> Dictionary:
	var available = self.size
	if available.x <= 0 or available.y <= 0:
		return {"zoom": 1.0, "pan": Vector2.ZERO}
	var zoom_x = available.x / DESIGN_RESOLUTION.x
	var zoom_y = available.y / DESIGN_RESOLUTION.y
	var fit_zoom = minf(zoom_x, zoom_y)
	var scaled_size = DESIGN_RESOLUTION * fit_zoom
	var pan = (available - scaled_size) * 0.5
	return {"zoom": fit_zoom, "pan": pan}

func apply_auto_fit() -> void:
	if not _auto_fit_enabled:
		return
	var result = compute_auto_fit()
	_zoom = result["zoom"]
	_pan_offset = result["pan"]
	_apply_transform()

func reset_view() -> void:
	_auto_fit_enabled = true
	apply_auto_fit()

func get_canvas_rect() -> Rect2:
	return Rect2(_pan_offset, DESIGN_RESOLUTION * _zoom)

func _on_resized() -> void:
	if _auto_fit_enabled:
		apply_auto_fit()

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
			if mb.pressed:
				_auto_fit_enabled = false
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
	_auto_fit_enabled = false
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
	# Update overlay container to match canvas screen rect
	if _overlay_container != null:
		var rect = get_canvas_rect()
		_overlay_container.position = rect.position
		_overlay_container.size = rect.size

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
	if _sequence == null:
		_bg_rect.visible = false
		_bg_color_rect.color = Color(0, 0, 0, 0)
		_update_grid_overlay()
		return

	# Background color
	if _sequence.background_color != "":
		_bg_color_rect.color = Color.from_string(_sequence.background_color, Color(0, 0, 0, 0))
	else:
		_bg_color_rect.color = Color(0, 0, 0, 0)

	# Background image
	if _sequence.background == "":
		_bg_rect.visible = false
		_update_grid_overlay()
		return
	var tex = _load_texture(_sequence.background)
	if tex:
		_bg_rect.texture = tex
		_bg_rect.visible = true
	else:
		_bg_rect.visible = false
	_update_grid_overlay()

func _load_texture(path: String):
	return TextureLoaderScript.load_texture(path)

# --- Foreground visuals ---

## UUIDs dont l'opacité est gérée par une transition en cours (ne pas écraser)
var _transitioning_uuids: Array = []

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

	# Opacity — ne pas écraser si une transition gère l'alpha
	if fg.uuid not in _transitioning_uuids:
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
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_select_foreground(uuid)
			_show_context_menu(uuid, mb.global_position)
			accept_event()
			return
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
				if _dragging_fg:
					_apply_snap_to_foreground(uuid)
					_update_foreground_visuals()
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

# --- Context menu ---

func _show_context_menu(uuid: String, global_pos: Vector2) -> void:
	_context_menu_uuid = uuid
	_update_context_menu_state()
	_context_menu.position = Vector2i(global_pos)
	_context_menu.popup()

func _update_context_menu_state() -> void:
	if _context_menu == null:
		return
	var paste_idx = _context_menu.get_item_index(2)
	if paste_idx >= 0:
		_context_menu.set_item_disabled(paste_idx, not _fg_clipboard.has_data())

func _on_context_menu_id_pressed(id: int) -> void:
	if id == 0:  # Supprimer
		if _context_menu_uuid != "":
			remove_foreground(_context_menu_uuid)
			_deselect_foreground()
			_context_menu_uuid = ""
	elif id == 1:  # Copier les paramètres
		if _context_menu_uuid != "":
			_copy_foreground_params(_context_menu_uuid)
	elif id == 2:  # Coller les paramètres
		if _context_menu_uuid != "":
			_paste_foreground_params(_context_menu_uuid)

# --- Grid ---

func set_grid_visible(visible: bool) -> void:
	_grid_visible = visible
	_update_grid_overlay()

func _update_grid_overlay() -> void:
	if _grid_overlay == null:
		return
	var has_bg = _bg_rect != null and _bg_rect.visible and _bg_rect.texture != null
	_grid_overlay.visible = _grid_visible and has_bg
	if _grid_overlay.visible:
		var bg_size = _bg_rect.texture.get_size()
		_grid_overlay.size = bg_size
		_grid_overlay.queue_redraw()

func _on_grid_draw() -> void:
	if not _grid_overlay.visible:
		return
	var bg_size = _grid_overlay.size
	var color = Color(1.0, 1.0, 1.0, 0.25)
	var h_lines = _placement_grid.get_horizontal_lines(bg_size)
	var v_lines = _placement_grid.get_vertical_lines(bg_size)
	for y in h_lines:
		_grid_overlay.draw_line(Vector2(0, y), Vector2(bg_size.x, y), color, 1.0)
	for x in v_lines:
		_grid_overlay.draw_line(Vector2(x, 0), Vector2(x, bg_size.y), color, 1.0)

# --- Snapping ---

func set_snap_enabled(enabled: bool) -> void:
	_snap_enabled = enabled

func _apply_snap_to_foreground(uuid: String) -> void:
	if not _snap_enabled:
		return
	var fg = find_foreground(uuid)
	if fg == null:
		return
	var bg_size = Vector2(1920, 1080)
	if _bg_rect and _bg_rect.texture:
		bg_size = _bg_rect.texture.get_size()
	fg.anchor_bg = _placement_grid.snap_position(fg.anchor_bg, bg_size)

# --- Foreground clipboard ---

func _copy_foreground_params(uuid: String) -> void:
	var fg = find_foreground(uuid)
	if fg == null:
		return
	_fg_clipboard.copy_from(fg)

func _paste_foreground_params(uuid: String) -> void:
	var fg = find_foreground(uuid)
	if fg == null:
		return
	if _fg_clipboard.paste_to(fg):
		_update_foreground_visuals()

# --- Data controller (existing API, unchanged) ---

func load_sequence(sequence) -> void:
	_sequence = sequence
	_auto_fit_enabled = true
	_update_visual()
	_update_foreground_visuals()
	call_deferred("apply_auto_fit")

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
