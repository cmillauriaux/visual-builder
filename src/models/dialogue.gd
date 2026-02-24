extends RefCounted

const ForegroundScript = preload("res://src/models/foreground.gd")

var uuid: String = ""
var character: String = ""
var text: String = ""
var foregrounds: Array = []  # Array[Foreground]

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

func to_dict() -> Dictionary:
	var fg_arr := []
	for fg in foregrounds:
		fg_arr.append(fg.to_dict())
	return {
		"uuid": uuid,
		"character": character,
		"text": text,
		"foregrounds": fg_arr,
	}

static func from_dict(d: Dictionary):
	var script = load("res://src/models/dialogue.gd")
	var dlg = script.new()
	dlg.uuid = d.get("uuid", dlg.uuid)
	dlg.character = d.get("character", "")
	dlg.text = d.get("text", "")
	if d.has("foregrounds"):
		for fg_dict in d["foregrounds"]:
			dlg.foregrounds.append(ForegroundScript.from_dict(fg_dict))
	return dlg
