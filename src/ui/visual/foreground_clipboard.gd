# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends RefCounted

## Presse-papiers interne pour copier/coller les paramètres de positionnement d'un foreground.
## Stocke scale, anchor_bg, anchor_fg, flip_h, flip_v.
## Supporte aussi la copie complète d'un foreground (toutes les propriétés).

var data = null  # null = pas de données copiées (paramètres)
var fg_data = null  # null = pas de foreground copié

func has_data() -> bool:
	return data != null

func has_foreground_data() -> bool:
	return fg_data != null

func copy_from(fg) -> void:
	data = {
		"scale": fg.scale,
		"anchor_bg": Vector2(fg.anchor_bg.x, fg.anchor_bg.y),
		"anchor_fg": Vector2(fg.anchor_fg.x, fg.anchor_fg.y),
		"flip_h": fg.flip_h,
		"flip_v": fg.flip_v,
	}

func paste_to(fg) -> bool:
	if not has_data():
		return false
	fg.scale = data.scale
	fg.anchor_bg = Vector2(data.anchor_bg.x, data.anchor_bg.y)
	fg.anchor_fg = Vector2(data.anchor_fg.x, data.anchor_fg.y)
	fg.flip_h = data.flip_h
	fg.flip_v = data.flip_v
	return true

func copy_foreground(fg) -> void:
	fg_data = [fg.to_dict()]

func copy_foregrounds(fgs: Array) -> void:
	fg_data = []
	for fg in fgs:
		fg_data.append(fg.to_dict())

func paste_foreground():
	if not has_foreground_data():
		return null
	var ForegroundScript = load("res://src/models/foreground.gd")
	var new_fg = ForegroundScript.from_dict(fg_data[0])
	new_fg.uuid = ForegroundScript._generate_uuid()
	return new_fg

func paste_foregrounds() -> Array:
	if not has_foreground_data():
		return []
	var ForegroundScript = load("res://src/models/foreground.gd")
	var result := []
	for d in fg_data:
		var new_fg = ForegroundScript.from_dict(d)
		new_fg.uuid = ForegroundScript._generate_uuid()
		result.append(new_fg)
	return result