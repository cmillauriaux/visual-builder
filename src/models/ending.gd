# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends RefCounted

const ConsequenceScript = preload("res://src/models/consequence.gd")
const ChoiceScript = preload("res://src/models/choice.gd")

var type: String = ""
var choices: Array = []  # Array[Choice]
var auto_consequence = null  # Consequence

func is_valid() -> bool:
	if type == "choices":
		return choices.size() >= 1 and choices.size() <= 8
	elif type == "auto_redirect":
		return auto_consequence != null and auto_consequence.is_valid()
	return false

func to_dict() -> Dictionary:
	if type == "choices":
		var choices_arr := []
		for choice in choices:
			choices_arr.append(choice.to_dict())
		return {"type": "choices", "choices": choices_arr}
	elif type == "auto_redirect":
		return {
			"type": "auto_redirect",
			"consequence": auto_consequence.to_dict() if auto_consequence else {},
		}
	return {"type": type}

static func from_dict(d: Dictionary):
	var script = load("res://src/models/ending.gd")
	var e = script.new()
	e.type = d.get("type", "")
	if e.type == "choices" and d.has("choices"):
		for choice_dict in d["choices"]:
			e.choices.append(ChoiceScript.from_dict(choice_dict))
	elif e.type == "auto_redirect" and d.has("consequence"):
		e.auto_consequence = ConsequenceScript.from_dict(d["consequence"])
	return e