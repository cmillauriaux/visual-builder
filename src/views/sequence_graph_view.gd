extends GraphEdit

## Vue graphe des séquences (niveau 3).

const GraphNodeItem = preload("res://src/views/graph_node_item.gd")
const SequenceScript = preload("res://src/models/sequence.gd")

signal sequence_double_clicked(sequence_uuid: String)
signal sequence_rename_requested(sequence_uuid: String)

var _scene_data = null
var _node_map: Dictionary = {}  # uuid → GraphNode

func load_scene(scene_data) -> void:
	_scene_data = scene_data
	_clear_nodes()
	for seq in _scene_data.sequences:
		_create_node(seq.uuid, seq.seq_name, seq.position, seq.subtitle)
	for conn in _scene_data.connections:
		_connect_nodes(conn["from"], conn["to"])
	_add_ending_connections()

func get_scene_data():
	return _scene_data

func get_node_count() -> int:
	return _node_map.size()

func add_new_sequence(seq_name: String, pos: Vector2) -> void:
	var seq = SequenceScript.new()
	seq.seq_name = seq_name
	seq.position = pos
	_scene_data.sequences.append(seq)
	_create_node(seq.uuid, seq.seq_name, seq.position, "")

func remove_sequence(uuid: String) -> void:
	for i in range(_scene_data.sequences.size()):
		if _scene_data.sequences[i].uuid == uuid:
			_scene_data.sequences.remove_at(i)
			break
	_scene_data.connections = _scene_data.connections.filter(func(c): return c["from"] != uuid and c["to"] != uuid)
	if _node_map.has(uuid):
		_node_map[uuid].queue_free()
		_node_map.erase(uuid)

func rename_sequence(uuid: String, new_name: String, new_subtitle: String = "") -> void:
	for s in _scene_data.sequences:
		if s.uuid == uuid:
			s.seq_name = new_name
			s.subtitle = new_subtitle
			break
	if _node_map.has(uuid):
		_node_map[uuid].set_item_name_and_subtitle(new_name, new_subtitle)

func add_sequence_connection(from_uuid: String, to_uuid: String) -> void:
	_scene_data.connections.append({"from": from_uuid, "to": to_uuid})
	_connect_nodes(from_uuid, to_uuid)

func sync_positions_to_model() -> void:
	for s in _scene_data.sequences:
		if _node_map.has(s.uuid):
			s.position = _node_map[s.uuid].get_item_position()

func _create_node(uuid: String, item_name: String, pos: Vector2, subtitle: String = "") -> void:
	var node = GraphNode.new()
	node.set_script(GraphNodeItem)
	add_child(node)
	node.setup(uuid, item_name, pos, subtitle)
	node.double_clicked.connect(_on_node_double_clicked)
	node.rename_requested.connect(_on_node_rename_requested)
	_node_map[uuid] = node

func _on_node_double_clicked(uuid: String) -> void:
	sequence_double_clicked.emit(uuid)

func _on_node_rename_requested(uuid: String) -> void:
	sequence_rename_requested.emit(uuid)

func _connect_nodes(from_uuid: String, to_uuid: String) -> void:
	if _node_map.has(from_uuid) and _node_map.has(to_uuid):
		connect_node(from_uuid, 0, to_uuid, 0)

func _add_ending_connections() -> void:
	if _scene_data == null:
		return
	# Collect existing connections as a set for dedup
	var existing := {}
	for conn in _scene_data.connections:
		existing[conn["from"] + "→" + conn["to"]] = true
	# Scan all sequences for ending-based connections
	for seq in _scene_data.sequences:
		if seq.ending == null:
			continue
		var targets := []
		if seq.ending.type == "auto_redirect" and seq.ending.auto_consequence:
			if seq.ending.auto_consequence.type == "redirect_sequence" and seq.ending.auto_consequence.target != "":
				targets.append(seq.ending.auto_consequence.target)
		elif seq.ending.type == "choices":
			for choice in seq.ending.choices:
				if choice.consequence and choice.consequence.type == "redirect_sequence" and choice.consequence.target != "":
					targets.append(choice.consequence.target)
		for target_uuid in targets:
			var key = seq.uuid + "→" + target_uuid
			if not existing.has(key):
				existing[key] = true
				_connect_nodes(seq.uuid, target_uuid)

func _clear_nodes() -> void:
	for uuid in _node_map:
		if is_instance_valid(_node_map[uuid]):
			_node_map[uuid].queue_free()
	_node_map.clear()
	clear_connections()
