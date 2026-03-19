extends VBoxContainer

## Mini-panel de propriétés de transition pour un foreground sélectionné.

var _foreground = null
var _type_option: OptionButton = null
var _duration_spin: SpinBox = null
var _z_order_spin: SpinBox = null
var _flip_option: OptionButton = null

const TYPE_OPTIONS = ["none", "fade"]
const TYPE_LABELS = ["Aucune", "Fondu"]
const FLIP_LABELS = ["Aucun", "Horizontal", "Vertical", "Les deux"]

signal transition_changed()

func _ready() -> void:
	visible = false

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)

	# Type (fondu)
	var type_label = Label.new()
	type_label.text = tr("Fondu :")
	row.add_child(type_label)
	_type_option = OptionButton.new()
	for i in range(TYPE_LABELS.size()):
		_type_option.add_item(tr(TYPE_LABELS[i]), i)
	_type_option.item_selected.connect(_on_type_selected)
	row.add_child(_type_option)

	# Duration (temps de fondu)
	var dur_label = Label.new()
	dur_label.text = tr("Durée :")
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
	z_label.text = tr("Z-Index :")
	row.add_child(z_label)
	_z_order_spin = SpinBox.new()
	_z_order_spin.min_value = -100
	_z_order_spin.max_value = 100
	_z_order_spin.step = 1
	_z_order_spin.value = 0
	_z_order_spin.value_changed.connect(_on_z_order_changed)
	row.add_child(_z_order_spin)

	# Flip
	var flip_label = Label.new()
	flip_label.text = tr("Flip :")
	row.add_child(flip_label)
	_flip_option = OptionButton.new()
	for i in range(FLIP_LABELS.size()):
		_flip_option.add_item(tr(FLIP_LABELS[i]), i)
	_flip_option.item_selected.connect(_on_flip_selected)
	row.add_child(_flip_option)

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
	# Set flip
	_flip_option.selected = _flip_index_from_fg(fg)

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

func get_displayed_flip() -> int:
	if _flip_option == null:
		return 0
	return _flip_option.selected

func set_flip(flip_index: int) -> void:
	flip_index = clampi(flip_index, 0, 3)
	_flip_option.selected = flip_index
	if _foreground:
		_foreground.flip_h = (flip_index == 1 or flip_index == 3)
		_foreground.flip_v = (flip_index == 2 or flip_index == 3)
		transition_changed.emit()

func _on_flip_selected(idx: int) -> void:
	if _foreground and idx >= 0 and idx < FLIP_LABELS.size():
		_foreground.flip_h = (idx == 1 or idx == 3)
		_foreground.flip_v = (idx == 2 or idx == 3)
		transition_changed.emit()

static func _flip_index_from_fg(fg) -> int:
	var idx = 0
	if fg.flip_h:
		idx += 1
	if fg.flip_v:
		idx += 2
	return idx
