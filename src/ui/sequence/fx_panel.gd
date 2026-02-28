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
	title.text = "Effets visuels (FX)"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	_add_button = MenuButton.new()
	_add_button.text = "+ Ajouter FX"
	header.add_child(_add_button)

	var popup = _add_button.get_popup()
	popup.add_item("Fondu (fade in)", 0)
	popup.add_item("Tremblement (screen shake)", 1)
	popup.add_item("Clignement (eyes blink)", 2)
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
	dur_label.text = "Durée:"
	row.add_child(dur_label)

	var dur_spin = SpinBox.new()
	dur_spin.name = "DurationSpin"
	dur_spin.min_value = 0.1
	dur_spin.max_value = 5.0
	dur_spin.step = 0.1
	dur_spin.value = fx.duration
	dur_spin.value_changed.connect(func(val): _on_duration_changed(index, val))
	row.add_child(dur_spin)

	# Intensity
	var int_label = Label.new()
	int_label.text = "Intensité:"
	row.add_child(int_label)

	var int_spin = SpinBox.new()
	int_spin.name = "IntensitySpin"
	int_spin.min_value = 0.1
	int_spin.max_value = 3.0
	int_spin.step = 0.1
	int_spin.value = fx.intensity
	int_spin.value_changed.connect(func(val): _on_intensity_changed(index, val))
	row.add_child(int_spin)

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
			return "Tremblement"
		"fade_in":
			return "Fondu"
		"eyes_blink":
			return "Clignement"
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
	_sequence.fx.append(fx)
	_rebuild_list()
	fx_changed.emit()


func _on_type_changed(index: int, type_idx: int) -> void:
	if _sequence == null or index >= _sequence.fx.size():
		return
	_sequence.fx[index].fx_type = SequenceFxScript.VALID_FX_TYPES[type_idx]
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


func _on_delete(index: int) -> void:
	if _sequence == null or index >= _sequence.fx.size():
		return
	_sequence.fx.remove_at(index)
	_rebuild_list()
	fx_changed.emit()
