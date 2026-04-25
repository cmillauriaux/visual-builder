# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends Window

class_name ProgressDialog

## Dialog générique affichant une barre de progression.

signal cancelled

var _label: Label
var _progress_bar: ProgressBar
var _cancel_button: Button

func _ready() -> void:
	size = Vector2i(400, 150)
	exclusive = true
	unresizable = true
	close_requested.connect(_on_cancel_pressed)
	
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	margin.add_child(vbox)
	
	_label = Label.new()
	_label.text = tr("Progression...")
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_label)
	
	_progress_bar = ProgressBar.new()
	_progress_bar.min_value = 0
	_progress_bar.max_value = 100
	_progress_bar.value = 0
	vbox.add_child(_progress_bar)
	
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)
	
	_cancel_button = Button.new()
	_cancel_button.text = tr("Annuler")
	_cancel_button.pressed.connect(_on_cancel_pressed)
	hbox.add_child(_cancel_button)

func set_title_text(t: String) -> void:
	title = t

func set_status_text(t: String) -> void:
	_label.text = t

func set_progress(val: float) -> void:
	_progress_bar.value = val

func set_max_progress(val: float) -> void:
	_progress_bar.max_value = val

func _on_cancel_pressed() -> void:
	cancelled.emit()
	hide()
	queue_free()
