# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends Node

const Contributions = preload("res://src/plugins/contributions.gd")
const PluginContext = preload("res://src/plugins/plugin_context.gd")

## List of loaded VBPlugin instances
var _plugins: Array = []

## Monotonically-increasing counter for menu item IDs (starts at 1000)
var _next_menu_id: int = 1000

## Maps menu item ID → Callable for callback dispatch
var _menu_callbacks: Dictionary = {}

## Graph context menu contributions
var _graph_context_menu_entries: Array = []

## Reference to main node — set by apply_contributions()
var _current_main: Control = null


## Registers an already-loaded plugin instance.
func register_plugin(plugin: RefCounted) -> void:
	_plugins.append(plugin)


## Returns the number of registered plugins.
func get_plugin_count() -> int:
	return _plugins.size()


## Scans a directory for plugin.gd files and loads them.
## Safe to call with nonexistent paths.
func scan_and_load_plugins(plugins_dir: String = "res://plugins/") -> void:
	var dir := DirAccess.open(plugins_dir)
	if dir == null:
		push_warning("PluginManager: directory not found: %s" % plugins_dir)
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir() and not entry.begins_with("."):
			_try_load_plugin("%s%s/plugin.gd" % [plugins_dir, entry])
		entry = dir.get_next()
	dir.list_dir_end()


## Injects all registered plugin contributions into the editor.
func apply_contributions(main: Control) -> void:
	_current_main = main
	_graph_context_menu_entries.clear()
	for plugin in _plugins:
		_inject_menu_entries(plugin, main)
		_inject_toolbar_items(plugin, main)
		_inject_dock_panels(plugin, main)
		_inject_sequence_tabs(plugin, main)
		_inject_background_services(plugin, main)
		_collect_graph_context_menu_entries(plugin)


# --- Private ---

func _collect_graph_context_menu_entries(plugin: RefCounted) -> void:
	if not plugin.has_method("get_graph_context_menu_entries"):
		return
	for entry in plugin.get_graph_context_menu_entries():
		_graph_context_menu_entries.append(entry)


func get_graph_context_menu_entries() -> Array:
	return _graph_context_menu_entries

func _try_load_plugin(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var loaded = load(path)
	if loaded == null:
		push_warning("PluginManager: failed to load %s" % path)
		return
	var instance = loaded.new()
	var name: String = ""
	if instance.has_method("get_plugin_name"):
		name = instance.get_plugin_name()
	if name == "":
		push_warning("PluginManager: plugin at %s returned empty name, skipping" % path)
		return
	register_plugin(instance)


func _inject_menu_entries(plugin: RefCounted, main: Control) -> void:
	if not plugin.has_method("get_menu_entries"):
		return
	for entry in plugin.get_menu_entries():
		var popup := _get_popup_for_menu(entry.menu_id, main)
		if popup == null:
			push_warning("PluginManager: unknown menu_id '%s'" % entry.menu_id)
			continue
		_register_menu_callback(popup, entry.label, entry.callback)


func _get_popup_for_menu(menu_id: String, main: Control) -> PopupMenu:
	var menu_btn: MenuButton
	match menu_id:
		"histoire":
			menu_btn = main.get("_histoire_menu")
		"parametres":
			menu_btn = main.get("_parametres_menu")
		_:
			# Fallback if unknown
			menu_btn = main.get("_histoire_menu")
	if menu_btn == null:
		return null
	return menu_btn.get_popup()


func _register_menu_callback(popup: PopupMenu, label: String, callback: Callable) -> void:
	var id := _next_menu_id
	_next_menu_id += 1
	_menu_callbacks[id] = callback
	popup.add_item(label, id)
	if not popup.id_pressed.is_connected(_on_menu_id_pressed):
		popup.id_pressed.connect(_on_menu_id_pressed)


func _on_menu_id_pressed(id: int) -> void:
	if not _menu_callbacks.has(id):
		return
	var ctx := _build_context()
	_menu_callbacks[id].call(ctx)


func _inject_toolbar_items(plugin: RefCounted, main: Control) -> void:
	if not plugin.has_method("get_toolbar_items"):
		return
	for item in plugin.get_toolbar_items():
		var toolbar := _get_toolbar_for_level(item.level, main)
		if toolbar == null:
			push_warning("PluginManager: unknown toolbar level '%s'" % item.level)
			continue
		var btn := Button.new()
		btn.text = item.label
		if item.icon != null:
			btn.icon = item.icon
		var cb: Callable = item.callback
		btn.pressed.connect(func(): cb.call(_build_context()))
		toolbar.add_child(btn)


func _get_toolbar_for_level(level: String, main: Control) -> HBoxContainer:
	var key: String
	match level:
		"sequence":
			key = "_sequence_toolbar"
		"chapter":
			key = "_chapter_plugin_toolbar"
		"scene":
			key = "_scene_plugin_toolbar"
		_:
			return null
	return main.get(key)


func _inject_dock_panels(plugin: RefCounted, main: Control) -> void:
	if not plugin.has_method("get_dock_panels"):
		return
	for def in plugin.get_dock_panels():
		var dock := _get_dock_for_position(def.position, main)
		if dock == null:
			push_warning("PluginManager: unknown dock position '%s'" % def.position)
			continue
		var panel: Control = def.create_panel.call(_build_context())
		if panel != null:
			dock.add_child(panel)
			dock.visible = true


func _get_dock_for_position(position: String, main: Control) -> PanelContainer:
	var key: String
	match position:
		"left":
			key = "_dock_left"
		"right":
			key = "_dock_right"
		"bottom":
			key = "_dock_bottom"
		_:
			return null
	return main.get(key)


func _inject_sequence_tabs(plugin: RefCounted, main: Control) -> void:
	if not plugin.has_method("get_sequence_tabs"):
		return
	for def in plugin.get_sequence_tabs():
		var tab_container: TabContainer = main.get("_sequence_tab_container")
		if tab_container == null:
			push_warning("PluginManager: main has no _sequence_tab_container")
			continue
		var tab: Control = def.create_tab.call(_build_context())
		if tab != null:
			tab.name = def.title
			tab_container.add_child(tab)


func _inject_background_services(plugin: RefCounted, main: Control) -> void:
	if not plugin.has_method("get_background_services"):
		return
	for def in plugin.get_background_services():
		if def.service_script == null:
			continue
		var node := Node.new()
		node.set_script(def.service_script)
		main.add_child(node)
		if def.setup_callback.is_valid():
			def.setup_callback.call(node, _build_context())


## Notifies all plugin sequence tabs that the active sequence changed.
## Calls setup(ctx) on each tab child that has the method.
func notify_sequence_tabs() -> void:
	if _current_main == null:
		return
	var tab_container: TabContainer = _current_main.get("_sequence_tab_container")
	if tab_container == null:
		return
	var ctx := _build_context()
	for tab in tab_container.get_children():
		if tab.has_method("setup"):
			tab.setup(ctx)


## Returns all ImagePickerTabDef contributions from all plugins.
func get_image_picker_tabs() -> Array:
	var result: Array = []
	for plugin in _plugins:
		result.append_array(plugin.get_image_picker_tabs())
	return result


func _build_context() -> RefCounted:
	var ctx := PluginContext.new()
	ctx.main_node = _current_main
	if _current_main == null:
		return ctx
	# Access story state if available
	if "_editor_main" in _current_main and _current_main.get("_editor_main") != null:
		var em: Object = _current_main.get("_editor_main")
		if "_story" in em:
			ctx.story = em.get("_story")
		if "_current_chapter" in em:
			ctx.current_chapter = em.get("_current_chapter")
		if "_current_scene" in em:
			ctx.current_scene = em.get("_current_scene")
		if "_current_sequence" in em:
			ctx.current_sequence = em.get("_current_sequence")
	if _current_main.has_method("_get_story_base_path"):
		ctx.story_base_path = _current_main._get_story_base_path()
	return ctx