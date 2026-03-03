extends RefCounted

class_name SequenceModel

const ForegroundScript = preload("res://src/models/foreground.gd")
const DialogueScript = preload("res://src/models/dialogue.gd")
const EndingScript = preload("res://src/models/ending.gd")
const SequenceFxScript = preload("res://src/models/sequence_fx.gd")

var uuid: String = ""
var seq_name: String = ""
var title: String = ""
var subtitle: String = ""
var position: Vector2 = Vector2.ZERO
var background: String = ""
var background_color: String = "00000000" # Transparent par défaut
var foregrounds: Array = []  # Array[Foreground]
var dialogues: Array = []  # Array[Dialogue]
var ending = null  # Ending
var fx: Array = []  # Array[SequenceFx]

# Transitions
var transition_in_type: String = "none" # "none", "fade", "pixelate"
var transition_in_duration: float = 0.5
var transition_out_type: String = "none" # "none", "fade", "pixelate"
var transition_out_duration: float = 0.5

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

	var dlg_arr := []
	for dlg in dialogues:
		dlg_arr.append(dlg.to_dict())

	var fx_arr := []
	for f in fx:
		fx_arr.append(f.to_dict())

	var d := {
		"uuid": uuid,
		"name": seq_name,
		"title": title,
		"subtitle": subtitle,
		"position": {"x": position.x, "y": position.y},
		"background": background,
		"background_color": background_color,
		"foregrounds": fg_arr,
		"dialogues": dlg_arr,
		"fx": fx_arr,
		"transition_in_type": transition_in_type,
		"transition_in_duration": transition_in_duration,
		"transition_out_type": transition_out_type,
		"transition_out_duration": transition_out_duration,
	}

	if ending:
		d["ending"] = ending.to_dict()

	return d

static func from_dict(d: Dictionary):
	var script = load("res://src/models/sequence.gd")
	var seq = script.new()
	seq.uuid = d.get("uuid", seq.uuid)
	seq.seq_name = d.get("name", "")
	seq.title = d.get("title", "")
	seq.subtitle = d.get("subtitle", "")
	if d.has("position"):
		seq.position = Vector2(d["position"]["x"], d["position"]["y"])
	seq.background = d.get("background", "")
	seq.background_color = d.get("background_color", "00000000")

	# Transitions
	seq.transition_in_type = d.get("transition_in_type", "none")
	seq.transition_in_duration = d.get("transition_in_duration", 0.5)
	seq.transition_out_type = d.get("transition_out_type", "none")
	seq.transition_out_duration = d.get("transition_out_duration", 0.5)

	if d.has("foregrounds"):
		for fg_dict in d["foregrounds"]:
			seq.foregrounds.append(ForegroundScript.from_dict(fg_dict))

	if d.has("dialogues"):
		for dlg_dict in d["dialogues"]:
			seq.dialogues.append(DialogueScript.from_dict(dlg_dict))

	if d.has("fx"):
		for fx_dict in d["fx"]:
			seq.fx.append(SequenceFxScript.from_dict(fx_dict))

	if d.has("ending"):
		seq.ending = EndingScript.from_dict(d["ending"])

	return seq
