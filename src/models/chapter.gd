extends RefCounted

const SceneDataScript = preload("res://src/models/scene_data.gd")

var uuid: String = ""
var chapter_name: String = ""
var position: Vector2 = Vector2.ZERO
var scenes: Array = []  # Array[SceneData]
var connections: Array = []  # Array[Dictionary] — {"from": uuid, "to": uuid}

func _init():
	uuid = _generate_uuid()

static func _generate_uuid() -> String:
	var chars = "abcdef0123456789"
	var result = ""
	for i in range(8):
		result += chars[randi() % chars.length()]
	result += "-"
	for i in range(4):
		result += chars[randi() % chars.length()]
	result += "-4"
	for i in range(3):
		result += chars[randi() % chars.length()]
	result += "-"
	for i in range(4):
		result += chars[randi() % chars.length()]
	result += "-"
	for i in range(12):
		result += chars[randi() % chars.length()]
	return result

func find_scene(scene_uuid: String):
	for scene in scenes:
		if scene.uuid == scene_uuid:
			return scene
	return null

func to_dict_header() -> Dictionary:
	return {
		"uuid": uuid,
		"name": chapter_name,
		"position": {"x": position.x, "y": position.y},
	}

func to_dict() -> Dictionary:
	var scene_headers := []
	for scene in scenes:
		scene_headers.append({
			"uuid": scene.uuid,
			"name": scene.scene_name,
			"position": {"x": scene.position.x, "y": scene.position.y},
		})

	var conn_arr := []
	for conn in connections:
		conn_arr.append(conn)

	return {
		"uuid": uuid,
		"name": chapter_name,
		"scenes": scene_headers,
		"connections": conn_arr,
	}

static func from_dict_header(d: Dictionary):
	var script = load("res://src/models/chapter.gd")
	var ch = script.new()
	ch.uuid = d.get("uuid", ch.uuid)
	ch.chapter_name = d.get("name", "")
	if d.has("position"):
		ch.position = Vector2(d["position"].get("x", 0), d["position"].get("y", 0))
	return ch

static func from_dict(d: Dictionary):
	var script = load("res://src/models/chapter.gd")
	var ch = script.new()
	ch.uuid = d.get("uuid", ch.uuid)
	ch.chapter_name = d.get("name", "")
	if d.has("position"):
		ch.position = Vector2(d["position"].get("x", 0), d["position"].get("y", 0))

	if d.has("scenes"):
		for scene_dict in d["scenes"]:
			ch.scenes.append(SceneDataScript.from_dict(scene_dict))

	if d.has("connections"):
		for conn in d["connections"]:
			ch.connections.append(conn)

	return ch
