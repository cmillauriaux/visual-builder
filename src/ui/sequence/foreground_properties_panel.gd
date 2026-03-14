extends VBoxContainer

## Panneau de propriétés pour le foreground sélectionné.
## Remplace le transition_panel.gd avec toutes les propriétés visibles.

var _foreground = null

var _title_label: Label
var _pos_x_spin: SpinBox
var _pos_y_spin: SpinBox
var _scale_spin: SpinBox
var _z_order_spin: SpinBox
var _flip_h_check: CheckButton
var _flip_v_check: CheckButton
var _opacity_slider: HSlider
var _opacity_label: Label
var _type_option: OptionButton
var _duration_spin: SpinBox

var _updating: bool = false

const TYPE_OPTIONS = ["none", "fade"]
const TYPE_LABELS = ["Aucune", "Fondu"]

signal properties_changed()

func _ready() -> void:
	visible = false
	add_theme_constant_override("separation", 4)

	_title_label = Label.new()
	_title_label.text = "Propriétés"
	_title_label.add_theme_font_size_override("font_size", 12)
	_title_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	add_child(_title_label)

	# Position
	var pos_row = HBoxContainer.new()
	add_child(pos_row)
	var pos_label = Label.new()
	pos_label.text = "Position"
	pos_label.custom_minimum_size = Vector2(70, 0)
	pos_row.add_child(pos_label)

	_pos_x_spin = SpinBox.new()
	_pos_x_spin.min_value = 0.0
	_pos_x_spin.max_value = 1.0
	_pos_x_spin.step = 0.01
	_pos_x_spin.prefix = "X:"
	_pos_x_spin.size_flags_horizontal = SIZE_EXPAND_FILL
	_pos_x_spin.value_changed.connect(_on_property_changed)
	pos_row.add_child(_pos_x_spin)

	_pos_y_spin = SpinBox.new()
	_pos_y_spin.min_value = 0.0
	_pos_y_spin.max_value = 1.0
	_pos_y_spin.step = 0.01
	_pos_y_spin.prefix = "Y:"
	_pos_y_spin.size_flags_horizontal = SIZE_EXPAND_FILL
	_pos_y_spin.value_changed.connect(_on_property_changed)
	pos_row.add_child(_pos_y_spin)

	# Scale
	var scale_row = HBoxContainer.new()
	add_child(scale_row)
	var scale_label = Label.new()
	scale_label.text = "Scale"
	scale_label.custom_minimum_size = Vector2(70, 0)
	scale_row.add_child(scale_label)

	_scale_spin = SpinBox.new()
	_scale_spin.min_value = 0.1
	_scale_spin.max_value = 10.0
	_scale_spin.step = 0.05
	_scale_spin.size_flags_horizontal = SIZE_EXPAND_FILL
	_scale_spin.value_changed.connect(_on_property_changed)
	scale_row.add_child(_scale_spin)

	# Z-order
	var z_row = HBoxContainer.new()
	add_child(z_row)
	var z_label = Label.new()
	z_label.text = "Z-order"
	z_label.custom_minimum_size = Vector2(70, 0)
	z_row.add_child(z_label)

	_z_order_spin = SpinBox.new()
	_z_order_spin.min_value = -100
	_z_order_spin.max_value = 100
	_z_order_spin.step = 1
	_z_order_spin.size_flags_horizontal = SIZE_EXPAND_FILL
	_z_order_spin.value_changed.connect(_on_property_changed)
	z_row.add_child(_z_order_spin)

	# Flip
	var flip_row = HBoxContainer.new()
	add_child(flip_row)
	var flip_label = Label.new()
	flip_label.text = "Flip"
	flip_label.custom_minimum_size = Vector2(70, 0)
	flip_row.add_child(flip_label)

	_flip_h_check = CheckButton.new()
	_flip_h_check.text = "H"
	_flip_h_check.toggled.connect(_on_property_changed)
	flip_row.add_child(_flip_h_check)

	_flip_v_check = CheckButton.new()
	_flip_v_check.text = "V"
	_flip_v_check.toggled.connect(_on_property_changed)
	flip_row.add_child(_flip_v_check)

	# Opacity
	var opacity_row = HBoxContainer.new()
	add_child(opacity_row)
	var opacity_label = Label.new()
	opacity_label.text = "Opacité"
	opacity_label.custom_minimum_size = Vector2(70, 0)
	opacity_row.add_child(opacity_label)

	_opacity_slider = HSlider.new()
	_opacity_slider.min_value = 0.0
	_opacity_slider.max_value = 1.0
	_opacity_slider.step = 0.05
	_opacity_slider.size_flags_horizontal = SIZE_EXPAND_FILL
	_opacity_slider.value_changed.connect(_on_property_changed)
	opacity_row.add_child(_opacity_slider)

	_opacity_label = Label.new()
	_opacity_label.text = "1.0"
	_opacity_label.custom_minimum_size = Vector2(30, 0)
	opacity_row.add_child(_opacity_label)

	# Transition
	add_child(HSeparator.new())

	var trans_row = HBoxContainer.new()
	add_child(trans_row)
	var trans_label = Label.new()
	trans_label.text = "Transition"
	trans_label.custom_minimum_size = Vector2(70, 0)
	trans_row.add_child(trans_label)

	_type_option = OptionButton.new()
	for i in range(TYPE_LABELS.size()):
		_type_option.add_item(TYPE_LABELS[i], i)
	_type_option.item_selected.connect(_on_property_changed)
	trans_row.add_child(_type_option)

	_duration_spin = SpinBox.new()
	_duration_spin.min_value = 0.1
	_duration_spin.max_value = 5.0
	_duration_spin.step = 0.1
	_duration_spin.value = 0.5
	_duration_spin.suffix = "s"
	_duration_spin.value_changed.connect(_on_property_changed)
	trans_row.add_child(_duration_spin)


func show_for_foreground(fg) -> void:
	_foreground = fg
	_updating = true
	_title_label.text = "Propriétés — %s" % fg.fg_name
	_pos_x_spin.value = fg.anchor_bg.x
	_pos_y_spin.value = fg.anchor_bg.y
	_scale_spin.value = fg.scale
	_z_order_spin.value = fg.z_order
	_flip_h_check.button_pressed = fg.flip_h
	_flip_v_check.button_pressed = fg.flip_v
	_opacity_slider.value = fg.opacity
	_opacity_label.text = "%.2f" % fg.opacity
	var type_idx = TYPE_OPTIONS.find(fg.transition_type)
	_type_option.selected = type_idx if type_idx >= 0 else 0
	_duration_spin.value = fg.transition_duration
	_updating = false
	visible = true


func hide_panel() -> void:
	_foreground = null
	visible = false


func _on_property_changed(_value = null) -> void:
	if _updating or _foreground == null:
		return
	_foreground.anchor_bg = Vector2(_pos_x_spin.value, _pos_y_spin.value)
	_foreground.scale = _scale_spin.value
	_foreground.z_order = int(_z_order_spin.value)
	_foreground.flip_h = _flip_h_check.button_pressed
	_foreground.flip_v = _flip_v_check.button_pressed
	_foreground.opacity = _opacity_slider.value
	_opacity_label.text = "%.2f" % _opacity_slider.value
	var type_idx = _type_option.selected
	if type_idx >= 0 and type_idx < TYPE_OPTIONS.size():
		_foreground.transition_type = TYPE_OPTIONS[type_idx]
	_foreground.transition_duration = _duration_spin.value
	properties_changed.emit()
