# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends Control

## Éditeur de dialogues pour une séquence.

const DialogueScript = preload("res://src/models/dialogue.gd")

var _sequence = null

func load_sequence(sequence) -> void:
	_sequence = sequence

func get_dialogue_count() -> int:
	if _sequence == null:
		return 0
	return _sequence.dialogues.size()

func add_dialogue(character: String, text: String) -> void:
	if _sequence == null:
		return
	var dlg = DialogueScript.new()
	dlg.character = character
	dlg.text = text
	_sequence.dialogues.append(dlg)

func modify_dialogue(index: int, character: String, text: String) -> void:
	if _sequence == null or index < 0 or index >= _sequence.dialogues.size():
		return
	_sequence.dialogues[index].character = character
	_sequence.dialogues[index].text = text

func remove_dialogue(index: int) -> void:
	if _sequence == null or index < 0 or index >= _sequence.dialogues.size():
		return
	_sequence.dialogues.remove_at(index)

func move_dialogue(from_index: int, to_index: int) -> void:
	if _sequence == null:
		return
	if from_index < 0 or from_index >= _sequence.dialogues.size():
		return
	if to_index < 0 or to_index > _sequence.dialogues.size():
		return
	var dlg = _sequence.dialogues[from_index]
	_sequence.dialogues.remove_at(from_index)
	_sequence.dialogues.insert(to_index, dlg)