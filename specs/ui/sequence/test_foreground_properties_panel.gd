extends GutTest

## Tests pour ForegroundPropertiesPanel — panneau de propriétés du foreground sélectionné.

var ForegroundPropertiesPanelScript = load("res://src/ui/sequence/foreground_properties_panel.gd")
var Foreground = load("res://src/models/foreground.gd")

var _panel: VBoxContainer
var _foreground


func before_each() -> void:
	_foreground = Foreground.new()
	_foreground.fg_name = "Hero"
	_foreground.image = "hero.png"
	_foreground.anchor_bg = Vector2(0.3, 0.7)
	_foreground.scale = 1.5
	_foreground.z_order = 2
	_foreground.flip_h = true
	_foreground.flip_v = false
	_foreground.opacity = 0.8
	_foreground.transition_type = "fade"
	_foreground.transition_duration = 1.0

	_panel = VBoxContainer.new()
	_panel.set_script(ForegroundPropertiesPanelScript)
	add_child_autofree(_panel)


# --- Initially hidden ---

func test_initially_hidden() -> void:
	assert_false(_panel.visible)


# --- show_for_foreground ---

func test_show_for_foreground_makes_visible() -> void:
	_panel.show_for_foreground(_foreground)
	assert_true(_panel.visible)


func test_show_for_foreground_populates_title() -> void:
	_panel.show_for_foreground(_foreground)
	assert_string_contains(_panel._title_label.text, "Propri")
	assert_eq(_panel._name_label.text, "Hero")


func test_show_for_foreground_populates_position() -> void:
	_panel.show_for_foreground(_foreground)
	assert_almost_eq(_panel._pos_x_spin.value, 0.3, 0.01)
	assert_almost_eq(_panel._pos_y_spin.value, 0.7, 0.01)


func test_show_for_foreground_populates_scale() -> void:
	_panel.show_for_foreground(_foreground)
	assert_almost_eq(_panel._scale_spin.value, 1.5, 0.01)


func test_show_for_foreground_populates_z_order() -> void:
	_panel.show_for_foreground(_foreground)
	assert_eq(int(_panel._z_order_spin.value), 2)


func test_show_for_foreground_populates_flip() -> void:
	_panel.show_for_foreground(_foreground)
	assert_true(_panel._flip_h_check.button_pressed)
	assert_false(_panel._flip_v_check.button_pressed)


func test_show_for_foreground_populates_opacity() -> void:
	_panel.show_for_foreground(_foreground)
	assert_almost_eq(_panel._opacity_slider.value, 0.8, 0.01)
	assert_eq(_panel._opacity_label.text, "0.80")


func test_show_for_foreground_populates_transition_type() -> void:
	_panel.show_for_foreground(_foreground)
	assert_eq(_panel._type_option.selected, 1)  # "fade" is index 1


func test_show_for_foreground_populates_transition_duration() -> void:
	_panel.show_for_foreground(_foreground)
	assert_almost_eq(_panel._duration_spin.value, 1.0, 0.01)


func test_show_for_foreground_with_none_transition() -> void:
	_foreground.transition_type = "none"
	_panel.show_for_foreground(_foreground)
	assert_eq(_panel._type_option.selected, 0)  # "none" is index 0


func test_show_for_foreground_stores_reference() -> void:
	_panel.show_for_foreground(_foreground)
	assert_eq(_panel._foreground, _foreground)


# --- hide_panel ---

func test_hide_panel_hides() -> void:
	_panel.show_for_foreground(_foreground)
	_panel.hide_panel()
	assert_false(_panel.visible)


func test_hide_panel_clears_foreground_reference() -> void:
	_panel.show_for_foreground(_foreground)
	_panel.hide_panel()
	assert_null(_panel._foreground)


# --- properties_changed signal ---

func test_properties_changed_signal_emitted_on_position_change() -> void:
	_panel.show_for_foreground(_foreground)
	watch_signals(_panel)
	_panel._on_property_changed(0.5)
	assert_signal_emitted(_panel, "properties_changed")


func test_properties_changed_not_emitted_during_update() -> void:
	watch_signals(_panel)
	# During show_for_foreground, _updating is true so signal should NOT fire
	_panel.show_for_foreground(_foreground)
	assert_signal_not_emitted(_panel, "properties_changed")


func test_properties_changed_not_emitted_without_foreground() -> void:
	watch_signals(_panel)
	_panel._on_property_changed(0.5)
	assert_signal_not_emitted(_panel, "properties_changed")


func test_property_change_updates_foreground_position() -> void:
	_panel.show_for_foreground(_foreground)
	_panel._pos_x_spin.value = 0.6
	_panel._pos_y_spin.value = 0.4
	_panel._on_property_changed()
	assert_almost_eq(_foreground.anchor_bg.x, 0.6, 0.01)
	assert_almost_eq(_foreground.anchor_bg.y, 0.4, 0.01)


func test_property_change_updates_foreground_scale() -> void:
	_panel.show_for_foreground(_foreground)
	_panel._scale_spin.value = 2.5
	_panel._on_property_changed()
	assert_almost_eq(_foreground.scale, 2.5, 0.01)


func test_property_change_updates_foreground_z_order() -> void:
	_panel.show_for_foreground(_foreground)
	_panel._z_order_spin.value = 10
	_panel._on_property_changed()
	assert_eq(_foreground.z_order, 10)


func test_property_change_updates_foreground_flip() -> void:
	_panel.show_for_foreground(_foreground)
	_panel._flip_h_check.button_pressed = false
	_panel._flip_v_check.button_pressed = true
	_panel._on_property_changed()
	assert_false(_foreground.flip_h)
	assert_true(_foreground.flip_v)


func test_property_change_updates_foreground_opacity() -> void:
	_panel.show_for_foreground(_foreground)
	_panel._opacity_slider.value = 0.5
	_panel._on_property_changed()
	assert_almost_eq(_foreground.opacity, 0.5, 0.01)


func test_property_change_updates_opacity_label() -> void:
	_panel.show_for_foreground(_foreground)
	_panel._opacity_slider.value = 0.35
	_panel._on_property_changed()
	assert_eq(_panel._opacity_label.text, "0.35")


func test_property_change_updates_transition_type() -> void:
	_panel.show_for_foreground(_foreground)
	_panel._type_option.selected = 0  # "none"
	_panel._on_property_changed()
	assert_eq(_foreground.transition_type, "none")


func test_property_change_updates_transition_duration() -> void:
	_panel.show_for_foreground(_foreground)
	_panel._duration_spin.value = 2.5
	_panel._on_property_changed()
	assert_almost_eq(_foreground.transition_duration, 2.5, 0.01)


# --- UI elements created ---

func test_spin_boxes_exist() -> void:
	assert_not_null(_panel._pos_x_spin)
	assert_not_null(_panel._pos_y_spin)
	assert_not_null(_panel._scale_spin)
	assert_not_null(_panel._z_order_spin)
	assert_not_null(_panel._duration_spin)


func test_check_buttons_exist() -> void:
	assert_not_null(_panel._flip_h_check)
	assert_not_null(_panel._flip_v_check)


func test_opacity_slider_exists() -> void:
	assert_not_null(_panel._opacity_slider)
	assert_not_null(_panel._opacity_label)


func test_type_option_exists() -> void:
	assert_not_null(_panel._type_option)
	assert_eq(_panel._type_option.get_item_count(), 2)
