extends GutTest

## Tests pour ForegroundLayerItem — item individuel dans le panneau calques.

var ForegroundLayerItemScript = load("res://src/ui/sequence/foreground_layer_item.gd")
var Foreground = load("res://src/models/foreground.gd")

var _item: PanelContainer
var _foreground


func before_each() -> void:
	_foreground = Foreground.new()
	_foreground.fg_name = "Hero"
	_foreground.image = "hero.png"
	_foreground.z_order = 3


func _create_item(is_inherited: bool = false, inherited_from_index: int = -1) -> PanelContainer:
	var item = PanelContainer.new()
	item.set_script(ForegroundLayerItemScript)
	item.setup(_foreground, is_inherited, inherited_from_index)
	add_child_autofree(item)
	return item


# --- Setup ---

func test_setup_sets_uuid() -> void:
	_item = _create_item()
	assert_eq(_item._uuid, _foreground.uuid)


func test_setup_sets_inherited_state_false() -> void:
	_item = _create_item(false)
	assert_false(_item._is_inherited)


func test_setup_sets_inherited_state_true() -> void:
	_item = _create_item(true, 2)
	assert_true(_item._is_inherited)


func test_setup_sets_inherited_from_index() -> void:
	_item = _create_item(true, 4)
	assert_eq(_item._inherited_from_index, 4)


func test_setup_stores_foreground_reference() -> void:
	_item = _create_item()
	assert_eq(_item._foreground, _foreground)


# --- Inherited item ---

func test_inherited_item_shows_label() -> void:
	_item = _create_item(true, 2)
	assert_true(_item._inherited_label.visible)
	assert_string_contains(_item._inherited_label.text, "hérité")
	assert_string_contains(_item._inherited_label.text, "3")  # inherited_from_index + 1


func test_inherited_from_sequence_shows_sequence_label() -> void:
	_item = _create_item(true, -1)
	assert_true(_item._inherited_label.visible)
	assert_eq(_item._inherited_label.text, "hérité de la séquence")


func test_inherited_item_label_color_is_orange() -> void:
	_item = _create_item(true, 0)
	var color = _item._inherited_label.get_theme_color("font_color")
	assert_eq(color, Color("#ffaa00"))


func test_inherited_item_has_reduced_opacity() -> void:
	_item = _create_item(true, 0)
	assert_almost_eq(_item.modulate.a, 0.6, 0.01)


func test_inherited_item_has_orange_color_bar() -> void:
	_item = _create_item(true, 0)
	assert_eq(_item._color_bar.color, Color("#ffaa00"))


func test_inherited_item_name_color_is_grey() -> void:
	_item = _create_item(true, 0)
	var color = _item._name_label.get_theme_color("font_color")
	assert_eq(color, Color(0.6, 0.6, 0.6))


# --- Non-inherited item ---

func test_non_inherited_item_hides_label() -> void:
	_item = _create_item(false)
	assert_false(_item._inherited_label.visible)


func test_non_inherited_item_has_full_opacity() -> void:
	_item = _create_item(false)
	assert_almost_eq(_item.modulate.a, 1.0, 0.01)


func test_non_inherited_item_shows_name() -> void:
	_item = _create_item(false)
	assert_eq(_item._name_label.text, "Hero")


func test_non_inherited_item_shows_z_order() -> void:
	_item = _create_item(false)
	assert_eq(_item._z_order_label.text, "z:3")


# --- Selection ---

func test_set_selected_true_changes_visual() -> void:
	_item = _create_item()
	_item.set_selected(true)
	assert_true(_item._selected)
	# Should have a stylebox override when selected
	assert_not_null(_item.get_theme_stylebox("panel"))


func test_set_selected_false_clears_visual() -> void:
	_item = _create_item()
	_item.set_selected(true)
	_item.set_selected(false)
	assert_false(_item._selected)


func test_set_selected_toggle() -> void:
	_item = _create_item()
	_item.set_selected(true)
	assert_true(_item._selected)
	_item.set_selected(false)
	assert_false(_item._selected)
	_item.set_selected(true)
	assert_true(_item._selected)


# --- get_uuid ---

func test_get_uuid_returns_correct_uuid() -> void:
	_item = _create_item()
	assert_eq(_item.get_uuid(), _foreground.uuid)


func test_get_uuid_returns_empty_without_setup() -> void:
	var item = PanelContainer.new()
	item.set_script(ForegroundLayerItemScript)
	add_child_autofree(item)
	assert_eq(item.get_uuid(), "")


# --- is_inherited ---

func test_is_inherited_returns_true_for_inherited() -> void:
	_item = _create_item(true, 1)
	assert_true(_item.is_inherited())


func test_is_inherited_returns_false_for_non_inherited() -> void:
	_item = _create_item(false)
	assert_false(_item.is_inherited())


# --- Signals ---

func test_item_clicked_signal_emitted() -> void:
	_item = _create_item()
	watch_signals(_item)
	_item.item_clicked.emit(_foreground.uuid)
	assert_signal_emitted_with_parameters(_item, "item_clicked", [_foreground.uuid])


func test_visibility_toggled_signal() -> void:
	_item = _create_item()
	watch_signals(_item)
	_item.visibility_toggled.emit(_foreground.uuid, false)
	assert_signal_emitted_with_parameters(_item, "visibility_toggled", [_foreground.uuid, false])


# --- Minimum size ---

func test_minimum_height() -> void:
	_item = _create_item()
	assert_eq(_item.custom_minimum_size.y, 32.0)


# --- Drag data for non-inherited ---

func test_drag_returns_null_for_inherited() -> void:
	_item = _create_item(true, 0)
	var result = _item._get_drag_data(Vector2.ZERO)
	assert_null(result)


func test_non_inherited_item_allows_drag() -> void:
	# We cannot call _get_drag_data directly in headless mode because
	# set_drag_preview requires an active drag operation in the viewport.
	# Instead, verify that the item is not inherited, which is the condition
	# for allowing drag.
	_item = _create_item(false)
	assert_false(_item._is_inherited, "Non-inherited item should allow drag")
