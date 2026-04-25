# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

## Value objects for plugin contributions.
## Each inner class represents one type of integration point a plugin can offer.


class MenuEntry extends RefCounted:
	## Menu identifier: "parametres" | "histoire"
	var menu_id: String = ""
	## Label shown in the menu
	var label: String = ""
	## Called with a PluginContext when the item is pressed
	var callback: Callable


class ToolbarItem extends RefCounted:
	## Editor level: "chapter" | "scene" | "sequence"
	var level: String = ""
	## Button label
	var label: String = ""
	## Optional icon (Texture2D)
	var icon = null
	## Called with a PluginContext when the button is pressed
	var callback: Callable


class DockPanelDef extends RefCounted:
	## Panel title
	var title: String = ""
	## Dock position: "left" | "right" | "bottom"
	var position: String = ""
	## Returns a Control given a PluginContext
	var create_panel: Callable


class SequenceTabDef extends RefCounted:
	## Tab title
	var title: String = ""
	## Returns a Control given a PluginContext
	var create_tab: Callable


class BackgroundServiceDef extends RefCounted:
	## Script to instantiate as a Node
	var service_script: Script = null
	## Optional: called once after main.add_child() with (node, ctx)
	var setup_callback: Callable


class ImagePickerTabDef extends RefCounted:
	## Tab label shown in the TabContainer
	var label: String = ""
	## Returns a Control given a context Dictionary.
	## Context keys: mode (int), story_base_path (String), story,
	##   category_service, on_image_selected: Callable(path),
	##   on_show_preview: Callable(texture, filename)
	var create_tab: Callable


class GraphContextMenuEntry extends RefCounted:
	## Label shown in the menu
	var label: String = ""
	## Called with (ctx, selected_uuids) when the item is pressed
	var callback: Callable