# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends VBoxContainer

## Panel de liste des dialogues avec drag & drop pour réordonner.

const DialogueListItemScript = preload("res://src/ui/sequence/dialogue_list_item.gd")

var _seq_editor = null
var _items: Array = []

signal dialogue_delete_requested(index: int)

func setup(seq_editor) -> void:
	_seq_editor = seq_editor
	rebuild()

func rebuild() -> void:
	# Retirer les anciens items
	for item in _items:
		if is_instance_valid(item):
			item.queue_free()
	_items.clear()

	if _seq_editor == null:
		return
	var seq = _seq_editor.get_sequence()
	if seq == null:
		return

	for i in range(seq.dialogues.size()):
		var dlg = seq.dialogues[i]
		var item = PanelContainer.new()
		item.set_script(DialogueListItemScript)
		item.setup(i, dlg, _seq_editor, self)
		add_child(item)
		_items.append(item)

func get_item_count() -> int:
	return _items.size()

func get_item(index: int):
	if index < 0 or index >= _items.size():
		return null
	return _items[index]

func select_item(index: int) -> void:
	if _seq_editor:
		_seq_editor.select_dialogue(index)

func highlight_item(index: int) -> void:
	for i in range(_items.size()):
		if is_instance_valid(_items[i]):
			_items[i].set_highlighted(i == index)

func request_delete(index: int) -> void:
	dialogue_delete_requested.emit(index)

func on_drop_reorder(from_index: int, to_index: int) -> void:
	if _seq_editor == null:
		return
	_seq_editor.move_dialogue(from_index, to_index)
	rebuild()