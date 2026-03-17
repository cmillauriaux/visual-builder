extends GutTest

const AIStudioPlugin = preload("res://plugins/ai_studio/plugin.gd")
const AIStudioDialog = preload("res://plugins/ai_studio/ai_studio_dialog.gd")
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


func test_image_picker_tabs_returns_one_tab() -> void:
	var plugin := AIStudioPlugin.new()
	assert_eq(plugin.get_image_picker_tabs().size(), 1)


func test_image_picker_tab_label_is_ia() -> void:
	var plugin := AIStudioPlugin.new()
	var tab_def: RefCounted = plugin.get_image_picker_tabs()[0]
	assert_eq(tab_def.label, "IA")


func test_image_picker_tab_create_tab_returns_control() -> void:
	var plugin := AIStudioPlugin.new()
	var tab_def: RefCounted = plugin.get_image_picker_tabs()[0]
	var ctrl: Node = tab_def.create_tab.call({})
	assert_not_null(ctrl)
	assert_true(ctrl is Control)
	ctrl.queue_free()


func test_dialog_has_four_tabs() -> void:
	var dialog = AIStudioDialog.new()
	add_child_autofree(dialog)
	await get_tree().process_frame
	assert_eq(dialog._tab_container.get_tab_count(), 4)
