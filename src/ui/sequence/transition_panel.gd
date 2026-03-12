extends VBoxContainer

## Mini-panel de propriétés de transition pour un foreground sélectionné.

var _foreground = null
var _type_option: OptionButton = null
var _duration_spin: SpinBox = null
var _z_order_spin: SpinBox = null

const TYPE_OPTIONS = ["none", "fade"]
const TYPE_LABELS = ["Aucune", "Fondu"]

signal transition_changed()

func _ready() -> void:
	visible = false

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)

	# Type (fondu)
	var type_label = Label.new()
	type_label.text = "Fondu :"
	row.add_child(type_label)
	_type_option = OptionButton.new()
	for i in range(TYPE_LABELS.size()):
		_type_option.add_item(TYPE_LABELS[i], i)
	_type_option.item_selected.connect(_on_type_selected)
	row.add_child(_type_option)

	# Duration (temps de fondu)
	var dur_label = Label.new()
	dur_label.text = "Durée :"
	row.add_child(dur_label)
	_duration_spin = SpinBox.new()
	_duration_spin.min_value = 0.1
	_duration_spin.max_value = 5.0
	_duration_spin.step = 0.1
	_duration_spin.value = 0.5
	_duration_spin.suffix = "s"
	_duration_spin.value_changed.connect(_on_duration_changed)
	row.add_child(_duration_spin)

	# Z-Index
	var z_label = Label.new()
	z_label.text = "Z-Index :"
	row.add_child(z_label)
	_z_order_spin = SpinBox.new()
	_z_order_spin.min_value = -100
	_z_order_spin.max_value = 100
	_z_order_spin.step = 1
	_z_order_spin.value = 0
	_z_order_spin.value_changed.connect(_on_z_order_changed)
	row.add_child(_z_order_spin)

func show_for_foreground(fg) -> void:
	_foreground = fg
	if fg == null:
		visible = false
		return
	visible = true
	# Set type
	var type_idx = TYPE_OPTIONS.find(fg.transition_type)
	if type_idx < 0:
		type_idx = 0
	_type_option.selected = type_idx
	# Set duration
	_duration_spin.value = fg.transition_duration
	# Set z-order
	_z_order_spin.value = fg.z_order

func hide_panel() -> void:
	visible = false
	_foreground = null

func get_selected_type() -> String:
	if _type_option == null:
		return "none"
	var idx = _type_option.selected
	if idx < 0 or idx >= TYPE_OPTIONS.size():
		return "none"
	return TYPE_OPTIONS[idx]

func get_displayed_duration() -> float:
	if _duration_spin == null:
		return 0.5
	return _duration_spin.value

func set_type(type: String) -> void:
	var idx = TYPE_OPTIONS.find(type)
	if idx >= 0:
		_type_option.selected = idx
		if _foreground:
			_foreground.transition_type = type
			transition_changed.emit()

func set_duration(duration: float) -> void:
	_duration_spin.value = clampf(duration, 0.1, 5.0)
	if _foreground:
		_foreground.transition_duration = _duration_spin.value
		transition_changed.emit()

func get_displayed_z_order() -> int:
	if _z_order_spin == null:
		return 0
	return int(_z_order_spin.value)

func set_z_order(z: int) -> void:
	_z_order_spin.value = clampi(z, -100, 100)
	if _foreground:
		_foreground.z_order = int(_z_order_spin.value)
		transition_changed.emit()

func _on_type_selected(idx: int) -> void:
	if _foreground and idx >= 0 and idx < TYPE_OPTIONS.size():
		_foreground.transition_type = TYPE_OPTIONS[idx]
		transition_changed.emit()

func _on_duration_changed(value: float) -> void:
	if _foreground:
		_foreground.transition_duration = value
		transition_changed.emit()

func _on_z_order_changed(value: float) -> void:
	if _foreground:
		_foreground.z_order = int(value)
		transition_changed.emit()
