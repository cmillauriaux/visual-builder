extends GraphEdit

## Vue Map complète de la story — affiche tous les chapitres, scènes, séquences
## et conditions dans une seule vue GraphEdit avec la même interface que les vues
## existantes. Double-cliquer sur un nœud navigue directement vers lui.
## Les chapitres englobent les scènes via des GraphFrame imbriqués.

const GraphNodeItem = preload("res://src/views/graph_node_item.gd")

signal chapter_clicked(chapter_uuid: String)
signal scene_clicked(chapter_uuid: String, scene_uuid: String)
signal sequence_clicked(chapter_uuid: String, scene_uuid: String, seq_uuid: String)
signal condition_clicked(chapter_uuid: String, scene_uuid: String, cond_uuid: String)

# Couleurs des connexions (identiques aux autres vues)
const COLOR_TRANSITION = Color(0.6, 0.8, 1.0)
const COLOR_CHOICE     = Color(0.0, 0.9, 0.2)
const COLOR_BOTH       = Color(1.0, 0.85, 0.0)

# Teintes des nœuds
const TINT_CHAPTER   = Color(0.75, 0.90, 1.40)
const TINT_SCENE     = Color(0.70, 1.40, 0.80)
const TINT_SEQUENCE  = Color(1.00, 1.00, 1.00)
const TINT_CONDITION = Color(1.40, 0.90, 0.50)

# Couleurs des cadres englobants (semi-transparentes)
const CHAPTER_FRAME_TINT = Color(0.15, 0.25, 0.55, 0.22)
const SCENE_FRAME_TINT   = Color(0.10, 0.35, 0.18, 0.24)

# Positions initiales des nœuds
const CHAPTER_Y: float     = 50.0
const SCENE_Y: float       = 200.0
const SEQ_Y_START: float   = 350.0
const NODE_COL_WIDTH: float = 230.0
const CHAPTER_GAP: float   = 100.0
const SEQ_ROW_HEIGHT: float = 80.0

# Taille estimée des nœuds et cadres
const NODE_ESTIMATED_WIDTH: float  = 190.0
const NODE_ESTIMATED_HEIGHT: float = 64.0
const SCENE_FRAME_PAD: float       = 14.0
const CHAPTER_FRAME_PAD: float     = 22.0
const FRAME_TITLE_H: float         = 26.0

var _story = null
var _node_map: Dictionary = {}             # uuid → GraphNode
var _node_meta: Dictionary = {}            # uuid → {"type": ..., "chapter_uuid": ..., "scene_uuid": ...}
var _connection_type_map: Dictionary = {}  # "from→to" → "transition"|"choice"|"both"
var _frame_list: Array = []                # tous les GraphFrame créés


func _ready() -> void:
	connection_lines_thickness = 6.0
	right_disconnects = false


func load_story(story) -> void:
	_story = story
	_clear_all()
	_build_all_nodes()
	_build_all_connections()


func get_node_count() -> int:
	return _node_map.size()


func _build_all_nodes() -> void:
	# Phase 1 : calculer toutes les positions et tailles avant création
	var chapter_frame_data: Array = []
	var scene_frame_data: Array = []
	var node_data: Array = []

	var ch_x := 50.0
	for chapter in _story.chapters:
		var scene_count: int = chapter.scenes.size()
		var group_width: float = maxf(float(scene_count) * NODE_COL_WIDTH, NODE_COL_WIDTH)
		var ch_center_x: float = ch_x + group_width * 0.5 - NODE_COL_WIDTH * 0.5

		node_data.append({
			"uuid": chapter.uuid, "display_name": chapter.chapter_name,
			"pos": Vector2(ch_center_x, CHAPTER_Y), "type": "chapter",
			"meta": {"chapter_uuid": chapter.uuid}
		})

		var max_scene_frame_bottom: float = CHAPTER_Y + NODE_ESTIMATED_HEIGHT

		for j in scene_count:
			var scene = chapter.scenes[j]
			var sc_x: float = ch_x + float(j) * NODE_COL_WIDTH

			node_data.append({
				"uuid": scene.uuid, "display_name": scene.scene_name,
				"pos": Vector2(sc_x, SCENE_Y), "type": "scene",
				"meta": {"chapter_uuid": chapter.uuid, "scene_uuid": scene.uuid}
			})

			var item_y := SEQ_Y_START
			for seq in scene.sequences:
				node_data.append({
					"uuid": seq.uuid, "display_name": seq.seq_name,
					"pos": Vector2(sc_x, item_y), "type": "sequence",
					"meta": {"chapter_uuid": chapter.uuid, "scene_uuid": scene.uuid}
				})
				item_y += SEQ_ROW_HEIGHT
			for cond in scene.conditions:
				node_data.append({
					"uuid": cond.uuid, "display_name": "◆ " + cond.condition_name,
					"pos": Vector2(sc_x, item_y), "type": "condition",
					"meta": {"chapter_uuid": chapter.uuid, "scene_uuid": scene.uuid}
				})
				item_y += SEQ_ROW_HEIGHT

			# Calcul du cadre de scène
			var sc_items: int = scene.sequences.size() + scene.conditions.size()
			var items_bottom: float
			if sc_items > 0:
				items_bottom = item_y - SEQ_ROW_HEIGHT + NODE_ESTIMATED_HEIGHT
			else:
				items_bottom = SCENE_Y + NODE_ESTIMATED_HEIGHT
			var sf_y: float = SCENE_Y - SCENE_FRAME_PAD - FRAME_TITLE_H
			var sf_h: float = items_bottom + SCENE_FRAME_PAD - sf_y
			scene_frame_data.append({
				"pos": Vector2(sc_x - SCENE_FRAME_PAD, sf_y),
				"size": Vector2(NODE_ESTIMATED_WIDTH + 2.0 * SCENE_FRAME_PAD, sf_h),
				"tint": SCENE_FRAME_TINT
			})
			max_scene_frame_bottom = maxf(max_scene_frame_bottom, sf_y + sf_h)

		# Calcul du cadre de chapitre
		var cf_y: float = CHAPTER_Y - CHAPTER_FRAME_PAD - FRAME_TITLE_H
		var cf_h: float = max_scene_frame_bottom + CHAPTER_FRAME_PAD - cf_y
		chapter_frame_data.append({
			"pos": Vector2(ch_x - CHAPTER_FRAME_PAD, cf_y),
			"size": Vector2(group_width + 2.0 * CHAPTER_FRAME_PAD, cf_h),
			"tint": CHAPTER_FRAME_TINT
		})

		ch_x += group_width + CHAPTER_GAP

	# Phase 2 : créer les cadres EN PREMIER (derrière les nœuds dans l'ordre z)
	for fd in chapter_frame_data:
		_create_frame(fd)
	for fd in scene_frame_data:
		_create_frame(fd)

	# Phase 3 : créer les nœuds PAR-DESSUS les cadres
	for nd in node_data:
		_create_node(nd["uuid"], nd["display_name"], nd["pos"], nd["type"], nd["meta"])


func _create_frame(fd: Dictionary) -> void:
	var frame := GraphFrame.new()
	frame.autoshrink_enabled = false
	frame.tint_color_enabled = true
	frame.tint_color = fd["tint"]
	frame.z_index = -1
	add_child(frame)
	frame.position_offset = fd["pos"]
	frame.size = fd["size"]
	_frame_list.append(frame)


func _create_node(uuid: String, display_name: String, pos: Vector2, node_type: String, meta: Dictionary) -> void:
	var node := GraphNode.new()
	node.set_script(GraphNodeItem)
	add_child(node)
	node.setup(uuid, display_name, pos)
	node.double_clicked.connect(_on_node_double_clicked)
	match node_type:
		"chapter":   node.modulate = TINT_CHAPTER
		"scene":     node.modulate = TINT_SCENE
		"condition": node.modulate = TINT_CONDITION
	_node_map[uuid] = node
	_node_meta[uuid] = meta.duplicate()
	_node_meta[uuid]["type"] = node_type


func _on_node_double_clicked(uuid: String) -> void:
	var meta: Dictionary = _node_meta.get(uuid, {})
	match meta.get("type", ""):
		"chapter":
			chapter_clicked.emit(uuid)
		"scene":
			scene_clicked.emit(meta["chapter_uuid"], uuid)
		"sequence":
			sequence_clicked.emit(meta["chapter_uuid"], meta["scene_uuid"], uuid)
		"condition":
			condition_clicked.emit(meta["chapter_uuid"], meta["scene_uuid"], uuid)


func _build_all_connections() -> void:
	_connection_type_map.clear()
	# Connexions explicites stockées dans les modèles
	for conn in _story.connections:
		_merge_conn(conn.get("from", ""), conn.get("to", ""), "transition")
	for chapter in _story.chapters:
		for conn in chapter.connections:
			_merge_conn(conn.get("from", ""), conn.get("to", ""), "transition")
		for scene in chapter.scenes:
			for conn in scene.connections:
				_merge_conn(conn.get("from", ""), conn.get("to", ""), "transition")
	# Connexions déduites des endings et conditions
	for chapter in _story.chapters:
		for scene in chapter.scenes:
			for seq in scene.sequences:
				_derive_from_ending(seq.ending, chapter.uuid, scene.uuid, seq.uuid)
			for cond in scene.conditions:
				_derive_from_condition(cond, chapter.uuid, scene.uuid)
	# Créer les arêtes GraphEdit depuis la map de types
	for key in _connection_type_map:
		var parts: PackedStringArray = key.split("→")
		if parts.size() == 2 and _node_map.has(parts[0]) and _node_map.has(parts[1]):
			connect_node(parts[0], 0, parts[1], 0)
	_update_node_colors()


func _merge_conn(from_uuid: String, to_uuid: String, conn_type: String) -> void:
	if not from_uuid or not to_uuid:
		return
	var key := from_uuid + "→" + to_uuid
	if not _connection_type_map.has(key):
		_connection_type_map[key] = conn_type
	elif _connection_type_map[key] != conn_type:
		_connection_type_map[key] = "both"


func _derive_from_ending(ending, chapter_uuid: String, scene_uuid: String, item_uuid: String) -> void:
	if ending == null:
		return
	if ending.type == "auto_redirect" and ending.auto_consequence:
		var cons = ending.auto_consequence
		if not cons.target:
			return
		match cons.type:
			"redirect_chapter": _merge_conn(chapter_uuid, cons.target, "transition")
			"redirect_scene":   _merge_conn(scene_uuid, cons.target, "transition")
			"redirect_sequence", "redirect_condition": _merge_conn(item_uuid, cons.target, "transition")
	elif ending.type == "choices":
		for choice in ending.choices:
			if choice.consequence == null or not choice.consequence.target:
				continue
			match choice.consequence.type:
				"redirect_chapter": _merge_conn(chapter_uuid, choice.consequence.target, "choice")
				"redirect_scene":   _merge_conn(scene_uuid, choice.consequence.target, "choice")
				"redirect_sequence", "redirect_condition": _merge_conn(item_uuid, choice.consequence.target, "choice")


func _derive_from_condition(cond, chapter_uuid: String, scene_uuid: String) -> void:
	for rule in cond.rules:
		if rule.consequence == null or not rule.consequence.target:
			continue
		match rule.consequence.type:
			"redirect_chapter": _merge_conn(chapter_uuid, rule.consequence.target, "transition")
			"redirect_scene":   _merge_conn(scene_uuid, rule.consequence.target, "transition")
			"redirect_sequence", "redirect_condition": _merge_conn(cond.uuid, rule.consequence.target, "transition")
	if cond.default_consequence and cond.default_consequence.target:
		match cond.default_consequence.type:
			"redirect_chapter": _merge_conn(chapter_uuid, cond.default_consequence.target, "transition")
			"redirect_scene":   _merge_conn(scene_uuid, cond.default_consequence.target, "transition")
			"redirect_sequence", "redirect_condition": _merge_conn(cond.uuid, cond.default_consequence.target, "transition")


func _update_node_colors() -> void:
	for uuid in _node_map:
		var node = _node_map[uuid]
		node.set_slot_color_right(0, _compute_outgoing_color(uuid))
		node.set_slot_color_left(0, _compute_incoming_color(uuid))


func _compute_outgoing_color(uuid: String) -> Color:
	var has_transition := false
	var has_choice := false
	for key in _connection_type_map:
		if key.begins_with(uuid + "→"):
			var t: String = _connection_type_map[key]
			if t == "transition" or t == "both": has_transition = true
			if t == "choice" or t == "both": has_choice = true
	if has_transition and has_choice: return COLOR_BOTH
	if has_choice: return COLOR_CHOICE
	return COLOR_TRANSITION


func _compute_incoming_color(uuid: String) -> Color:
	var has_transition := false
	var has_choice := false
	for key in _connection_type_map:
		if key.ends_with("→" + uuid):
			var t: String = _connection_type_map[key]
			if t == "transition" or t == "both": has_transition = true
			if t == "choice" or t == "both": has_choice = true
	if has_transition and has_choice: return COLOR_BOTH
	if has_choice: return COLOR_CHOICE
	return COLOR_TRANSITION


func _clear_all() -> void:
	for frame in _frame_list:
		if is_instance_valid(frame):
			remove_child(frame)
			frame.queue_free()
	_frame_list.clear()
	for uuid in _node_map:
		if is_instance_valid(_node_map[uuid]):
			remove_child(_node_map[uuid])
			_node_map[uuid].queue_free()
	_node_map.clear()
	_node_meta.clear()
	_connection_type_map.clear()
	clear_connections()
