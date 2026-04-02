# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends RefCounted

## Notification déclenchée quand une variable correspondant au pattern glob est modifiée.

var pattern: String = ""
var message: String = ""


func matches(var_name: String) -> bool:
	var regex_pattern = "^" + _glob_to_regex(pattern) + "$"
	var regex = RegEx.new()
	if regex.compile(regex_pattern) != OK:
		return false
	return regex.search(var_name) != null


func to_dict() -> Dictionary:
	return {
		"pattern": pattern,
		"message": message,
	}


static func from_dict(d: Dictionary):
	var script = load("res://src/models/story_notification.gd")
	var n = script.new()
	n.pattern = d.get("pattern", "")
	n.message = d.get("message", "")
	return n


static func _glob_to_regex(glob: String) -> String:
	## Convertit un pattern glob (*, ?) en regex. Les autres caractères spéciaux sont échappés.
	var regex_special := "\\^$.|+()[]{}"
	var result := ""
	for i in range(glob.length()):
		var c := glob[i]
		if c == "*":
			result += ".*"
		elif c == "?":
			result += "."
		elif regex_special.find(c) >= 0:
			result += "\\" + c
		else:
			result += c
	return result