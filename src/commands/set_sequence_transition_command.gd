# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends "res://src/commands/base_command.gd"

## Commande pour modifier le type de transition d'une ou plusieurs séquences.

var _sequences: Array
var _property: String # "transition_in_type" ou "transition_out_type"
var _new_value: String
var _old_values: Dictionary = {} # uuid -> old_value

func _init(sequences: Array, property: String, new_value: String) -> void:
	_sequences = sequences
	_property = property
	_new_value = new_value
	for s in _sequences:
		_old_values[s.uuid] = s.get(_property)

func execute() -> void:
	for s in _sequences:
		s.set(_property, _new_value)

func undo() -> void:
	for s in _sequences:
		s.set(_property, _old_values[s.uuid])

func get_label() -> String:
	var prop_name = "Transition d'entrée" if _property == "transition_in_type" else "Transition de sortie"
	var type_name = "Aucune"
	match _new_value:
		"fade": type_name = "Fondu"
		"pixelate": type_name = "Pixellisation"
	
	if _sequences.size() == 1:
		return "Modifier %s : %s" % [prop_name, type_name]
	return "Modifier %s : %s (%d séquences)" % [prop_name, type_name, _sequences.size()]