# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends "res://src/commands/base_command.gd"

var _foreground
var _old_image: String
var _new_image: String

func _init(foreground, new_image: String) -> void:
	_foreground = foreground
	_old_image = foreground.image
	_new_image = new_image

func execute() -> void:
	_foreground.image = _new_image

func undo() -> void:
	_foreground.image = _old_image

func get_label() -> String:
	return "Remplacer l'image du foreground"