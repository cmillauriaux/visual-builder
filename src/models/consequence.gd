# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends RefCounted

const VariableEffectScript = preload("res://src/models/variable_effect.gd")

## Types de conséquence valides
const VALID_TYPES := ["redirect_sequence", "redirect_condition", "redirect_scene", "redirect_chapter", "game_over", "to_be_continued", "the_end"]
const REDIRECT_TYPES := ["redirect_sequence", "redirect_condition", "redirect_scene", "redirect_chapter"]

var type: String = ""
var target: String = ""
var effects: Array = []  # Array[VariableEffect]

func is_valid() -> bool:
	if type not in VALID_TYPES:
		return false
	if type in REDIRECT_TYPES and target == "":
		return false
	return true

func to_dict() -> Dictionary:
	var d := {"type": type}
	if type in REDIRECT_TYPES:
		d["target"] = target
	var effects_arr := []
	for e in effects:
		effects_arr.append(e.to_dict())
	d["effects"] = effects_arr
	return d

static func from_dict(d: Dictionary):
	var script = load("res://src/models/consequence.gd")
	var c = script.new()
	c.type = d.get("type", "")
	c.target = d.get("target", "")
	if d.has("effects"):
		for effect_dict in d["effects"]:
			c.effects.append(VariableEffectScript.from_dict(effect_dict))
	return c