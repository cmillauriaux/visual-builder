extends RefCounted

class_name DialogueModel

const ForegroundScript = preload("res://src/models/foreground.gd")

var uuid: String = ""
var character: String = ""
var text: String = ""
var voice: String = ""  # Optional: ElevenLabs voice description with annotations ([sarcastically], [whispers], etc.)
var voice_file: String = ""  # Optional: path to generated MP3 voice file (e.g. "assets/voices/uuid.mp3")
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
	var d := {
		"uuid": uuid,
		"character": character,
		"text": text,
		"foregrounds": fg_arr,
	}
	if voice != "":
		d["voice"] = voice
	if voice_file != "":
		d["voice_file"] = voice_file
	return d

static func from_dict(d: Dictionary):
	var script = load("res://src/models/dialogue.gd")
	var dlg = script.new()
	dlg.uuid = d.get("uuid", dlg.uuid)
	dlg.character = d.get("character", "")
	dlg.text = d.get("text", "")
	dlg.voice = d.get("voice", "")
	dlg.voice_file = d.get("voice_file", "")
	if d.has("foregrounds"):
		for fg_dict in d["foregrounds"]:
			dlg.foregrounds.append(ForegroundScript.from_dict(fg_dict))
	return dlg
