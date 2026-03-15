extends GutTest

const AIStudioPlugin = preload("res://plugins/ai_studio/plugin.gd")
const Contributions = preload("res://src/plugins/contributions.gd")


func test_plugin_name_is_ai_studio() -> void:
	var plugin := AIStudioPlugin.new()
	assert_eq(plugin.get_plugin_name(), "ai_studio")


func test_menu_entries_returns_one_entry() -> void:
	var plugin := AIStudioPlugin.new()
	var entries := plugin.get_menu_entries()
	assert_eq(entries.size(), 1)


func test_menu_entry_targets_parametres_menu() -> void:
	var plugin := AIStudioPlugin.new()
	var entry: Contributions.MenuEntry = plugin.get_menu_entries()[0]
	assert_eq(entry.menu_id, "parametres")


func test_menu_entry_label_is_studio_ia() -> void:
	var plugin := AIStudioPlugin.new()
	var entry: Contributions.MenuEntry = plugin.get_menu_entries()[0]
	assert_eq(entry.label, "Studio IA")


func test_menu_entry_has_valid_callback() -> void:
	var plugin := AIStudioPlugin.new()
	var entry: Contributions.MenuEntry = plugin.get_menu_entries()[0]
	assert_true(entry.callback.is_valid())
