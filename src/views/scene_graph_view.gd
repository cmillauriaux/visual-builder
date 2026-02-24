extends GraphEdit

## Vue graphe des scènes (niveau 2).

const GraphNodeItem = preload("res://src/views/graph_node_item.gd")
const SceneDataScript = preload("res://src/models/scene_data.gd")

signal scene_double_clicked(scene_uuid: String)

var _chapter = null
var _node_map: Dictionary = {}  # uuid → GraphNode

func load_chapter(chapter) -> void:
	_chapter = chapter
	_clear_nodes()
	for scene in _chapter.scenes:
		_create_node(scene.uuid, scene.scene_name, scene.position)
	for conn in _chapter.connections:
		_connect_nodes(conn["from"], conn["to"])
	_add_ending_connections()

func get_chapter():
	return _chapter

func get_node_count() -> int:
	return _node_map.size()

func add_new_scene(scene_name: String, pos: Vector2) -> void:
	var scene = SceneDataScript.new()
	scene.scene_name = scene_name
	scene.position = pos
	_chapter.scenes.append(scene)
	_create_node(scene.uuid, scene.scene_name, scene.position)

func remove_scene(uuid: String) -> void:
	for i in range(_chapter.scenes.size()):
		if _chapter.scenes[i].uuid == uuid:
			_chapter.scenes.remove_at(i)
			break
	_chapter.connections = _chapter.connections.filter(func(c): return c["from"] != uuid and c["to"] != uuid)
	if _node_map.has(uuid):
		_node_map[uuid].queue_free()
		_node_map.erase(uuid)

func rename_scene(uuid: String, new_name: String) -> void:
	for s in _chapter.scenes:
		if s.uuid == uuid:
			s.scene_name = new_name
			break
	if _node_map.has(uuid):
		_node_map[uuid].set_item_name(new_name)

func add_scene_connection(from_uuid: String, to_uuid: String) -> void:
	_chapter.connections.append({"from": from_uuid, "to": to_uuid})
	_connect_nodes(from_uuid, to_uuid)

func sync_positions_to_model() -> void:
	for s in _chapter.scenes:
		if _node_map.has(s.uuid):
			s.position = _node_map[s.uuid].get_item_position()

func _create_node(uuid: String, item_name: String, pos: Vector2) -> void:
	var node = GraphNode.new()
	node.set_script(GraphNodeItem)
	add_child(node)
	node.setup(uuid, item_name, pos)
	node.double_clicked.connect(_on_node_double_clicked)
	_node_map[uuid] = node

func _on_node_double_clicked(uuid: String) -> void:
	scene_double_clicked.emit(uuid)

func _connect_nodes(from_uuid: String, to_uuid: String) -> void:
	if _node_map.has(from_uuid) and _node_map.has(to_uuid):
		connect_node(from_uuid, 0, to_uuid, 0)

func _add_ending_connections() -> void:
	if _chapter == null:
		return
	var existing := {}
	for conn in _chapter.connections:
		existing[conn["from"] + "→" + conn["to"]] = true
	# Scan all sequences in all scenes for redirect_scene endings
	for scene in _chapter.scenes:
		for seq in scene.sequences:
			if seq.ending == null:
				continue
			var targets := []
			if seq.ending.type == "auto_redirect" and seq.ending.auto_consequence:
				if seq.ending.auto_consequence.type == "redirect_scene" and seq.ending.auto_consequence.target != "":
					targets.append(seq.ending.auto_consequence.target)
			elif seq.ending.type == "choices":
				for choice in seq.ending.choices:
					if choice.consequence and choice.consequence.type == "redirect_scene" and choice.consequence.target != "":
						targets.append(choice.consequence.target)
			for target_uuid in targets:
				var key = scene.uuid + "→" + target_uuid
				if not existing.has(key):
					existing[key] = true
					_connect_nodes(scene.uuid, target_uuid)

func _clear_nodes() -> void:
	for uuid in _node_map:
		if is_instance_valid(_node_map[uuid]):
			_node_map[uuid].queue_free()
	_node_map.clear()
	clear_connections()
