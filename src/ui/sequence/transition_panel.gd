extends VBoxContainer

## Mini-panel de propriétés de transition pour un foreground sélectionné.

var _foreground = null
var _type_option: OptionButton = null
var _duration_spin: SpinBox = null

const TYPE_OPTIONS = ["none", "fade"]
const TYPE_LABELS = ["Aucune", "Fondu"]

signal transition_changed()

func _ready() -> void:
	visible = false

	var title = Label.new()
	title.text = "Transition"
	add_child(title)

	var type_hbox = HBoxContainer.new()
	add_child(type_hbox)
	var type_label = Label.new()
	type_label.text = "Type :"
	type_hbox.add_child(type_label)
	_type_option = OptionButton.new()
	for i in range(TYPE_LABELS.size()):
		_type_option.add_item(TYPE_LABELS[i], i)
	_type_option.item_selected.connect(_on_type_selected)
	type_hbox.add_child(_type_option)

	var dur_hbox = HBoxContainer.new()
	add_child(dur_hbox)
	var dur_label = Label.new()
	dur_label.text = "Durée :"
	dur_hbox.add_child(dur_label)
	_duration_spin = SpinBox.new()
	_duration_spin.min_value = 0.1
	_duration_spin.max_value = 5.0
	_duration_spin.step = 0.1
	_duration_spin.value = 0.5
	_duration_spin.suffix = "s"
	_duration_spin.value_changed.connect(_on_duration_changed)
	dur_hbox.add_child(_duration_spin)

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

func _on_type_selected(idx: int) -> void:
	if _foreground and idx >= 0 and idx < TYPE_OPTIONS.size():
		_foreground.transition_type = TYPE_OPTIONS[idx]
		transition_changed.emit()

func _on_duration_changed(value: float) -> void:
	if _foreground:
		_foreground.transition_duration = value
		transition_changed.emit()
