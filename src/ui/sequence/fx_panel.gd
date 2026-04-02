# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends VBoxContainer

## Panel UI pour configurer les FX d'une séquence dans l'éditeur.

const SequenceFxScript = preload("res://src/models/sequence_fx.gd")

signal fx_changed

var _sequence = null
var _fx_list_container: VBoxContainer
var _add_button: MenuButton


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var header = HBoxContainer.new()
	add_child(header)

	var title = Label.new()
	title.text = tr("Effets visuels (FX)")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	_add_button = MenuButton.new()
	_add_button.text = tr("+ Ajouter FX")
	header.add_child(_add_button)

	var popup = _add_button.get_popup()
	popup.add_item(tr("Fondu (fade in)"), 0)
	popup.add_item(tr("Tremblement (screen shake)"), 1)
	popup.add_item(tr("Clignement (eyes blink)"), 2)
	popup.add_item(tr("Flash"), 3)
	popup.add_item(tr("Zoom (pulsé)"), 4)
	popup.add_item(tr("Vignette"), 5)
	popup.add_item(tr("Désaturation"), 6)
	popup.add_separator()
	popup.add_item(tr("Zoom avant"), 7)
	popup.add_item(tr("Zoom arrière"), 8)
	popup.add_separator()
	popup.add_item(tr("Caméra → Droite"), 9)
	popup.add_item(tr("Caméra → Gauche"), 10)
	popup.add_item(tr("Caméra → Bas"), 11)
	popup.add_item(tr("Caméra → Haut"), 12)
	popup.id_pressed.connect(_on_add_fx_type_selected)

	_fx_list_container = VBoxContainer.new()
	_fx_list_container.name = "FxListContainer"
	add_child(_fx_list_container)


func load_sequence(seq) -> void:
	_sequence = seq
	_rebuild_list()


func clear() -> void:
	_sequence = null
	_clear_list()


func _rebuild_list() -> void:
	_clear_list()
	if _sequence == null:
		return
	for i in range(_sequence.fx.size()):
		var row = _build_fx_row(_sequence.fx[i], i)
		_fx_list_container.add_child(row)


func _clear_list() -> void:
	for child in _fx_list_container.get_children():
		child.queue_free()


func _build_fx_row(fx, index: int) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.name = "FxRow_%d" % index

	# Type selector
	var type_btn = OptionButton.new()
	type_btn.name = "TypeOption"
	for t in SequenceFxScript.VALID_FX_TYPES:
		type_btn.add_item(_get_fx_label(t))
	type_btn.selected = SequenceFxScript.VALID_FX_TYPES.find(fx.fx_type)
	type_btn.item_selected.connect(func(idx): _on_type_changed(index, idx))
	row.add_child(type_btn)

	# Duration
	var dur_label = Label.new()
	dur_label.text = tr("Durée:")
	row.add_child(dur_label)

	var dur_spin = SpinBox.new()
	dur_spin.name = "DurationSpin"
	dur_spin.min_value = 0.1
	dur_spin.max_value = 5.0
	dur_spin.step = 0.1
	dur_spin.value = fx.duration
	dur_spin.value_changed.connect(func(val): _on_duration_changed(index, val))
	row.add_child(dur_spin)

	var zoom_types := ["zoom_in", "zoom_out"]
	var pan_types := ["pan_right", "pan_left", "pan_down", "pan_up"]

	if fx.fx_type in zoom_types:
		# zoom_in / zoom_out : zoom_from → zoom_to, no intensity
		var zf_label = Label.new()
		zf_label.text = tr("De x:")
		row.add_child(zf_label)

		var zf_spin = SpinBox.new()
		zf_spin.name = "ZoomFromSpin"
		zf_spin.min_value = 1.0
		zf_spin.max_value = 5.0
		zf_spin.step = 0.1
		zf_spin.value = fx.zoom_from
		zf_spin.value_changed.connect(func(val): _on_zoom_from_changed(index, val))
		row.add_child(zf_spin)

		var zt_label = Label.new()
		zt_label.text = tr("À x:")
		row.add_child(zt_label)

		var zt_spin = SpinBox.new()
		zt_spin.name = "ZoomToSpin"
		zt_spin.min_value = 1.0
		zt_spin.max_value = 5.0
		zt_spin.step = 0.1
		zt_spin.value = fx.zoom_to
		zt_spin.value_changed.connect(func(val): _on_zoom_to_changed(index, val))
		row.add_child(zt_spin)

	elif fx.fx_type in pan_types:
		# pan_* : zoom level + scroll fraction
		var zf_label = Label.new()
		zf_label.text = tr("Zoom:")
		row.add_child(zf_label)

		var zf_spin = SpinBox.new()
		zf_spin.name = "ZoomFromSpin"
		zf_spin.min_value = 1.0
		zf_spin.max_value = 5.0
		zf_spin.step = 0.1
		zf_spin.value = fx.zoom_from
		zf_spin.value_changed.connect(func(val): _on_zoom_from_changed(index, val))
		row.add_child(zf_spin)

		var scroll_label = Label.new()
		scroll_label.text = tr("Défilement:")
		row.add_child(scroll_label)

		var scroll_spin = SpinBox.new()
		scroll_spin.name = "IntensitySpin"
		scroll_spin.min_value = 0.0
		scroll_spin.max_value = 1.0
		scroll_spin.step = 0.05
		scroll_spin.value = minf(fx.intensity, 1.0)
		scroll_spin.value_changed.connect(func(val): _on_intensity_changed(index, val))
		row.add_child(scroll_spin)

	else:
		# Intensité standard pour les autres types qui l'utilisent
		var uses_intensity: bool = fx.fx_type in ["screen_shake", "flash", "zoom", "vignette", "desaturation"]
		if uses_intensity:
			var int_label = Label.new()
			int_label.text = tr("Intensité:")
			row.add_child(int_label)

			var int_spin = SpinBox.new()
			int_spin.name = "IntensitySpin"
			int_spin.min_value = 0.1
			int_spin.max_value = 3.0
			int_spin.step = 0.1
			int_spin.value = fx.intensity
			int_spin.value_changed.connect(func(val): _on_intensity_changed(index, val))
			row.add_child(int_spin)

	# Color picker (only for flash)
	if fx.fx_type == "flash":
		var color_label = Label.new()
		color_label.text = tr("Couleur:")
		row.add_child(color_label)

		var color_btn = ColorPickerButton.new()
		color_btn.name = "ColorPicker"
		color_btn.color = fx.color
		color_btn.custom_minimum_size = Vector2(40, 0)
		color_btn.color_changed.connect(func(c): _on_color_changed(index, c))
		row.add_child(color_btn)

	# Continue during FX checkbox
	var continue_chk = CheckBox.new()
	continue_chk.name = "ContinueCheckBox"
	continue_chk.text = tr("En parallèle")
	continue_chk.tooltip_text = tr("Continuer la scène pendant le FX : l'UI reste visible, les dialogues et voix se jouent simultanément.")
	continue_chk.button_pressed = fx.continue_during_fx
	continue_chk.toggled.connect(func(val): _on_continue_changed(index, val))
	row.add_child(continue_chk)

	# Delete button
	var del_btn = Button.new()
	del_btn.name = "DeleteButton"
	del_btn.text = "✕"
	del_btn.pressed.connect(func(): _on_delete(index))
	row.add_child(del_btn)

	return row


func _get_fx_label(fx_type: String) -> String:
	match fx_type:
		"screen_shake":
			return tr("Tremblement")
		"fade_in":
			return tr("Fondu")
		"eyes_blink":
			return tr("Clignement")
		"flash":
			return tr("Flash")
		"zoom":
			return tr("Zoom pulsé")
		"vignette":
			return tr("Vignette")
		"desaturation":
			return tr("Désaturation")
		"zoom_in":
			return tr("Zoom avant")
		"zoom_out":
			return tr("Zoom arrière")
		"pan_right":
			return tr("Caméra → Droite")
		"pan_left":
			return tr("Caméra → Gauche")
		"pan_down":
			return tr("Caméra → Bas")
		"pan_up":
			return tr("Caméra → Haut")
		_:
			return fx_type


func _on_add_fx_type_selected(id: int) -> void:
	if _sequence == null:
		return
	var fx = SequenceFxScript.new()
	match id:
		0:
			fx.fx_type = "fade_in"
		1:
			fx.fx_type = "screen_shake"
		2:
			fx.fx_type = "eyes_blink"
		3:
			fx.fx_type = "flash"
		4:
			fx.fx_type = "zoom"
		5:
			fx.fx_type = "vignette"
		6:
			fx.fx_type = "desaturation"
		7:
			fx.fx_type = "zoom_in"
			fx.zoom_from = 1.0
			fx.zoom_to = 1.5
		8:
			fx.fx_type = "zoom_out"
			fx.zoom_from = 1.5
			fx.zoom_to = 1.0
		9:
			fx.fx_type = "pan_right"
			fx.zoom_from = 1.3
			fx.intensity = 0.5
		10:
			fx.fx_type = "pan_left"
			fx.zoom_from = 1.3
			fx.intensity = 0.5
		11:
			fx.fx_type = "pan_down"
			fx.zoom_from = 1.3
			fx.intensity = 0.5
		12:
			fx.fx_type = "pan_up"
			fx.zoom_from = 1.3
			fx.intensity = 0.5
	_sequence.fx.append(fx)
	_rebuild_list()
	fx_changed.emit()


func _on_type_changed(index: int, type_idx: int) -> void:
	if _sequence == null or index >= _sequence.fx.size():
		return
	_sequence.fx[index].fx_type = SequenceFxScript.VALID_FX_TYPES[type_idx]
	_rebuild_list()
	fx_changed.emit()


func _on_duration_changed(index: int, value: float) -> void:
	if _sequence == null or index >= _sequence.fx.size():
		return
	_sequence.fx[index].duration = value
	fx_changed.emit()


func _on_intensity_changed(index: int, value: float) -> void:
	if _sequence == null or index >= _sequence.fx.size():
		return
	_sequence.fx[index].intensity = value
	fx_changed.emit()


func _on_color_changed(index: int, new_color: Color) -> void:
	if _sequence == null or index >= _sequence.fx.size():
		return
	_sequence.fx[index].color = new_color
	fx_changed.emit()


func _on_continue_changed(index: int, value: bool) -> void:
	if _sequence == null or index >= _sequence.fx.size():
		return
	_sequence.fx[index].continue_during_fx = value
	fx_changed.emit()


func _on_zoom_from_changed(index: int, value: float) -> void:
	if _sequence == null or index >= _sequence.fx.size():
		return
	_sequence.fx[index].zoom_from = value
	fx_changed.emit()


func _on_zoom_to_changed(index: int, value: float) -> void:
	if _sequence == null or index >= _sequence.fx.size():
		return
	_sequence.fx[index].zoom_to = value
	fx_changed.emit()


func _on_delete(index: int) -> void:
	if _sequence == null or index >= _sequence.fx.size():
		return
	_sequence.fx.remove_at(index)
	_rebuild_list()
	fx_changed.emit()