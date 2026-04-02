# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends "res://src/commands/base_command.gd"

var _dialogue
var _new_character: String
var _new_text: String
var _old_character: String
var _old_text: String

func _init(dialogue, new_character: String, new_text: String,
		old_character: String, old_text: String) -> void:
	_dialogue = dialogue
	_new_character = new_character
	_new_text = new_text
	_old_character = old_character
	_old_text = old_text

func execute() -> void:
	_dialogue.character = _new_character
	_dialogue.text = _new_text

func undo() -> void:
	_dialogue.character = _old_character
	_dialogue.text = _old_text

func get_label() -> String:
	return "Modification dialogue"