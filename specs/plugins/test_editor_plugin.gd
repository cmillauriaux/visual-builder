extends GutTest

const VBPlugin = preload("res://src/plugins/editor_plugin.gd")


func test_get_plugin_name_returns_empty_string() -> void:
	var plugin := VBPlugin.new()
	assert_eq(plugin.get_plugin_name(), "")


func test_get_menu_entries_returns_empty_array() -> void:
	var plugin := VBPlugin.new()
	var result := plugin.get_menu_entries()
	assert_typeof(result, TYPE_ARRAY)
	assert_eq(result.size(), 0)


func test_get_toolbar_items_returns_empty_array() -> void:
	var plugin := VBPlugin.new()
	var result := plugin.get_toolbar_items()
	assert_typeof(result, TYPE_ARRAY)
	assert_eq(result.size(), 0)


func test_get_dock_panels_returns_empty_array() -> void:
	var plugin := VBPlugin.new()
	var result := plugin.get_dock_panels()
	assert_typeof(result, TYPE_ARRAY)
	assert_eq(result.size(), 0)


func test_get_sequence_tabs_returns_empty_array() -> void:
	var plugin := VBPlugin.new()
	var result := plugin.get_sequence_tabs()
	assert_typeof(result, TYPE_ARRAY)
	assert_eq(result.size(), 0)


func test_get_background_services_returns_empty_array() -> void:
	var plugin := VBPlugin.new()
	var result := plugin.get_background_services()
	assert_typeof(result, TYPE_ARRAY)
	assert_eq(result.size(), 0)


func test_get_image_picker_tabs_returns_empty_array() -> void:
	var plugin := VBPlugin.new()
	var result := plugin.get_image_picker_tabs()
	assert_typeof(result, TYPE_ARRAY)
	assert_eq(result.size(), 0)
