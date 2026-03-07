extends RefCounted

var uuid: String = ""
var _fx_type: String = "fade_in"
var _duration: float = 0.5
var _intensity: float = 1.0
var _color: Color = Color.WHITE

const VALID_FX_TYPES = ["screen_shake", "fade_in", "eyes_blink", "flash", "zoom", "vignette", "desaturation"]

var fx_type: String:
	get:
		return _fx_type
	set(value):
		if value in VALID_FX_TYPES:
			_fx_type = value
		else:
			_fx_type = "fade_in"

var duration: float:
	get:
		return _duration
	set(value):
		_duration = clampf(value, 0.1, 5.0)

var intensity: float:
	get:
		return _intensity
	set(value):
		_intensity = clampf(value, 0.1, 3.0)

var color: Color:
	get:
		return _color
	set(value):
		_color = value


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
	return {
		"uuid": uuid,
		"fx_type": fx_type,
		"duration": duration,
		"intensity": intensity,
		"color": color.to_html(),
	}


static func from_dict(d: Dictionary):
	var script = load("res://src/models/sequence_fx.gd")
	var fx = script.new()
	fx.uuid = d.get("uuid", fx.uuid)
	fx.fx_type = d.get("fx_type", "fade_in")
	fx.duration = d.get("duration", 0.5)
	fx.intensity = d.get("intensity", 1.0)
	var color_str = d.get("color", "")
	if color_str != "":
		fx.color = Color.from_string(color_str, Color.WHITE)
	return fx
