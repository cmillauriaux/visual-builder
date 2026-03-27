extends GraphEdit

## Vue graphe des chapitres (niveau 1).

const GraphNodeItem = preload("res://src/views/graph_node_item.gd")
const ChapterScript = preload("res://src/models/chapter.gd")

const COLOR_TRANSITION = Color(0.6, 0.8, 1.0)
const COLOR_CHOICE = Color(0.0, 0.9, 0.2)
const COLOR_BOTH = Color(1.0, 0.85, 0.0)
const TOOLTIP_HOVER_THRESHOLD = 10.0
const BEZIER_SAMPLE_COUNT = 20

signal chapter_double_clicked(chapter_uuid: String)
signal chapter_rename_requested(chapter_uuid: String)
signal chapter_delete_requested(chapter_uuid: String)
signal entry_point_changed(uuid: String)

var _story = null
var _node_map: Dictionary = {}  # uuid → GraphNode
var _connection_type_map: Dictionary = {}  # "from→to" → "transition"|"choice"|"both"

## Index O(1) pour les couleurs de connexions (optimisation perf)
var _outgoing_index: Dictionary = {}  # uuid → {has_transition: bool, has_choice: bool}
var _incoming_index: Dictionary = {}  # uuid → {has_transition: bool, has_choice: bool}

## Cache des courbes bezier en espace canvas (optimisation perf)
var _bezier_cache: Dictionary = {}           # key → PackedVector2Array (canvas space)
var _cached_node_positions: Dictionary = {}  # uuid → Vector2 (position_offset)
var _last_mouse_pos: Vector2 = Vector2(INF, INF)

var _tooltip_panel: PanelContainer
var _tooltip_label: Label
var _hovered_key: String = ""

func _ready() -> void:
	connection_lines_thickness = 6.0
	_setup_tooltip()
	set_process(true)

func _setup_tooltip() -> void:
	_tooltip_panel = PanelContainer.new()
	_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_panel.z_index = 100
	_tooltip_label = Label.new()
	_tooltip_panel.add_child(_tooltip_label)
	add_child(_tooltip_panel)
	_tooltip_panel.hide()

func _process(_delta: float) -> void:
	if not is_visible_in_tree() or _connection_type_map.is_empty():
		return
	var mouse_pos = get_local_mouse_position()
	_rebuild_bezier_cache_if_stale()
	# Pas de recalcul si la souris n'a pas bougé
	if mouse_pos == _last_mouse_pos:
		if _hovered_key != "" and _tooltip_panel:
			_tooltip_panel.position = mouse_pos + Vector2(12.0, 12.0)
		return
	_last_mouse_pos = mouse_pos
	# Comparaison en espace canvas pour exploiter le cache
	var mouse_canvas = mouse_pos / zoom + scroll_offset
	var threshold_canvas = TOOLTIP_HOVER_THRESHOLD / zoom
	var new_hovered = ""
	for key in _bezier_cache:
		for p in _bezier_cache[key]:
			if mouse_canvas.distance_to(p) <= threshold_canvas:
				new_hovered = key
				break
		if new_hovered != "":
			break
	if new_hovered != _hovered_key:
		_hovered_key = new_hovered
		_update_tooltip(mouse_pos)
	elif _hovered_key != "" and _tooltip_panel:
		_tooltip_panel.position = mouse_pos + Vector2(12.0, 12.0)

func _rebuild_bezier_cache_if_stale() -> void:
	# Détecte si un nœud a bougé
	var positions_changed = false
	for uuid in _node_map:
		if _cached_node_positions.get(uuid) != _node_map[uuid].position_offset:
			positions_changed = true
			break
	if not positions_changed and _bezier_cache.size() == _connection_type_map.size():
		return
	# Reconstruit le cache en espace canvas
	_bezier_cache.clear()
	_cached_node_positions.clear()
	for uuid in _node_map:
		_cached_node_positions[uuid] = _node_map[uuid].position_offset
	for key in _connection_type_map:
		var parts = key.split("→")
		if parts.size() != 2:
			continue
		var from_node = _node_map.get(parts[0])
		var to_node = _node_map.get(parts[1])
		if not from_node or not to_node:
			continue
		var from_canvas = from_node.position_offset + from_node.get_output_port_position(0)
		var to_canvas = to_node.position_offset + to_node.get_input_port_position(0)
		_bezier_cache[key] = _get_connection_line(from_canvas, to_canvas)

func _canvas_to_screen(canvas_pos: Vector2) -> Vector2:
	return (canvas_pos - scroll_offset) * zoom

func _is_near_bezier(point: Vector2, from_pos: Vector2, to_pos: Vector2) -> bool:
	for p in _get_connection_line(from_pos, to_pos):
		if point.distance_to(p) <= TOOLTIP_HOVER_THRESHOLD:
			return true
	return false

func _get_connection_line(from_position: Vector2, to_position: Vector2) -> PackedVector2Array:
	var points = PackedVector2Array()
	if to_position.x >= from_position.x:
		var dist_x = abs(to_position.x - from_position.x)
		var cp_offset = maxf(dist_x * 0.5, 40.0)
		var cp1 = from_position + Vector2(cp_offset, 0.0)
		var cp2 = to_position - Vector2(cp_offset, 0.0)
		for i in range(BEZIER_SAMPLE_COUNT + 1):
			var t = float(i) / BEZIER_SAMPLE_COUNT
			points.append(from_position.bezier_interpolate(cp1, cp2, to_position, t))
		return points
	var margin = 60.0
	var bottom_y = maxf(from_position.y, to_position.y) + margin
	var right_x = from_position.x + margin
	var left_x = to_position.x - margin
	var corner_right = Vector2(right_x, bottom_y)
	var corner_left = Vector2(left_x, bottom_y)
	for i in range(BEZIER_SAMPLE_COUNT + 1):
		var t = float(i) / BEZIER_SAMPLE_COUNT
		var cp1 = Vector2(right_x, from_position.y)
		var cp2 = Vector2(right_x, bottom_y)
		points.append(from_position.bezier_interpolate(cp1, cp2, corner_right, t))
	for i in range(1, BEZIER_SAMPLE_COUNT + 1):
		var t = float(i) / BEZIER_SAMPLE_COUNT
		points.append(corner_right.lerp(corner_left, t))
	for i in range(1, BEZIER_SAMPLE_COUNT + 1):
		var t = float(i) / BEZIER_SAMPLE_COUNT
		var cp1 = Vector2(left_x, bottom_y)
		var cp2 = Vector2(left_x, to_position.y)
		points.append(corner_left.bezier_interpolate(cp1, cp2, to_position, t))
	return points

func _update_tooltip(mouse_pos: Vector2) -> void:
	if not _tooltip_panel:
		return
	if _hovered_key == "":
		_tooltip_panel.hide()
		return
	var conn_type = _connection_type_map.get(_hovered_key, "transition")
	match conn_type:
		"transition":
			_tooltip_label.text = tr("Transition automatique")
		"choice":
			_tooltip_label.text = tr("Choix du joueur")
		"both":
			_tooltip_label.text = tr("Transition et Choix")
	_tooltip_panel.position = mouse_pos + Vector2(12.0, 12.0)
	_tooltip_panel.reset_size()
	_tooltip_panel.show()

func load_story(story) -> void:
	_story = story
	_clear_nodes()
	for chapter in _story.chapters:
		_create_node(chapter.uuid, chapter.chapter_name, chapter.position, chapter.subtitle)
	if _story.entry_point_uuid != "" and _node_map.has(_story.entry_point_uuid):
		_node_map[_story.entry_point_uuid].set_entry_point(true)
	_build_connection_type_map()
	_connect_all_from_map()
	_update_node_colors()

func get_story():
	return _story

func get_node_count() -> int:
	return _node_map.size()

func get_connection_type(from_uuid: String, to_uuid: String) -> String:
	return _connection_type_map.get(from_uuid + "→" + to_uuid, "")

func add_new_chapter(chapter_name: String, pos: Vector2) -> void:
	var chapter = ChapterScript.new()
	chapter.chapter_name = chapter_name
	chapter.position = pos
	_story.chapters.append(chapter)
	_create_node(chapter.uuid, chapter.chapter_name, chapter.position, "")

func remove_chapter(uuid: String) -> void:
	for i in range(_story.chapters.size()):
		if _story.chapters[i].uuid == uuid:
			_story.chapters.remove_at(i)
			break
	_story.connections = _story.connections.filter(func(c): return c.has("from") and c.has("to") and c["from"] != uuid and c["to"] != uuid)
	if _node_map.has(uuid):
		_node_map[uuid].queue_free()
		_node_map.erase(uuid)

func rename_chapter(uuid: String, new_name: String, new_subtitle: String = "") -> void:
	for ch in _story.chapters:
		if ch.uuid == uuid:
			ch.chapter_name = new_name
			ch.subtitle = new_subtitle
			break
	if _node_map.has(uuid):
		_node_map[uuid].set_item_name_and_subtitle(new_name, new_subtitle)

func add_story_connection(from_uuid: String, to_uuid: String) -> void:
	_story.connections.append({"from": from_uuid, "to": to_uuid})
	var key = from_uuid + "→" + to_uuid
	_merge_connection_type(key, "transition")
	_rebuild_color_indices()
	_connect_nodes(from_uuid, to_uuid)
	_update_node_colors()

func remove_story_connection(from_uuid: String, to_uuid: String) -> void:
	_story.connections = _story.connections.filter(
		func(c): return c.has("from") and c.has("to") and not (c["from"] == from_uuid and c["to"] == to_uuid)
	)
	var key = from_uuid + "→" + to_uuid
	_connection_type_map.erase(key)
	_bezier_cache.erase(key)
	_rebuild_color_indices()
	disconnect_node(from_uuid, 0, to_uuid, 0)
	_update_node_colors()

func clear_graph() -> void:
	_clear_nodes()

func get_chapter_by_uuid(uuid: String):
	if _story == null:
		return null
	for chapter in _story.chapters:
		if chapter.uuid == uuid:
			return chapter
	return null

func sync_positions_to_model() -> void:
	for ch in _story.chapters:
		if _node_map.has(ch.uuid):
			ch.position = _node_map[ch.uuid].get_item_position()

func _build_connection_type_map() -> void:
	_connection_type_map.clear()
	_bezier_cache.clear()
	_last_mouse_pos = Vector2(INF, INF)
	# Connexions manuelles = transition
	for conn in _story.connections:
		if not conn.has("from") or not conn.has("to"):
			continue
		_merge_connection_type(conn["from"] + "→" + conn["to"], "transition")
	# Connexions issues des endings des séquences dans les scènes des chapitres
	for chapter in _story.chapters:
		for scene in chapter.scenes:
			for seq in scene.sequences:
				if seq.ending == null:
					continue
				if seq.ending.type == "auto_redirect" and seq.ending.auto_consequence:
					if seq.ending.auto_consequence.type == "redirect_chapter" and seq.ending.auto_consequence.target != "":
						_merge_connection_type(chapter.uuid + "→" + seq.ending.auto_consequence.target, "transition")
				elif seq.ending.type == "choices":
					for choice in seq.ending.choices:
						if choice.consequence and choice.consequence.type == "redirect_chapter" and choice.consequence.target != "":
							_merge_connection_type(chapter.uuid + "→" + choice.consequence.target, "choice")
			for cond in scene.conditions:
				for rule in cond.rules:
					if rule.consequence and rule.consequence.type == "redirect_chapter" and rule.consequence.target != "":
						_merge_connection_type(chapter.uuid + "→" + rule.consequence.target, "transition")
				if cond.default_consequence and cond.default_consequence.type == "redirect_chapter" and cond.default_consequence.target != "":
					_merge_connection_type(chapter.uuid + "→" + cond.default_consequence.target, "transition")
	_rebuild_color_indices()

func _merge_connection_type(key: String, new_type: String) -> void:
	if not _connection_type_map.has(key):
		_connection_type_map[key] = new_type
	elif _connection_type_map[key] != new_type:
		_connection_type_map[key] = "both"

func _connect_all_from_map() -> void:
	for key in _connection_type_map:
		var parts = key.split("→")
		if parts.size() == 2:
			_connect_nodes(parts[0], parts[1])

func _update_node_colors() -> void:
	for uuid in _node_map:
		var node = _node_map[uuid]
		node.set_slot_color_right(0, _compute_outgoing_color(uuid))
		node.set_slot_color_left(0, _compute_incoming_color(uuid))

func _rebuild_color_indices() -> void:
	_outgoing_index.clear()
	_incoming_index.clear()
	for key in _connection_type_map:
		var parts = key.split("→")
		if parts.size() != 2:
			continue
		var from_uuid = parts[0]
		var to_uuid = parts[1]
		var t = _connection_type_map[key]
		if not _outgoing_index.has(from_uuid):
			_outgoing_index[from_uuid] = {"has_transition": false, "has_choice": false}
		if not _incoming_index.has(to_uuid):
			_incoming_index[to_uuid] = {"has_transition": false, "has_choice": false}
		if t == "transition" or t == "both":
			_outgoing_index[from_uuid]["has_transition"] = true
			_incoming_index[to_uuid]["has_transition"] = true
		if t == "choice" or t == "both":
			_outgoing_index[from_uuid]["has_choice"] = true
			_incoming_index[to_uuid]["has_choice"] = true

func _compute_outgoing_color(uuid: String) -> Color:
	var entry = _outgoing_index.get(uuid, {})
	var has_transition = entry.get("has_transition", false)
	var has_choice = entry.get("has_choice", false)
	if has_transition and has_choice:
		return COLOR_BOTH
	if has_choice:
		return COLOR_CHOICE
	return COLOR_TRANSITION

func _compute_incoming_color(uuid: String) -> Color:
	var entry = _incoming_index.get(uuid, {})
	var has_transition = entry.get("has_transition", false)
	var has_choice = entry.get("has_choice", false)
	if has_transition and has_choice:
		return COLOR_BOTH
	if has_choice:
		return COLOR_CHOICE
	return COLOR_TRANSITION

func _create_node(uuid: String, item_name: String, pos: Vector2, subtitle: String = "") -> void:
	var node = GraphNode.new()
	node.set_script(GraphNodeItem)
	add_child(node)
	node.setup(uuid, item_name, pos, subtitle)
	node.double_clicked.connect(_on_node_double_clicked)
	node.rename_requested.connect(_on_node_rename_requested)
	node.delete_requested.connect(_on_node_delete_requested)
	node.entry_point_toggled.connect(_on_entry_point_toggled)
	_node_map[uuid] = node

func _on_node_double_clicked(uuid: String) -> void:
	chapter_double_clicked.emit(uuid)

func _on_node_rename_requested(uuid: String) -> void:
	chapter_rename_requested.emit(uuid)

func _on_node_delete_requested(uuid: String) -> void:
	chapter_delete_requested.emit(uuid)

func _on_entry_point_toggled(uuid: String, checked: bool) -> void:
	if checked:
		if _story.entry_point_uuid != "" and _story.entry_point_uuid != uuid and _node_map.has(_story.entry_point_uuid):
			_node_map[_story.entry_point_uuid].set_entry_point(false)
		_story.entry_point_uuid = uuid
	else:
		_story.entry_point_uuid = ""
	entry_point_changed.emit(_story.entry_point_uuid)

func _connect_nodes(from_uuid: String, to_uuid: String) -> void:
	if _node_map.has(from_uuid) and _node_map.has(to_uuid):
		connect_node(from_uuid, 0, to_uuid, 0)

func _clear_nodes() -> void:
	for uuid in _node_map:
		if is_instance_valid(_node_map[uuid]):
			remove_child(_node_map[uuid])
			_node_map[uuid].queue_free()
	_node_map.clear()
	_connection_type_map.clear()
	_outgoing_index.clear()
	_incoming_index.clear()
	_bezier_cache.clear()
	_cached_node_positions.clear()
	_last_mouse_pos = Vector2(INF, INF)
	clear_connections()
