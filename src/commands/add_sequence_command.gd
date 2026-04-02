# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends "res://src/commands/base_command.gd"

const SequenceScript = preload("res://src/models/sequence.gd")

var _scene
var _sequence
var _label: String

func _init(scene, seq_name: String, position: Vector2) -> void:
	_scene = scene
	_sequence = SequenceScript.new()
	_sequence.seq_name = seq_name
	_sequence.position = position
	_label = "Ajout séquence \"%s\"" % seq_name

func execute() -> void:
	_scene.sequences.append(_sequence)

func undo() -> void:
	_scene.sequences.erase(_sequence)

func get_label() -> String:
	return _label