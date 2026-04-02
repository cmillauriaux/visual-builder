# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends "res://src/commands/base_command.gd"

const ConditionScript = preload("res://src/models/condition.gd")

var _scene
var _condition
var _label: String

func _init(scene, condition_name: String, position: Vector2) -> void:
	_scene = scene
	_condition = ConditionScript.new()
	_condition.condition_name = condition_name
	_condition.position = position
	_label = "Ajout condition \"%s\"" % condition_name

func execute() -> void:
	_scene.conditions.append(_condition)

func undo() -> void:
	_scene.conditions.erase(_condition)

func get_label() -> String:
	return _label