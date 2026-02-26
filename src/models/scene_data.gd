extends RefCounted

const SequenceScript = preload("res://src/models/sequence.gd")
const ConditionScript = preload("res://src/models/condition.gd")

var uuid: String = ""
var scene_name: String = ""
var subtitle: String = ""
var position: Vector2 = Vector2.ZERO
var sequences: Array = []  # Array[Sequence]
var conditions: Array = []  # Array[Condition]
var connections: Array = []  # Array[Dictionary] — {"from": uuid, "to": uuid}
var entry_point_uuid: String = ""

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

func find_sequence(seq_uuid: String):
	for seq in sequences:
		if seq.uuid == seq_uuid:
			return seq
	return null

func find_condition(cond_uuid: String):
	for cond in conditions:
		if cond.uuid == cond_uuid:
			return cond
	return null

func to_dict() -> Dictionary:
	var seq_arr := []
	for seq in sequences:
		seq_arr.append(seq.to_dict())

	var conn_arr := []
	for conn in connections:
		conn_arr.append(conn)

	var cond_arr := []
	for cond in conditions:
		cond_arr.append(cond.to_dict())

	return {
		"uuid": uuid,
		"name": scene_name,
		"subtitle": subtitle,
		"sequences": seq_arr,
		"conditions": cond_arr,
		"connections": conn_arr,
		"entry_point": entry_point_uuid,
	}

static func from_dict(d: Dictionary):
	var script = load("res://src/models/scene_data.gd")
	var scene = script.new()
	scene.uuid = d.get("uuid", scene.uuid)
	scene.scene_name = d.get("name", "")
	scene.subtitle = d.get("subtitle", "")
	if d.has("position"):
		scene.position = Vector2(d["position"].get("x", 0), d["position"].get("y", 0))

	if d.has("sequences"):
		for seq_dict in d["sequences"]:
			scene.sequences.append(SequenceScript.from_dict(seq_dict))

	if d.has("conditions"):
		for cond_dict in d["conditions"]:
			scene.conditions.append(ConditionScript.from_dict(cond_dict))

	if d.has("connections"):
		for conn in d["connections"]:
			scene.connections.append(conn)

	scene.entry_point_uuid = d.get("entry_point", "")

	return scene
