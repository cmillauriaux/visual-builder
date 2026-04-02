# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends RefCounted

var uuid: String = ""
var fg_name: String = ""
var image: String = ""
var z_order: int = 0
var _opacity: float = 1.0
var flip_h: bool = false
var flip_v: bool = false
var scale: float = 1.0
var anchor_bg: Vector2 = Vector2(0.5, 0.5)
var anchor_fg: Vector2 = Vector2(0.5, 1.0)
var _transition_type: String = "none"
var _transition_duration: float = 0.5

const VALID_TRANSITION_TYPES = ["none", "fade"]

var transition_type: String:
	get:
		return _transition_type
	set(value):
		if value in VALID_TRANSITION_TYPES:
			_transition_type = value
		else:
			_transition_type = "none"

var transition_duration: float:
	get:
		return _transition_duration
	set(value):
		_transition_duration = clampf(value, 0.1, 5.0)

var opacity: float:
	get:
		return _opacity
	set(value):
		_opacity = clampf(value, 0.0, 1.0)

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
		"name": fg_name,
		"image": image,
		"z_order": z_order,
		"opacity": opacity,
		"flip_h": flip_h,
		"flip_v": flip_v,
		"scale": scale,
		"anchor_bg": {"x": anchor_bg.x, "y": anchor_bg.y},
		"anchor_fg": {"x": anchor_fg.x, "y": anchor_fg.y},
		"transition_type": transition_type,
		"transition_duration": transition_duration,
	}

static func from_dict(d: Dictionary):
	var script = load("res://src/models/foreground.gd")
	var fg = script.new()
	fg.uuid = d.get("uuid", fg.uuid)
	fg.fg_name = d.get("name", "")
	fg.image = d.get("image", "")
	fg.z_order = d.get("z_order", 0)
	fg.opacity = d.get("opacity", 1.0)
	fg.flip_h = d.get("flip_h", false)
	fg.flip_v = d.get("flip_v", false)
	fg.scale = d.get("scale", 1.0)
	if d.has("anchor_bg"):
		fg.anchor_bg = Vector2(d["anchor_bg"]["x"], d["anchor_bg"]["y"])
	if d.has("anchor_fg"):
		fg.anchor_fg = Vector2(d["anchor_fg"]["x"], d["anchor_fg"]["y"])
	fg.transition_type = d.get("transition_type", "none")
	fg.transition_duration = d.get("transition_duration", 0.5)
	return fg