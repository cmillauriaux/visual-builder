# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends "res://src/commands/base_command.gd"

var _chapter
var _scene
var _index: int
var _label: String

func _init(chapter, scene) -> void:
	_chapter = chapter
	_scene = scene
	_index = chapter.scenes.find(scene)
	_label = "Suppression scène \"%s\"" % scene.scene_name

func execute() -> void:
	_chapter.scenes.erase(_scene)

func undo() -> void:
	_chapter.scenes.insert(_index, _scene)

func get_label() -> String:
	return _label