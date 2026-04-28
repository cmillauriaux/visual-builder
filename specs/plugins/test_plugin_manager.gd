extends GutTest

const VBPlugin = preload("res://src/plugins/editor_plugin.gd")
const PluginManager = preload("res://src/plugins/plugin_manager.gd")
const Contributions = preload("res://src/plugins/contributions.gd")
const PluginContext = preload("res://src/plugins/plugin_context.gd")
const FakeMain = preload("res://specs/plugins/fixtures/fake_main.gd")

var _manager: Node
var _main: Control
var _histoire_popup: PopupMenu


func before_each() -> void:
	_manager = PluginManager.new()
	_main = Control.new()
	_main.set_script(FakeMain)
	add_child_autofree(_manager)
	add_child_autofree(_main)

	# Setup minimal main structure expected by PluginManager
	var histoire_menu := MenuButton.new()
	var seq_toolbar := HBoxContainer.new()
	var chapter_toolbar := HBoxContainer.new()
	var scene_toolbar := HBoxContainer.new()
	var dock_left := PanelContainer.new()
	var dock_right := PanelContainer.new()
	var dock_bottom := PanelContainer.new()

	_main._histoire_menu = histoire_menu
	_main._sequence_toolbar = seq_toolbar
	_main._chapter_plugin_toolbar = chapter_toolbar
	_main._scene_plugin_toolbar = scene_toolbar
	_main._dock_left = dock_left
	_main._dock_right = dock_right
	_main._dock_bottom = dock_bottom

	add_child_autofree(histoire_menu)
	add_child_autofree(seq_toolbar)
	add_child_autofree(chapter_toolbar)
	add_child_autofree(scene_toolbar)
	add_child_autofree(dock_left)
	add_child_autofree(dock_right)
	add_child_autofree(dock_bottom)

	_histoire_popup = histoire_menu.get_popup()


# --- Plugin registration ---

func test_register_plugin_adds_to_list() -> void:
	var plugin := VBPlugin.new()
	_manager.register_plugin(plugin)
	assert_eq(_manager.get_plugin_count(), 1)


func test_register_multiple_plugins() -> void:
	_manager.register_plugin(VBPlugin.new())
	_manager.register_plugin(VBPlugin.new())
	assert_eq(_manager.get_plugin_count(), 2)


# --- Menu injection ---

func test_menu_entry_added_to_histoire_popup_from_parametres_id() -> void:
	var plugin := _PluginWithMenu.new()
	plugin.menu_id = "parametres"
	plugin.menu_label = "Test Item"
	_manager.register_plugin(plugin)
	_manager.apply_contributions(_main)

	assert_true(_popup_has_item(_histoire_popup, "Test Item"), "Item should be in histoire popup (redirected from parametres)")


func test_menu_entry_added_to_histoire_popup() -> void:
	var plugin := _PluginWithMenu.new()
	plugin.menu_id = "histoire"
	plugin.menu_label = "Test Histoire"
	_manager.register_plugin(plugin)
	_manager.apply_contributions(_main)

	assert_true(_popup_has_item(_histoire_popup, "Test Histoire"), "Item should be in histoire popup")


func test_menu_item_id_is_at_least_1000() -> void:
	var plugin := _PluginWithMenu.new()
	plugin.menu_id = "histoire"
	plugin.menu_label = "Test"
	_manager.register_plugin(plugin)
	_manager.apply_contributions(_main)

	var id := _get_popup_item_id(_histoire_popup, "Test")
	assert_gte(id, 1000, "Plugin menu IDs must be >= 1000")


func test_two_plugins_get_different_menu_ids() -> void:
	var plugin1 := _PluginWithMenu.new()
	plugin1.menu_id = "histoire"
	plugin1.menu_label = "Item A"
	var plugin2 := _PluginWithMenu.new()
	plugin2.menu_id = "histoire"
	plugin2.menu_label = "Item B"
	_manager.register_plugin(plugin1)
	_manager.register_plugin(plugin2)
	_manager.apply_contributions(_main)

	var id_a := _get_popup_item_id(_histoire_popup, "Item A")
	var id_b := _get_popup_item_id(_histoire_popup, "Item B")
	assert_ne(id_a, -1, "Item A should exist")
	assert_ne(id_b, -1, "Item B should exist")
	assert_ne(id_a, id_b, "Two items must have different IDs")


# --- Toolbar injection ---

func test_toolbar_item_added_to_sequence_toolbar() -> void:
	var plugin := _PluginWithToolbar.new()
	plugin.toolbar_level = "sequence"
	plugin.toolbar_label = "AI Seq"
	_manager.register_plugin(plugin)
	_manager.apply_contributions(_main)

	assert_true(_toolbar_has_button(_main.get("_sequence_toolbar"), "AI Seq"))


func test_toolbar_item_added_to_chapter_toolbar() -> void:
	var plugin := _PluginWithToolbar.new()
	plugin.toolbar_level = "chapter"
	plugin.toolbar_label = "AI Chap"
	_manager.register_plugin(plugin)
	_manager.apply_contributions(_main)

	assert_true(_toolbar_has_button(_main.get("_chapter_plugin_toolbar"), "AI Chap"))


func test_toolbar_item_added_to_scene_toolbar() -> void:
	var plugin := _PluginWithToolbar.new()
	plugin.toolbar_level = "scene"
	plugin.toolbar_label = "AI Scene"
	_manager.register_plugin(plugin)
	_manager.apply_contributions(_main)

	assert_true(_toolbar_has_button(_main.get("_scene_plugin_toolbar"), "AI Scene"))


# --- Dock injection ---

func test_dock_panel_added_to_left_dock() -> void:
	var plugin := _PluginWithDock.new()
	plugin.dock_position = "left"
	_manager.register_plugin(plugin)
	_manager.apply_contributions(_main)

	var dock: PanelContainer = _main.get("_dock_left")
	assert_gt(dock.get_child_count(), 0)


func test_dock_panel_added_to_right_dock() -> void:
	var plugin := _PluginWithDock.new()
	plugin.dock_position = "right"
	_manager.register_plugin(plugin)
	_manager.apply_contributions(_main)

	var dock: PanelContainer = _main.get("_dock_right")
	assert_gt(dock.get_child_count(), 0)


# --- Background service injection ---

func test_background_service_added_to_main() -> void:
	var plugin := _PluginWithService.new()
	_manager.register_plugin(plugin)
	_manager.apply_contributions(_main)

	var found := false
	for child in _main.get_children():
		if child.get_script() == _DummyServiceScript:
			found = true
	assert_true(found, "Background service node should be added to main")


# --- Image picker tab aggregation ---

func test_get_image_picker_tabs_returns_empty_when_no_plugins() -> void:
	assert_eq(_manager.get_image_picker_tabs().size(), 0)


func test_get_image_picker_tabs_collects_from_plugins() -> void:
	var plugin := _PluginWithPickerTab.new()
	_manager.register_plugin(plugin)
	assert_eq(_manager.get_image_picker_tabs().size(), 1)


func test_get_image_picker_tabs_aggregates_multiple_plugins() -> void:
	_manager.register_plugin(_PluginWithPickerTab.new())
	_manager.register_plugin(_PluginWithPickerTab.new())
	assert_eq(_manager.get_image_picker_tabs().size(), 2)


# --- Scan resilience ---

func test_scan_nonexistent_dir_does_not_crash() -> void:
	_manager.scan_and_load_plugins("res://nonexistent_plugins_dir/")
	assert_eq(_manager.get_plugin_count(), 0)


# --- Menu callback invocation ---

func test_menu_callback_is_invoked_on_id_pressed() -> void:
	# Use an Array as a mutable ref to avoid GDScript closure capture issues
	var calls := []
	var plugin := _PluginWithMenu.new()
	plugin.menu_id = "histoire"
	plugin.menu_label = "Callback Test"
	plugin.on_activated = func(_ctx): calls.append(true)
	_manager.register_plugin(plugin)
	_manager.apply_contributions(_main)

	var target_id := _get_popup_item_id(_histoire_popup, "Callback Test")
	assert_ne(target_id, -1, "Item must exist")

	_histoire_popup.id_pressed.emit(target_id)

	assert_eq(calls.size(), 1, "Callback should have been invoked once")


# --- Helpers ---

func _popup_has_item(popup: PopupMenu, label: String) -> bool:
	for i in popup.item_count:
		if popup.get_item_text(i) == label:
			return true
	return false


func _get_popup_item_id(popup: PopupMenu, label: String) -> int:
	for i in popup.item_count:
		if popup.get_item_text(i) == label:
			return popup.get_item_id(i)
	return -1


func _toolbar_has_button(toolbar: HBoxContainer, label: String) -> bool:
	if toolbar == null:
		return false
	for child in toolbar.get_children():
		if child is Button and child.text == label:
			return true
	return false


# --- Mock plugins ---

class _PluginWithMenu extends VBPlugin:
	var menu_id: String = "parametres"
	var menu_label: String = "Item"
	var on_activated: Callable = func(_c): pass

	func get_menu_entries() -> Array:
		var e := Contributions.MenuEntry.new()
		e.menu_id = menu_id
		e.label = menu_label
		e.callback = on_activated
		return [e]


class _PluginWithToolbar extends VBPlugin:
	var toolbar_level: String = "sequence"
	var toolbar_label: String = "Btn"

	func get_toolbar_items() -> Array:
		var item := Contributions.ToolbarItem.new()
		item.level = toolbar_level
		item.label = toolbar_label
		item.callback = func(_c): pass
		return [item]


class _PluginWithDock extends VBPlugin:
	var dock_position: String = "left"

	func get_dock_panels() -> Array:
		var def := Contributions.DockPanelDef.new()
		def.position = dock_position
		def.title = "Panel"
		def.create_panel = func(_c): return Control.new()
		return [def]


class _PluginWithService extends VBPlugin:
	func get_background_services() -> Array:
		var def := Contributions.BackgroundServiceDef.new()
		def.service_script = load("res://specs/plugins/fixtures/dummy_service.gd")
		return [def]


class _PluginWithPickerTab extends VBPlugin:
	func get_image_picker_tabs() -> Array:
		var def := Contributions.ImagePickerTabDef.new()
		def.label = "IA"
		def.create_tab = func(_ctx): return Control.new()
		return [def]


const _DummyServiceScript = preload("res://specs/plugins/fixtures/dummy_service.gd")
