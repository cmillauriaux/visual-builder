# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends "res://src/commands/base_command.gd"

const SceneDataScript = preload("res://src/models/scene_data.gd")

var _chapter
var _scene
var _label: String

func _init(chapter, scene_name: String, position: Vector2) -> void:
	_chapter = chapter
	_scene = SceneDataScript.new()
	_scene.scene_name = scene_name
	_scene.position = position
	_label = "Ajout scène \"%s\"" % scene_name

func execute() -> void:
	_chapter.scenes.append(_scene)

func undo() -> void:
	_chapter.scenes.erase(_scene)

func get_label() -> String:
	return _label