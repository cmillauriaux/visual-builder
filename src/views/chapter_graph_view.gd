extends GraphEdit

## Vue graphe des chapitres (niveau 1).

const GraphNodeItem = preload("res://src/views/graph_node_item.gd")
const ChapterScript = preload("res://src/models/chapter.gd")

signal chapter_double_clicked(chapter_uuid: String)

var _story = null
var _node_map: Dictionary = {}  # uuid → GraphNode

func load_story(story) -> void:
	_story = story
	_clear_nodes()
	for chapter in _story.chapters:
		_create_node(chapter.uuid, chapter.chapter_name, chapter.position)
	# Restaurer les connexions
	for conn in _story.connections:
		_connect_nodes(conn["from"], conn["to"])

func get_story():
	return _story

func get_node_count() -> int:
	return _node_map.size()

func add_new_chapter(chapter_name: String, pos: Vector2) -> void:
	var chapter = ChapterScript.new()
	chapter.chapter_name = chapter_name
	chapter.position = pos
	_story.chapters.append(chapter)
	_create_node(chapter.uuid, chapter.chapter_name, chapter.position)

func remove_chapter(uuid: String) -> void:
	# Supprimer du modèle
	for i in range(_story.chapters.size()):
		if _story.chapters[i].uuid == uuid:
			_story.chapters.remove_at(i)
			break
	# Supprimer les connexions liées
	_story.connections = _story.connections.filter(func(c): return c["from"] != uuid and c["to"] != uuid)
	# Supprimer le noeud
	if _node_map.has(uuid):
		_node_map[uuid].queue_free()
		_node_map.erase(uuid)

func rename_chapter(uuid: String, new_name: String) -> void:
	for ch in _story.chapters:
		if ch.uuid == uuid:
			ch.chapter_name = new_name
			break
	if _node_map.has(uuid):
		_node_map[uuid].set_item_name(new_name)

func add_story_connection(from_uuid: String, to_uuid: String) -> void:
	_story.connections.append({"from": from_uuid, "to": to_uuid})
	_connect_nodes(from_uuid, to_uuid)

func sync_positions_to_model() -> void:
	for ch in _story.chapters:
		if _node_map.has(ch.uuid):
			ch.position = _node_map[ch.uuid].get_item_position()

func _create_node(uuid: String, item_name: String, pos: Vector2) -> void:
	var node = GraphNode.new()
	node.set_script(GraphNodeItem)
	add_child(node)
	node.setup(uuid, item_name, pos)
	node.double_clicked.connect(_on_node_double_clicked)
	_node_map[uuid] = node

func _on_node_double_clicked(uuid: String) -> void:
	chapter_double_clicked.emit(uuid)

func _connect_nodes(from_uuid: String, to_uuid: String) -> void:
	if _node_map.has(from_uuid) and _node_map.has(to_uuid):
		connect_node(from_uuid, 0, to_uuid, 0)

func _clear_nodes() -> void:
	for uuid in _node_map:
		if is_instance_valid(_node_map[uuid]):
			_node_map[uuid].queue_free()
	_node_map.clear()
	clear_connections()
