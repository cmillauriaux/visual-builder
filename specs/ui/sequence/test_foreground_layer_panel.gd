extends GutTest

## Tests pour ForegroundLayerPanel — panneau des calques foreground.

var ForegroundLayerPanelScript = load("res://src/ui/sequence/foreground_layer_panel.gd")
var Foreground = load("res://src/models/foreground.gd")

var _panel: VBoxContainer


func before_each() -> void:
	_panel = VBoxContainer.new()
	_panel.set_script(ForegroundLayerPanelScript)
	add_child_autofree(_panel)


# --- update_layers ---

func test_update_layers_creates_correct_items() -> void:
	var fgs = _create_foregrounds(3)
	_panel.update_layers(fgs, false)
	assert_eq(_panel._items.size(), 3)


func test_update_layers_with_inherited_flag() -> void:
	var fgs = _create_foregrounds(2)
	_panel.update_layers(fgs, true, 0)
	assert_eq(_panel._items.size(), 2)
	for item in _panel._items:
		assert_true(item.is_inherited())


func test_update_layers_replaces_previous_items() -> void:
	var fgs1 = _create_foregrounds(3)
	_panel.update_layers(fgs1, false)
	assert_eq(_panel._items.size(), 3)
	var fgs2 = _create_foregrounds(5)
	_panel.update_layers(fgs2, false)
	assert_eq(_panel._items.size(), 5)


# --- select_foreground ---

func test_select_foreground_highlights_item() -> void:
	var fgs = _create_foregrounds(3)
	_panel.update_layers(fgs, false)
	var target_uuid = fgs[1].uuid
	_panel.select_foreground(target_uuid)
	assert_eq(_panel._selected_uuid, target_uuid)
	assert_true(_panel._items[1]._selected)
	assert_false(_panel._items[0]._selected)
	assert_false(_panel._items[2]._selected)


func test_select_foreground_stores_uuid() -> void:
	var fgs = _create_foregrounds(2)
	_panel.update_layers(fgs, false)
	_panel.select_foreground(fgs[0].uuid)
	assert_eq(_panel._selected_uuid, fgs[0].uuid)


# --- deselect_all ---

func test_deselect_all_clears_selection() -> void:
	var fgs = _create_foregrounds(3)
	_panel.update_layers(fgs, false)
	_panel.select_foreground(fgs[1].uuid)
	assert_true(_panel._items[1]._selected)
	_panel.deselect_all()
	assert_eq(_panel._selected_uuid, "")
	for item in _panel._items:
		assert_false(item._selected)


# --- Empty layers ---

func test_empty_layers() -> void:
	_panel.update_layers([], false)
	assert_eq(_panel._items.size(), 0)


func test_empty_layers_after_non_empty() -> void:
	var fgs = _create_foregrounds(3)
	_panel.update_layers(fgs, false)
	_panel.update_layers([], false)
	assert_eq(_panel._items.size(), 0)


# --- Add button ---

func test_add_button_exists() -> void:
	assert_not_null(_panel._add_btn)
	assert_true(_panel._add_btn.is_inside_tree())


func test_add_button_text() -> void:
	assert_eq(_panel._add_btn.text, "+ Ajouter")


# --- Paste button ---

func test_paste_button_exists() -> void:
	assert_not_null(_panel._paste_btn)
	assert_true(_panel._paste_btn.is_inside_tree())


# --- Signals ---

func test_foreground_clicked_signal_emitted() -> void:
	var fgs = _create_foregrounds(2)
	_panel.update_layers(fgs, false)
	watch_signals(_panel)
	_panel._on_item_clicked(fgs[0].uuid)
	assert_signal_emitted_with_parameters(_panel, "foreground_clicked", [fgs[0].uuid])


func test_foreground_clicked_updates_selection() -> void:
	var fgs = _create_foregrounds(2)
	_panel.update_layers(fgs, false)
	_panel._on_item_clicked(fgs[1].uuid)
	assert_eq(_panel._selected_uuid, fgs[1].uuid)


func test_add_foreground_requested_signal() -> void:
	watch_signals(_panel)
	_panel.add_foreground_requested.emit()
	assert_signal_emitted(_panel, "add_foreground_requested")


func test_paste_foreground_requested_signal() -> void:
	watch_signals(_panel)
	_panel.paste_foreground_requested.emit()
	assert_signal_emitted(_panel, "paste_foreground_requested")


func test_visibility_toggled_signal() -> void:
	watch_signals(_panel)
	_panel._on_visibility_toggled("test-uuid", false)
	assert_signal_emitted_with_parameters(_panel, "foreground_visibility_toggled", ["test-uuid", false])


# --- Selection restored after update ---

func test_selection_restored_after_update_layers() -> void:
	var fgs = _create_foregrounds(3)
	_panel.update_layers(fgs, false)
	_panel.select_foreground(fgs[1].uuid)
	# Rebuild with same foregrounds
	_panel.update_layers(fgs, false)
	assert_true(_panel._items[1]._selected)


# --- Helpers ---

func _create_foregrounds(count: int) -> Array:
	var fgs = []
	for i in range(count):
		var fg = Foreground.new()
		fg.fg_name = "Layer %d" % i
		fg.image = "layer_%d.png" % i
		fg.z_order = i
		fgs.append(fg)
	return fgs
