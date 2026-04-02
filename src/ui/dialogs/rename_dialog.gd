# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends ConfirmationDialog

## Dialogue de renommage pour les noeuds de graphe.

signal rename_confirmed(uuid: String, new_name: String, new_subtitle: String)

var _uuid: String = ""
var _name_edit: LineEdit
var _subtitle_edit: LineEdit

func _init():
	title = tr("Renommer")
	min_size = Vector2i(350, 0)

	var vbox = VBoxContainer.new()
	vbox.name = "ContentVBox"

	var name_label = Label.new()
	name_label.text = tr("Titre")
	vbox.add_child(name_label)

	_name_edit = LineEdit.new()
	_name_edit.name = "NameEdit"
	vbox.add_child(_name_edit)

	var subtitle_label = Label.new()
	subtitle_label.text = tr("Description (optionnel)")
	vbox.add_child(subtitle_label)

	_subtitle_edit = LineEdit.new()
	_subtitle_edit.name = "SubtitleEdit"
	vbox.add_child(_subtitle_edit)

	add_child(vbox)

	_name_edit.text_changed.connect(_on_name_text_changed)
	confirmed.connect(_on_confirmed)

func setup(uuid: String, current_name: String, current_subtitle: String) -> void:
	_uuid = uuid
	_name_edit.text = current_name
	_subtitle_edit.text = current_subtitle
	_update_ok_button()

func _on_name_text_changed(_new_text: String) -> void:
	_update_ok_button()

func _update_ok_button() -> void:
	get_ok_button().disabled = _name_edit.text.strip_edges().is_empty()

func get_uuid() -> String:
	return _uuid

func get_new_name() -> String:
	return _name_edit.text

func get_new_subtitle() -> String:
	return _subtitle_edit.text

func _on_confirmed() -> void:
	rename_confirmed.emit(_uuid, _name_edit.text, _subtitle_edit.text)