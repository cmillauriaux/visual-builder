# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends RefCounted

var uuid: String = ""
var _fx_type: String = "fade_in"
var _duration: float = 0.5
var _intensity: float = 1.0
var _color: Color = Color.WHITE
var _zoom_from: float = 1.0
var _zoom_to: float = 1.5
var continue_during_fx: bool = false

const VALID_FX_TYPES = [
	"screen_shake", "fade_in", "eyes_blink", "flash", "zoom", "vignette", "desaturation",
	"zoom_in", "zoom_out",
	"pan_right", "pan_left", "pan_down", "pan_up",
]

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

var zoom_from: float:
	get:
		return _zoom_from
	set(value):
		_zoom_from = maxf(value, 1.0)

var zoom_to: float:
	get:
		return _zoom_to
	set(value):
		_zoom_to = maxf(value, 1.0)


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
		"zoom_from": zoom_from,
		"zoom_to": zoom_to,
		"continue_during_fx": continue_during_fx,
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
	fx.zoom_from = d.get("zoom_from", 1.0)
	fx.zoom_to = d.get("zoom_to", 1.5)
	fx.continue_during_fx = d.get("continue_during_fx", false)
	return fx