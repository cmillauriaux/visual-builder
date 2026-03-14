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
var _fx_container: Control
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
var _selected_fg_uuids: Array = []
var _hidden_fg_uuids: Array = []      # UUIDs temporairement cachés (reset au changement de dialogue)
var _dragging_fg: bool = false
var _resizing_fg: bool = false
var _drag_start_pos: Vector2 = Vector2.ZERO
var _drag_start_wrapper_pos: Vector2 = Vector2.ZERO
var _resize_start_pos: Vector2 = Vector2.ZERO
var _resize_start_scale: float = 1.0

## Inheritance mode — indicates foregrounds are inherited from another dialogue
var _is_inherited_mode: bool = false
var _inherited_from_index: int = -1

## Backward-compatible accessor — returns last selected UUID or "".
var _selected_fg_uuid: String:
	get:
		if _selected_fg_uuids.is_empty():
			return ""
		return _selected_fg_uuids[-1]

# --- Context menu ---
var _context_menu: PopupMenu = null
var _bg_context_menu: PopupMenu = null
var _context_menu_uuid: String = ""

# --- Inherit confirmation ---
var _inherit_confirm_dialog: AcceptDialog = null

signal foreground_selected(uuid: String)
signal foreground_deselected()
signal foreground_replace_requested(uuid: String)
signal foreground_replace_with_new_requested(uuid: String)
signal inherited_foreground_edit_confirmed()
signal foreground_modified(uuid: String)

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

	# FX container — between Canvas and UI overlay, so FX affect only bg/fg, not UI
	_fx_container = Control.new()
	_fx_container.name = "FxContainer"
	_fx_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx_container)

	# Overlay container — positioned/sized to match the canvas screen rect (UI goes here)
	_overlay_container = Control.new()
	_overlay_container.name = "OverlayContainer"
	_overlay_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay_container)

	_context_menu = PopupMenu.new()
	_context_menu.name = "ForegroundContextMenu"
	_context_menu.add_item("Supprimer", 0)
	_context_menu.add_item("Copier les paramètres", 1)
	_context_menu.add_item("Coller les paramètres", 2)
	_context_menu.add_separator()
	_context_menu.add_item("Remplacer", 5)
	_context_menu.add_item("Remplacer par un nouveau foreground", 6)
	_context_menu.add_separator()
	_context_menu.add_item("Copier le foreground", 3)
	_context_menu.add_item("Coller le foreground", 4)
	_context_menu.add_separator()
	_context_menu.add_item("Cacher", 7)
	_context_menu.id_pressed.connect(_on_context_menu_id_pressed)
	_update_context_menu_state()
	add_child(_context_menu)

	_bg_context_menu = PopupMenu.new()
	_bg_context_menu.name = "BackgroundContextMenu"
	_bg_context_menu.add_item("Coller le foreground", 4)
	_bg_context_menu.id_pressed.connect(_on_context_menu_id_pressed)
	add_child(_bg_context_menu)

	# Confirmation dialog for inherited foreground editing
	_inherit_confirm_dialog = AcceptDialog.new()
	_inherit_confirm_dialog.title = "Foreground hérité"
	_inherit_confirm_dialog.dialog_text = ""
	_inherit_confirm_dialog.ok_button_text = "Confirmer"
	_inherit_confirm_dialog.add_cancel_button("Annuler")
	_inherit_confirm_dialog.confirmed.connect(_on_inherit_confirmed)
	add_child(_inherit_confirm_dialog)

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
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			# Right-click on background → show paste-only menu
			_show_bg_context_menu(mb.global_position)
			accept_event()
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
	# Update FX and overlay containers to match canvas screen rect
	var rect = get_canvas_rect()
	if _fx_container != null:
		_fx_container.position = rect.position
		_fx_container.size = rect.size
	if _overlay_container != null:
		_overlay_container.position = rect.position
		_overlay_container.size = rect.size

# --- Input for Delete key ---

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_DELETE:
		if not _selected_fg_uuids.is_empty():
			var uuids_to_remove = _selected_fg_uuids.duplicate()
			_deselect_foreground()
			for uuid in uuids_to_remove:
				remove_foreground(uuid)
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
		for key in _fg_visual_map.keys():
			if is_instance_valid(_fg_visual_map[key]):
				_fg_visual_map[key].queue_free()
		_fg_visual_map.clear()
		return

	# Collect current UUIDs
	var current_uuids := {}
	for fg in _sequence.foregrounds:
		current_uuids[fg.uuid] = fg

	# Identify orphan wrappers (old UUIDs absent du nouveau set)
	var orphan_uuids: Array = []
	for uuid in _fg_visual_map.keys():
		if not current_uuids.has(uuid):
			orphan_uuids.append(uuid)

	# Identify new FGs (not in existing map)
	var new_fgs: Array = []
	for fg in _sequence.foregrounds:
		if not _fg_visual_map.has(fg.uuid):
			new_fgs.append(fg)

	# Réutiliser les wrappers orphelins pour les nouveaux FGs visuellement identiques
	for fg in new_fgs:
		for i in range(orphan_uuids.size()):
			var old_uuid = orphan_uuids[i]
			var wrapper = _fg_visual_map.get(old_uuid)
			if wrapper and is_instance_valid(wrapper) and _wrapper_matches_fg(wrapper, fg):
				_fg_visual_map.erase(old_uuid)
				_reassign_wrapper(wrapper, fg)
				orphan_uuids.remove_at(i)
				break

	# Supprimer les orphelins restants (non réutilisés)
	for old_uuid in orphan_uuids:
		if _fg_visual_map.has(old_uuid) and is_instance_valid(_fg_visual_map[old_uuid]):
			_fg_visual_map[old_uuid].queue_free()
		_fg_visual_map.erase(old_uuid)

	# Create or update wrappers
	for fg in _sequence.foregrounds:
		if not _fg_visual_map.has(fg.uuid):
			_create_fg_visual(fg)
		_update_single_fg_visual(fg)

	# Reorder children in _fg_container by z_order
	_reorder_fg_children()

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

	var inherit_border = ColorRect.new()
	inherit_border.name = "InheritBorder"
	inherit_border.color = Color(1.0, 0.67, 0.0, 0.4)  # orange
	inherit_border.visible = false
	inherit_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.add_child(inherit_border)

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

## Compare un wrapper existant avec un nouveau FG pour déterminer s'ils sont visuellement identiques.
func _wrapper_matches_fg(wrapper: Control, fg) -> bool:
	if not wrapper.has_meta("fg_image"):
		return false
	if wrapper.get_meta("fg_image") != fg.image:
		return false
	var threshold = 0.01
	var old_abg = wrapper.get_meta("fg_anchor_bg", Vector2.ZERO)
	if absf(old_abg.x - fg.anchor_bg.x) > threshold or absf(old_abg.y - fg.anchor_bg.y) > threshold:
		return false
	var old_afg = wrapper.get_meta("fg_anchor_fg", Vector2.ZERO)
	if absf(old_afg.x - fg.anchor_fg.x) > threshold or absf(old_afg.y - fg.anchor_fg.y) > threshold:
		return false
	if absf(wrapper.get_meta("fg_scale", 1.0) - fg.scale) > threshold:
		return false
	if wrapper.get_meta("fg_flip_h", false) != fg.flip_h or wrapper.get_meta("fg_flip_v", false) != fg.flip_v:
		return false
	return true

## Réutilise un wrapper existant pour un nouveau foreground (UUID différent mais visuellement identique).
func _reassign_wrapper(wrapper: Control, fg) -> void:
	# Reconnecter les signaux gui_input avec le nouveau UUID
	for conn in wrapper.gui_input.get_connections():
		wrapper.gui_input.disconnect(conn["callable"])
	wrapper.gui_input.connect(_on_fg_gui_input.bind(fg.uuid))
	# Reconnecter le ResizeHandle
	var handle = wrapper.get_node_or_null("ResizeHandle")
	if handle:
		for conn in handle.gui_input.get_connections():
			handle.gui_input.disconnect(conn["callable"])
		handle.gui_input.connect(_on_resize_handle_input.bind(fg.uuid))
	wrapper.name = "FG_" + fg.uuid.left(8)
	_fg_visual_map[fg.uuid] = wrapper

func _update_single_fg_visual(fg) -> void:
	if not _fg_visual_map.has(fg.uuid):
		return
	var wrapper: Control = _fg_visual_map[fg.uuid]
	if not is_instance_valid(wrapper):
		return

	# Skip si le wrapper affiche déjà exactement ce foreground (évite le rechargement texture GPU)
	if _wrapper_matches_fg(wrapper, fg):
		_update_fg_non_visual_props(wrapper, fg)
		return

	# Load texture — seulement si l'image a changé
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

	# Z-index for correct visual layering (especially during transitions with clones)
	wrapper.z_index = fg.z_order

	# Stocker les propriétés visuelles pour le matching (réutilisation des wrappers)
	wrapper.set_meta("fg_image", fg.image)
	wrapper.set_meta("fg_anchor_bg", fg.anchor_bg)
	wrapper.set_meta("fg_anchor_fg", fg.anchor_fg)
	wrapper.set_meta("fg_scale", fg.scale)
	wrapper.set_meta("fg_flip_h", fg.flip_h)
	wrapper.set_meta("fg_flip_v", fg.flip_v)

	_update_fg_non_visual_props(wrapper, fg)


func _update_fg_non_visual_props(wrapper: Control, fg) -> void:

	# Hidden foregrounds
	wrapper.visible = fg.uuid not in _hidden_fg_uuids

	# Opacity — ne pas écraser si une transition gère l'alpha
	if fg.uuid not in _transitioning_uuids:
		if _is_inherited_mode:
			wrapper.modulate.a = fg.opacity * 0.5
		else:
			wrapper.modulate.a = fg.opacity

	# Selection border — visible for all selected foregrounds
	var is_selected = fg.uuid in _selected_fg_uuids
	var border: ColorRect = wrapper.get_node("SelectionBorder")
	border.visible = is_selected and not _is_inherited_mode
	border.size = wrapper.size

	# Inheritance border — visible when foregrounds are inherited
	var inherit_border = wrapper.get_node_or_null("InheritBorder")
	if inherit_border:
		inherit_border.visible = _is_inherited_mode
		inherit_border.size = wrapper.size

	# Resize handle — only for single selection and not inherited
	var handle: ColorRect = wrapper.get_node("ResizeHandle")
	handle.visible = is_selected and _selected_fg_uuids.size() == 1 and not _is_inherited_mode
	handle.position = wrapper.size - Vector2(20, 20)

# --- Foreground interaction ---

func _select_foreground(uuid: String, shift: bool = false) -> void:
	if shift:
		if uuid in _selected_fg_uuids:
			_selected_fg_uuids.erase(uuid)
			if _selected_fg_uuids.is_empty():
				foreground_deselected.emit()
			else:
				foreground_selected.emit(_selected_fg_uuids[-1])
		else:
			_selected_fg_uuids.append(uuid)
			foreground_selected.emit(uuid)
	else:
		_selected_fg_uuids = [uuid]
		foreground_selected.emit(uuid)
	_update_foreground_visuals()

func _deselect_foreground() -> void:
	if not _selected_fg_uuids.is_empty():
		_selected_fg_uuids.clear()
		foreground_deselected.emit()
		_update_foreground_visuals()

func _on_fg_gui_input(event: InputEvent, uuid: String) -> void:
	# Ne pas démarrer le drag si on est en train de resize
	if _resizing_fg:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		# Block interactions on inherited foregrounds — show confirmation
		if _is_inherited_mode and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_show_inherit_confirmation()
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if _is_inherited_mode:
				_show_inherit_confirmation()
				accept_event()
				return
			if uuid not in _selected_fg_uuids:
				_select_foreground(uuid)
			_show_context_menu(uuid, mb.global_position)
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_select_foreground(uuid, mb.shift_pressed)
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
					foreground_modified.emit(uuid)
				_dragging_fg = false
	elif event is InputEventMouseMotion and _dragging_fg and uuid in _selected_fg_uuids:
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
				if _resizing_fg:
					foreground_modified.emit(uuid)
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

func _show_bg_context_menu(global_pos: Vector2) -> void:
	_context_menu_uuid = ""
	_update_bg_context_menu_state()
	_bg_context_menu.position = Vector2i(global_pos)
	_bg_context_menu.popup()

func _update_context_menu_state() -> void:
	if _context_menu == null:
		return
	var paste_idx = _context_menu.get_item_index(2)
	if paste_idx >= 0:
		_context_menu.set_item_disabled(paste_idx, not _fg_clipboard.has_data())
	var paste_fg_idx = _context_menu.get_item_index(4)
	if paste_fg_idx >= 0:
		_context_menu.set_item_disabled(paste_fg_idx, not _fg_clipboard.has_foreground_data())

func _update_bg_context_menu_state() -> void:
	if _bg_context_menu == null:
		return
	var paste_fg_idx = _bg_context_menu.get_item_index(4)
	if paste_fg_idx >= 0:
		_bg_context_menu.set_item_disabled(paste_fg_idx, not _fg_clipboard.has_foreground_data())

func _on_context_menu_id_pressed(id: int) -> void:
	if id == 0:  # Supprimer
		if not _selected_fg_uuids.is_empty():
			var uuids_to_remove = _selected_fg_uuids.duplicate()
			_deselect_foreground()
			for uuid in uuids_to_remove:
				remove_foreground(uuid)
			_context_menu_uuid = ""
	elif id == 1:  # Copier les paramètres
		if _context_menu_uuid != "":
			_copy_foreground_params(_context_menu_uuid)
	elif id == 2:  # Coller les paramètres
		if _context_menu_uuid != "":
			_paste_foreground_params(_context_menu_uuid)
	elif id == 3:  # Copier le foreground
		_copy_selected_foregrounds()
	elif id == 4:  # Coller le foreground
		_paste_foreground()
	elif id == 5:  # Remplacer
		if _context_menu_uuid != "":
			foreground_replace_requested.emit(_context_menu_uuid)
	elif id == 6:  # Remplacer par un nouveau foreground
		if _context_menu_uuid != "":
			foreground_replace_with_new_requested.emit(_context_menu_uuid)
	elif id == 7:  # Cacher
		if _context_menu_uuid != "":
			hide_foreground(_context_menu_uuid)

# --- Grid ---

func set_grid_visible(visible: bool) -> void:
	_grid_visible = visible
	_update_grid_overlay()

func is_grid_visible() -> bool:
	return _grid_visible

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

func is_snap_enabled() -> bool:
	return _snap_enabled

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

func _copy_foreground(uuid: String) -> void:
	var fg = find_foreground(uuid)
	if fg == null:
		return
	_fg_clipboard.copy_foreground(fg)

func _copy_selected_foregrounds() -> void:
	if _selected_fg_uuids.is_empty():
		return
	var fgs := []
	for uuid in _selected_fg_uuids:
		var fg = find_foreground(uuid)
		if fg:
			fgs.append(fg)
	if fgs.size() == 1:
		_fg_clipboard.copy_foreground(fgs[0])
	elif fgs.size() > 1:
		_fg_clipboard.copy_foregrounds(fgs)

func _paste_foreground() -> void:
	if _sequence == null:
		return
	var new_fgs = _fg_clipboard.paste_foregrounds()
	if new_fgs.is_empty():
		return
	for new_fg in new_fgs:
		_sequence.foregrounds.append(new_fg)
	_update_foreground_visuals()

# --- Data controller (existing API, unchanged) ---

func load_sequence(sequence) -> void:
	_sequence = sequence
	_auto_fit_enabled = true
	_selected_fg_uuids.clear()
	_hidden_fg_uuids.clear()
	_transitioning_uuids.clear()
	_dragging_fg = false
	_resizing_fg = false
	_is_inherited_mode = false
	_inherited_from_index = -1
	_update_visual()
	_update_foreground_visuals()
	call_deferred("apply_auto_fit")

## Met à jour uniquement les foregrounds sans toucher au background, aux transitions en cours,
## ni à l'état de sélection. Utilisé lors du changement de dialogue pendant le play.
func update_foregrounds() -> void:
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

func select_foreground_by_uuid(uuid: String) -> void:
	_select_foreground(uuid)


func set_inherited_mode(is_inherited: bool, from_index: int = -1) -> void:
	_is_inherited_mode = is_inherited
	_inherited_from_index = from_index
	_update_foreground_visuals()


func is_inherited_mode() -> bool:
	return _is_inherited_mode


func show_foreground(uuid: String) -> void:
	_hidden_fg_uuids.erase(uuid)
	_update_foreground_visuals()


func hide_foreground(uuid: String) -> void:
	if uuid not in _hidden_fg_uuids:
		_hidden_fg_uuids.append(uuid)
	# Deselect if selected
	if uuid in _selected_fg_uuids:
		_selected_fg_uuids.erase(uuid)
		foreground_deselected.emit()
	_update_foreground_visuals()

func is_foreground_hidden(uuid: String) -> bool:
	return uuid in _hidden_fg_uuids

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

func normalize_foregrounds() -> int:
	if _sequence == null:
		return 0
	var to_remove: Array = []
	var fgs = _sequence.foregrounds
	for i in range(fgs.size()):
		if i in to_remove:
			continue
		for j in range(i + 1, fgs.size()):
			if j in to_remove:
				continue
			if _are_duplicate_foregrounds(fgs[i], fgs[j]):
				to_remove.append(j)
	to_remove.sort()
	to_remove.reverse()
	for idx in to_remove:
		var uuid = fgs[idx].uuid
		fgs.remove_at(idx)
		if _fg_visual_map.has(uuid):
			if is_instance_valid(_fg_visual_map[uuid]):
				_fg_visual_map[uuid].queue_free()
			_fg_visual_map.erase(uuid)
	if to_remove.size() > 0:
		_selected_fg_uuids.clear()
		_update_foreground_visuals()
	return to_remove.size()

func _are_duplicate_foregrounds(a, b) -> bool:
	if a.image != b.image:
		return false
	var threshold = 0.05
	if absf(a.anchor_bg.x - b.anchor_bg.x) > threshold:
		return false
	if absf(a.anchor_bg.y - b.anchor_bg.y) > threshold:
		return false
	if absf(a.anchor_fg.x - b.anchor_fg.x) > threshold:
		return false
	if absf(a.anchor_fg.y - b.anchor_fg.y) > threshold:
		return false
	return true

func get_foregrounds_sorted() -> Array:
	if _sequence == null:
		return []
	var sorted = _sequence.foregrounds.duplicate()
	sorted.sort_custom(func(a, b): return a.z_order < b.z_order)
	return sorted

func _reorder_fg_children() -> void:
	if _sequence == null or _fg_container == null:
		return
	var sorted = get_foregrounds_sorted()
	# Collecter les wrappers mappés dans l'ordre trié
	var sorted_wrappers: Array = []
	for fg in sorted:
		if _fg_visual_map.has(fg.uuid) and is_instance_valid(_fg_visual_map[fg.uuid]):
			sorted_wrappers.append(_fg_visual_map[fg.uuid])
	# Vérifier si l'ordre relatif des wrappers est déjà correct
	# (ignorer les enfants non-mappés : clones, zombies queue_free)
	var current_order: Array = []
	for child_idx in range(_fg_container.get_child_count()):
		var child = _fg_container.get_child(child_idx)
		if child in sorted_wrappers:
			current_order.append(child)
	if current_order == sorted_wrappers:
		return
	# L'ordre relatif est différent : replacer les wrappers dans l'ordre trié
	for wrapper in sorted_wrappers:
		_fg_container.move_child(wrapper, -1)

func refresh_foreground_z_order() -> void:
	_reorder_fg_children()

func refresh_foreground_flip() -> void:
	for uuid in _fg_visual_map.keys():
		var wrapper = _fg_visual_map[uuid]
		if not is_instance_valid(wrapper):
			continue
		var fg = find_foreground(uuid)
		if fg == null:
			continue
		var tex_rect: TextureRect = wrapper.get_node("Texture")
		tex_rect.flip_h = fg.flip_h
		tex_rect.flip_v = fg.flip_v
		wrapper.set_meta("fg_flip_h", fg.flip_h)
		wrapper.set_meta("fg_flip_v", fg.flip_v)


# --- Inherited foreground confirmation ---

func _show_inherit_confirmation() -> void:
	if _inherit_confirm_dialog == null:
		return
	var source_text = ""
	if _inherited_from_index >= 0:
		source_text = " du dialogue #%d" % (_inherited_from_index + 1)
	else:
		source_text = " de la séquence"
	_inherit_confirm_dialog.dialog_text = "Ce foreground est hérité%s.\nLe modifier créera une copie locale pour ce dialogue." % source_text
	_inherit_confirm_dialog.popup_centered()


func _on_inherit_confirmed() -> void:
	inherited_foreground_edit_confirmed.emit()
