extends GraphEdit

## Vue graphe des séquences (niveau 3).

const GraphNodeItem = preload("res://src/views/graph_node_item.gd")
const SequenceScript = preload("res://src/models/sequence.gd")
const ConditionScript = preload("res://src/models/condition.gd")

const COLOR_TRANSITION = Color(0.6, 0.8, 1.0)
const COLOR_CHOICE = Color(0.0, 0.9, 0.2)
const COLOR_CONDITION = Color(0.4, 0.6, 1.0)
const COLOR_BOTH = Color(1.0, 0.85, 0.0)
const TOOLTIP_HOVER_THRESHOLD = 10.0
const BEZIER_SAMPLE_COUNT = 20

const TERMINAL_TYPES = ["game_over", "to_be_continued", "redirect_scene", "redirect_chapter"]
const TERMINAL_DISPLAY_NAMES = {
	"game_over": "Fin de partie",
	"to_be_continued": "À suivre...",
	"redirect_scene": "→ Scène suivante",
	"redirect_chapter": "→ Chapitre suivant",
}
const TERMINAL_COLORS = {
	"game_over": Color(0.65, 0.1, 0.1),
	"to_be_continued": Color(0.35, 0.2, 0.55),
	"redirect_scene": Color(0.1, 0.3, 0.65),
	"redirect_chapter": Color(0.55, 0.3, 0.1),
}

signal sequence_double_clicked(sequence_uuid: String)
signal condition_double_clicked(condition_uuid: String)
signal sequence_rename_requested(sequence_uuid: String)
signal condition_rename_requested(condition_uuid: String)
signal sequence_delete_requested(sequence_uuid: String)
signal condition_delete_requested(condition_uuid: String)
signal entry_point_changed(uuid: String)
signal sequences_transition_requested(uuids: Array, property: String, value: String)

var _scene_data = null
var _node_map: Dictionary = {}  # uuid → GraphNode
var _condition_uuids: Dictionary = {}  # uuid → true (pour identifier les nœuds condition)
var _terminal_uuids: Dictionary = {}  # uuid → terminal_type (pour les nœuds terminaux)
var _choice_sequence_uuids: Dictionary = {}  # uuid → true (pour les nœuds séquence-choix multi-ports)
var _choice_connections: Array = []  # [{from_uuid, from_port, to_uuid}, ...]
var _connection_type_map: Dictionary = {}  # "from→to" → "transition"|"choice"|"condition"|"both"

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
	var new_hovered = ""
	for key in _connection_type_map:
		var parts = key.split("→")
		if parts.size() != 2:
			continue
		if _choice_sequence_uuids.has(parts[0]):
			continue  # Les connexions multi-ports ont leur propre logique
		var from_node = _node_map.get(parts[0])
		var to_node = _node_map.get(parts[1])
		if not from_node or not to_node:
			continue
		var from_pos = _canvas_to_screen(from_node.position_offset + from_node.get_output_port_position(0))
		var to_pos = _canvas_to_screen(to_node.position_offset + to_node.get_input_port_position(0))
		if _is_near_bezier(mouse_pos, from_pos, to_pos):
			new_hovered = key
			break
	if new_hovered != _hovered_key:
		_hovered_key = new_hovered
		_update_tooltip(mouse_pos)
	elif _hovered_key != "" and _tooltip_panel:
		_tooltip_panel.position = mouse_pos + Vector2(12.0, 12.0)

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
		# Cas forward : Bézier standard
		var dist_x = abs(to_position.x - from_position.x)
		var cp_offset = maxf(dist_x * 0.5, 40.0)
		var cp1 = from_position + Vector2(cp_offset, 0.0)
		var cp2 = to_position - Vector2(cp_offset, 0.0)
		for i in range(BEZIER_SAMPLE_COUNT + 1):
			var t = float(i) / BEZIER_SAMPLE_COUNT
			points.append(from_position.bezier_interpolate(cp1, cp2, to_position, t))
		return points
	# Connexion arrière : contourner par en-dessous via 3 segments
	var margin = 60.0
	var bottom_y = maxf(from_position.y, to_position.y) + margin
	var right_x = from_position.x + margin
	var left_x = to_position.x - margin
	var corner_right = Vector2(right_x, bottom_y)
	var corner_left = Vector2(left_x, bottom_y)
	# Segment 1 : from → coin bas-droit
	for i in range(BEZIER_SAMPLE_COUNT + 1):
		var t = float(i) / BEZIER_SAMPLE_COUNT
		var cp1 = Vector2(right_x, from_position.y)
		var cp2 = Vector2(right_x, bottom_y)
		points.append(from_position.bezier_interpolate(cp1, cp2, corner_right, t))
	# Segment 2 : coin bas-droit → coin bas-gauche
	for i in range(1, BEZIER_SAMPLE_COUNT + 1):
		var t = float(i) / BEZIER_SAMPLE_COUNT
		points.append(corner_right.lerp(corner_left, t))
	# Segment 3 : coin bas-gauche → to
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
			_tooltip_label.text = "Transition automatique"
		"choice":
			_tooltip_label.text = "Choix du joueur"
		"condition":
			_tooltip_label.text = "Condition"
		"both":
			_tooltip_label.text = "Transition et Choix"
	_tooltip_panel.position = mouse_pos + Vector2(12.0, 12.0)
	_tooltip_panel.reset_size()
	_tooltip_panel.show()

func load_scene(scene_data) -> void:
	_scene_data = scene_data
	_clear_nodes()
	for seq in _scene_data.sequences:
		_create_node(seq.uuid, seq.seq_name, seq.position, seq.subtitle)
	for cond in _scene_data.conditions:
		_create_condition_node(cond.uuid, cond.condition_name, cond.position, cond.subtitle)
	if _scene_data.entry_point_uuid != "" and _node_map.has(_scene_data.entry_point_uuid):
		_node_map[_scene_data.entry_point_uuid].set_entry_point(true)
	_create_needed_terminal_nodes()
	_build_connection_type_map()
	_connect_all_from_map()
	_update_node_colors()

func _has_effects(item) -> bool:
	if item.get("rules") != null:
		# Condition
		for rule in item.rules:
			if rule.consequence and rule.consequence.effects.size() > 0:
				return true
		if item.default_consequence and item.default_consequence.effects.size() > 0:
			return true
	elif item.get("dialogues") != null:
		# Sequence
		if item.ending:
			if item.ending.type == "auto_redirect" and item.ending.auto_consequence:
				if item.ending.auto_consequence.effects.size() > 0:
					return true
			elif item.ending.type == "choices":
				for choice in item.ending.choices:
					if choice.effects.size() > 0:
						return true
					if choice.consequence and choice.consequence.effects.size() > 0:
						return true
	return false

func get_scene_data():
	return _scene_data

func get_node_count() -> int:
	return _node_map.size() - _terminal_uuids.size()

func get_connection_type(from_uuid: String, to_uuid: String) -> String:
	return _connection_type_map.get(from_uuid + "→" + to_uuid, "")

func add_new_sequence(seq_name: String, pos: Vector2) -> void:
	var seq = SequenceScript.new()
	seq.seq_name = seq_name
	seq.position = pos
	_scene_data.sequences.append(seq)
	_create_node(seq.uuid, seq.seq_name, seq.position, "")

func add_new_condition(cond_name: String, pos: Vector2) -> void:
	var cond = ConditionScript.new()
	cond.condition_name = cond_name
	cond.position = pos
	_scene_data.conditions.append(cond)
	_create_condition_node(cond.uuid, cond.condition_name, cond.position, "")

func remove_sequence(uuid: String) -> void:
	for i in range(_scene_data.sequences.size()):
		if _scene_data.sequences[i].uuid == uuid:
			_scene_data.sequences.remove_at(i)
			break
	_scene_data.connections = _scene_data.connections.filter(func(c): return c["from"] != uuid and c["to"] != uuid)
	if _node_map.has(uuid):
		_node_map[uuid].queue_free()
		_node_map.erase(uuid)

func remove_condition(uuid: String) -> void:
	for i in range(_scene_data.conditions.size()):
		if _scene_data.conditions[i].uuid == uuid:
			_scene_data.conditions.remove_at(i)
			break
	_scene_data.connections = _scene_data.connections.filter(func(c): return c["from"] != uuid and c["to"] != uuid)
	if _node_map.has(uuid):
		_node_map[uuid].queue_free()
		_node_map.erase(uuid)
	_condition_uuids.erase(uuid)

func rename_sequence(uuid: String, new_name: String, new_subtitle: String = "") -> void:
	for s in _scene_data.sequences:
		if s.uuid == uuid:
			s.seq_name = new_name
			s.subtitle = new_subtitle
			break
	if _node_map.has(uuid):
		_node_map[uuid].set_item_name_and_subtitle(new_name, new_subtitle)

func rename_condition(uuid: String, new_name: String, new_subtitle: String = "") -> void:
	for c in _scene_data.conditions:
		if c.uuid == uuid:
			c.condition_name = new_name
			c.subtitle = new_subtitle
			break
	if _node_map.has(uuid):
		_node_map[uuid].set_item_name_and_subtitle(new_name, new_subtitle)

func add_sequence_connection(from_uuid: String, to_uuid: String) -> void:
	_scene_data.connections.append({"from": from_uuid, "to": to_uuid})
	var key = from_uuid + "→" + to_uuid
	_merge_connection_type(key, "transition")
	_connect_nodes(from_uuid, to_uuid)
	_update_node_colors()

func sync_positions_to_model() -> void:
	for s in _scene_data.sequences:
		if _node_map.has(s.uuid):
			s.position = _node_map[s.uuid].get_item_position()
	for c in _scene_data.conditions:
		if _node_map.has(c.uuid):
			c.position = _node_map[c.uuid].get_item_position()

func _build_connection_type_map() -> void:
	_connection_type_map.clear()
	_choice_connections.clear()
	# Connexions manuelles = transition (on ignore celles issues de séquences "choices")
	for conn in _scene_data.connections:
		if _choice_sequence_uuids.has(conn["from"]):
			continue
		_merge_connection_type(conn["from"] + "→" + conn["to"], "transition")
	# Connexions issues des endings des séquences
	var local_redirect_types = ["redirect_sequence", "redirect_condition"]
	for seq in _scene_data.sequences:
		if seq.ending == null:
			continue
		if seq.ending.type == "auto_redirect" and seq.ending.auto_consequence:
			var cons = seq.ending.auto_consequence
			if cons.type in local_redirect_types and cons.target != "":
				_merge_connection_type(seq.uuid + "→" + cons.target, "transition")
			elif cons.type in TERMINAL_TYPES:
				var terminal_uuid = "terminal_" + cons.type
				if _node_map.has(terminal_uuid):
					_merge_connection_type(seq.uuid + "→" + terminal_uuid, "transition")
		elif seq.ending.type == "choices":
			for i in range(seq.ending.choices.size()):
				var choice = seq.ending.choices[i]
				if choice.consequence == null:
					continue
				var target_uuid = ""
				if choice.consequence.type in local_redirect_types and choice.consequence.target != "":
					target_uuid = choice.consequence.target
				elif choice.consequence.type in TERMINAL_TYPES:
					var terminal_uuid = "terminal_" + choice.consequence.type
					if _node_map.has(terminal_uuid):
						target_uuid = terminal_uuid
				if target_uuid != "":
					# Conserver dans _connection_type_map pour colorer les ports du nœud destination
					_merge_connection_type(seq.uuid + "→" + target_uuid, "choice")
					# Enregistrer la connexion avec le port spécifique au choix
					if _node_map.has(target_uuid):
						_choice_connections.append({"from_uuid": seq.uuid, "from_port": i, "to_uuid": target_uuid})
	# Connexions issues des conditions
	for cond in _scene_data.conditions:
		for rule in cond.rules:
			if rule.consequence == null:
				continue
			if rule.consequence.type in local_redirect_types and rule.consequence.target != "":
				_merge_connection_type(cond.uuid + "→" + rule.consequence.target, "condition")
			elif rule.consequence.type in TERMINAL_TYPES:
				var terminal_uuid = "terminal_" + rule.consequence.type
				if _node_map.has(terminal_uuid):
					_merge_connection_type(cond.uuid + "→" + terminal_uuid, "condition")
		if cond.default_consequence == null:
			continue
		if cond.default_consequence.type in local_redirect_types and cond.default_consequence.target != "":
			_merge_connection_type(cond.uuid + "→" + cond.default_consequence.target, "condition")
		elif cond.default_consequence.type in TERMINAL_TYPES:
			var terminal_uuid = "terminal_" + cond.default_consequence.type
			if _node_map.has(terminal_uuid):
				_merge_connection_type(cond.uuid + "→" + terminal_uuid, "condition")

func _merge_connection_type(key: String, new_type: String) -> void:
	if not _connection_type_map.has(key):
		_connection_type_map[key] = new_type
	elif _connection_type_map[key] != new_type:
		_connection_type_map[key] = "both"

func _connect_all_from_map() -> void:
	for key in _connection_type_map:
		var parts = key.split("→")
		if parts.size() == 2 and not _choice_sequence_uuids.has(parts[0]):
			_connect_nodes(parts[0], parts[1])
	# Connexions multi-ports pour les séquences de type "choices"
	for cc in _choice_connections:
		if _node_map.has(cc["from_uuid"]) and _node_map.has(cc["to_uuid"]):
			connect_node(cc["from_uuid"], cc["from_port"], cc["to_uuid"], 0)

func _update_node_colors() -> void:
	for uuid in _node_map:
		var node = _node_map[uuid]
		if not _terminal_uuids.has(uuid) and not _choice_sequence_uuids.has(uuid):
			node.set_slot_color_right(0, _compute_outgoing_color(uuid))
		node.set_slot_color_left(0, _compute_incoming_color(uuid))

func _compute_outgoing_color(uuid: String) -> Color:
	var has_transition = false
	var has_choice = false
	var has_condition = false
	for key in _connection_type_map:
		if key.begins_with(uuid + "→"):
			var t = _connection_type_map[key]
			if t == "transition" or t == "both":
				has_transition = true
			if t == "choice" or t == "both":
				has_choice = true
			if t == "condition":
				has_condition = true
	if has_transition and has_choice:
		return COLOR_BOTH
	if has_choice:
		return COLOR_CHOICE
	if has_condition:
		return COLOR_CONDITION
	return COLOR_TRANSITION

func _compute_incoming_color(uuid: String) -> Color:
	var has_transition = false
	var has_choice = false
	var has_condition = false
	for key in _connection_type_map:
		if key.ends_with("→" + uuid):
			var t = _connection_type_map[key]
			if t == "transition" or t == "both":
				has_transition = true
			if t == "choice" or t == "both":
				has_choice = true
			if t == "condition":
				has_condition = true
	if has_transition and has_choice:
		return COLOR_BOTH
	if has_choice:
		return COLOR_CHOICE
	if has_condition:
		return COLOR_CONDITION
	return COLOR_TRANSITION

func _create_node(uuid: String, item_name: String, pos: Vector2, subtitle: String = "") -> void:
	var node = GraphNode.new()
	node.set_script(GraphNodeItem)
	add_child(node)
	# Détecter si c'est une séquence de type "choices" pour afficher les ports multi-choix
	var seq_choices = []
	var seq_model = null
	for seq in _scene_data.sequences:
		if seq.uuid == uuid:
			seq_model = seq
			if seq.ending != null and seq.ending.type == "choices":
				seq_choices = seq.ending.choices
			break
	if seq_choices.size() > 0:
		node.setup_as_choice_sequence(uuid, item_name, pos, subtitle, seq_choices)
		_choice_sequence_uuids[uuid] = true
	else:
		node.setup(uuid, item_name, pos, subtitle, false, _has_effects(seq_model) if seq_model else false)
	
	node.setup_sequence_options()
	node.double_clicked.connect(_on_node_double_clicked)
	node.rename_requested.connect(_on_node_rename_requested)
	node.delete_requested.connect(_on_sequence_delete_requested)
	node.entry_point_toggled.connect(_on_entry_point_toggled)
	node.transition_selected.connect(_on_node_transition_selected)
	_node_map[uuid] = node

func _on_node_transition_selected(uuid: String, property: String, value: String) -> void:
	var selected_uuids = []
	var selected_nodes = []
	for child in get_children():
		if child is GraphNode and child.selected:
			selected_nodes.append(child)
	
	# Si le nœud cliqué n'est pas sélectionné, on ne change que lui
	var target_is_selected = false
	for n in selected_nodes:
		if n.name == uuid:
			target_is_selected = true
			break
	
	if target_is_selected:
		for n in selected_nodes:
			# Ne prendre que les séquences (pas les conditions ou terminaux)
			if _node_map.has(n.name) and not _condition_uuids.has(n.name) and not _terminal_uuids.has(n.name):
				selected_uuids.append(n.name)
	else:
		selected_uuids = [uuid]
	
	sequences_transition_requested.emit(selected_uuids, property, value)

func _create_condition_node(uuid: String, item_name: String, pos: Vector2, subtitle: String = "") -> void:
	var node = GraphNode.new()
	node.set_script(GraphNodeItem)
	add_child(node)
	var cond_model = null
	for cond in _scene_data.conditions:
		if cond.uuid == uuid:
			cond_model = cond
			break
	node.setup(uuid, item_name, pos, subtitle, false, _has_effects(cond_model) if cond_model else false)
	# Couleur distincte pour les nœuds condition
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0.25, 0.2, 0.45)
	stylebox.set_corner_radius_all(4)
	node.add_theme_stylebox_override("titlebar", stylebox)
	var stylebox_sel = StyleBoxFlat.new()
	stylebox_sel.bg_color = Color(0.35, 0.3, 0.55)
	stylebox_sel.set_corner_radius_all(4)
	node.add_theme_stylebox_override("titlebar_selected", stylebox_sel)
	node.double_clicked.connect(_on_condition_double_clicked)
	node.rename_requested.connect(_on_condition_rename_requested)
	node.delete_requested.connect(_on_condition_delete_requested)
	node.entry_point_toggled.connect(_on_entry_point_toggled)
	_node_map[uuid] = node
	_condition_uuids[uuid] = true

func _on_node_double_clicked(uuid: String) -> void:
	sequence_double_clicked.emit(uuid)

func _on_condition_double_clicked(uuid: String) -> void:
	condition_double_clicked.emit(uuid)

func _on_node_rename_requested(uuid: String) -> void:
	sequence_rename_requested.emit(uuid)

func _on_condition_rename_requested(uuid: String) -> void:
	condition_rename_requested.emit(uuid)

func _on_sequence_delete_requested(uuid: String) -> void:
	sequence_delete_requested.emit(uuid)

func _on_condition_delete_requested(uuid: String) -> void:
	condition_delete_requested.emit(uuid)

func _on_entry_point_toggled(uuid: String, checked: bool) -> void:
	if checked:
		if _scene_data.entry_point_uuid != "" and _scene_data.entry_point_uuid != uuid and _node_map.has(_scene_data.entry_point_uuid):
			_node_map[_scene_data.entry_point_uuid].set_entry_point(false)
		_scene_data.entry_point_uuid = uuid
	else:
		_scene_data.entry_point_uuid = ""
	entry_point_changed.emit(_scene_data.entry_point_uuid)

func _connect_nodes(from_uuid: String, to_uuid: String) -> void:
	if _node_map.has(from_uuid) and _node_map.has(to_uuid):
		connect_node(from_uuid, 0, to_uuid, 0)

func _clear_nodes() -> void:
	for uuid in _node_map:
		if is_instance_valid(_node_map[uuid]):
			remove_child(_node_map[uuid])
			_node_map[uuid].queue_free()
	_node_map.clear()
	_condition_uuids.clear()
	_terminal_uuids.clear()
	_choice_sequence_uuids.clear()
	_choice_connections.clear()
	_connection_type_map.clear()
	clear_connections()

func _create_needed_terminal_nodes() -> void:
	var needed: Dictionary = {}  # terminal_type → true
	for seq in _scene_data.sequences:
		if seq.ending == null:
			continue
		if seq.ending.type == "choices":
			for choice in seq.ending.choices:
				if choice.consequence and choice.consequence.type in TERMINAL_TYPES:
					needed[choice.consequence.type] = true
		elif seq.ending.type == "auto_redirect" and seq.ending.auto_consequence:
			if seq.ending.auto_consequence.type in TERMINAL_TYPES:
				needed[seq.ending.auto_consequence.type] = true
	for cond in _scene_data.conditions:
		for rule in cond.rules:
			if rule.consequence and rule.consequence.type in TERMINAL_TYPES:
				needed[rule.consequence.type] = true
		if cond.default_consequence and cond.default_consequence.type in TERMINAL_TYPES:
			needed[cond.default_consequence.type] = true
	if needed.is_empty():
		return
	var max_x = 0.0
	for uuid in _node_map:
		if _node_map[uuid].position_offset.x > max_x:
			max_x = _node_map[uuid].position_offset.x
	var y_offset = 0.0
	for terminal_type in needed:
		var uuid = "terminal_" + terminal_type
		var display_name = TERMINAL_DISPLAY_NAMES.get(terminal_type, terminal_type)
		var pos = Vector2(max_x + 280.0, 100.0 + y_offset)
		_create_terminal_node(uuid, display_name, pos, terminal_type)
		y_offset += 80.0

func _create_terminal_node(uuid: String, display_name: String, pos: Vector2, terminal_type: String) -> void:
	var node = GraphNode.new()
	node.set_script(GraphNodeItem)
	add_child(node)
	node.setup(uuid, display_name, pos, "", true)
	var color = TERMINAL_COLORS.get(terminal_type, Color(0.3, 0.3, 0.3))
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = color
	stylebox.set_corner_radius_all(4)
	node.add_theme_stylebox_override("titlebar", stylebox)
	var stylebox_sel = StyleBoxFlat.new()
	stylebox_sel.bg_color = color.lightened(0.15)
	stylebox_sel.set_corner_radius_all(4)
	node.add_theme_stylebox_override("titlebar_selected", stylebox_sel)
	_node_map[uuid] = node
	_terminal_uuids[uuid] = terminal_type
