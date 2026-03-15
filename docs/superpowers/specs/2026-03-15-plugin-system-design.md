# Plugin System for Visual Builder Editor

**Date:** 2026-03-15
**Status:** Approved

## Context

The editor currently embeds all tools directly in its core code. AI Studio (ComfyUI-based image generation) lives in `src/ui/dialogs/` and is hardwired into `menu_controller.gd`. As the editor grows, more specialized tools (AI, export, analytics, etc.) risk bloating the core.

The goal is a plugin system where:
- The core editor doesn't know about specific plugins in advance
- Plugins live in `res://plugins/<name>/` and are scanned + loaded dynamically at startup
- AI Studio is the first plugin to be migrated out of core

## Architecture

### Directory structure

```
src/plugins/
  editor_plugin.gd       # Base class (interface) — extends RefCounted
  plugin_context.gd      # Context object passed to plugins at action time
  plugin_manager.gd      # Node: scans, loads, injects contributions
  contributions.gd       # Value objects: MenuEntry, ToolbarItem, DockPanelDef, SequenceTabDef, BackgroundServiceDef

plugins/
  ai_studio/
    plugin.gd                     # extends EditorPlugin
    ai_studio_dialog.gd           # moved from src/ui/dialogs/
    ai_studio_decliner_tab.gd     # moved from src/ui/dialogs/
    ai_studio_expressions_tab.gd  # moved from src/ui/dialogs/
    ai_studio_upscale_tab.gd      # moved from src/ui/dialogs/
```

### EditorPlugin interface

```gdscript
class_name EditorPlugin
extends RefCounted

func get_plugin_name() -> String: return ""
func get_menu_entries() -> Array: return []       # Array of Contributions.MenuEntry
func get_toolbar_items() -> Array: return []      # Array of Contributions.ToolbarItem
func get_dock_panels() -> Array: return []        # Array of Contributions.DockPanelDef
func get_sequence_tabs() -> Array: return []      # Array of Contributions.SequenceTabDef
func get_background_services() -> Array: return [] # Array of Contributions.BackgroundServiceDef
```

### Contributions value objects

```gdscript
class MenuEntry:
    var menu_id: String      # "parametres" | "histoire"
    var label: String
    var callback: Callable   # func(ctx: PluginContext)

class ToolbarItem:
    var level: String        # "chapter" | "scene" | "sequence"
    var label: String
    var icon: Texture2D      # optional
    var callback: Callable   # func(ctx: PluginContext)

class DockPanelDef:
    var title: String
    var position: String     # "left" | "right" | "bottom"
    var create_panel: Callable  # func(ctx: PluginContext) -> Control

class SequenceTabDef:
    var title: String
    var create_tab: Callable  # func(ctx: PluginContext) -> Control

class BackgroundServiceDef:
    var script: Script
    var setup_callback: Callable  # optional: func(node: Node, ctx: PluginContext)
```

### PluginContext

Created fresh at action time (not stored):

```gdscript
class_name PluginContext
extends RefCounted

var story           # current Story model (may be null)
var story_base_path: String
var current_chapter # may be null
var current_scene   # may be null
var current_sequence # may be null
var main_node: Control  # reference to main for add_child
```

`main_node` must be non-null (asserted at creation). Context is only valid during callback execution and must not be stored by plugins.

### PluginManager

- Extends `Node`, added to `main` after `MainUIBuilder.build()`
- Scans `res://plugins/` at startup via `DirAccess`
- For each subdirectory, tries to load `plugin.gd`
- Calls `apply_contributions(main)` to inject all contributions

**Error handling:**
- If `res://plugins/` doesn't exist: log warning, return cleanly
- If subdirectory has no `plugin.gd`: skip silently
- If `load()` fails or returns null: log warning with path, skip
- If `get_plugin_name()` throws: log warning, skip

**Menu ID allocation:**
- Counter starts at 1000 (`_next_menu_id`)
- `_register_menu_callback(popup, label, callable)` allocates next ID, stores `id → callable`, calls `popup.add_item(label, id)`
- Plugins never hardcode IDs

**Injection mechanisms:**

| Contribution | Mechanism |
|---|---|
| MenuEntry | `PopupMenu.add_item(label, id)` + dict `id→Callable`; connect to `id_pressed` |
| ToolbarItem (sequence) | Append `Button` to existing `main._sequence_toolbar` |
| ToolbarItem (chapter/scene) | Append `Button` to `main._chapter_plugin_toolbar` / `main._scene_plugin_toolbar` |
| DockPanelDef | Add to `main._dock_left`, `main._dock_right`, or `main._dock_bottom` |
| SequenceTabDef | `TabContainer.add_child()` in sequence editor panel |
| BackgroundServiceDef | `Node.new() + set_script() + main.add_child()`, then `setup_callback` |

### Toolbar injection

- **Sequence toolbar**: items appended as `Button` children to `main._sequence_toolbar` (already created in `main_ui_builder.gd`)
- **Chapter/Scene toolbars**: `main_ui_builder.gd` creates `main._chapter_plugin_toolbar` and `main._scene_plugin_toolbar` as `HBoxContainer`; hidden if empty

### Dock zones

- `main_ui_builder.gd` creates `main._dock_left`, `main._dock_right`, `main._dock_bottom` as `PanelContainer` (hidden by default)
- Multiple panels in the same position stacked vertically
- Dock shows/hides based on whether it has children

### AI Studio plugin

```gdscript
class_name AIStudioPlugin
extends EditorPlugin

const AIStudioDialog = preload("res://plugins/ai_studio/ai_studio_dialog.gd")

func get_plugin_name() -> String: return "ai_studio"

func get_menu_entries() -> Array:
    var e = Contributions.MenuEntry.new()
    e.menu_id = "parametres"
    e.label = "Studio IA"
    e.callback = func(ctx): _open(ctx)
    return [e]

func _open(ctx: PluginContext) -> void:
    if ctx.story == null: return
    var dlg = Window.new()
    dlg.set_script(AIStudioDialog)
    ctx.main_node.add_child(dlg)
    dlg.setup(ctx.story, ctx.story_base_path)
    dlg.popup_centered()
```

## Files modified (existing)

| File | Change |
|---|---|
| `src/main.gd` | Add `_plugin_manager` node; call setup after `_setup_controllers()`; add `get_current_context()` |
| `src/controllers/main_ui_builder.gd` | Add plugin toolbars and dock zones |
| `src/controllers/menu_controller.gd` | Remove AI Studio hardwired code |
| `specs/ui/dialogs/test_ai_studio_dialog.gd` | Update preload paths |

## Tests

```
specs/plugins/
  test_editor_plugin.gd
  test_contributions.gd
  test_plugin_context.gd
  test_plugin_manager.gd

specs/plugins/ai_studio/
  test_ai_studio_plugin.gd
```

## Acceptance criteria

- [ ] `EditorPlugin` base class exists with all 6 interface methods returning correct default types
- [ ] All 5 contribution value objects exist with correct fields
- [ ] `PluginContext` has all required fields; asserts `main_node != null`
- [ ] `PluginManager` scans `res://plugins/` and loads each `plugin.gd`
- [ ] `PluginManager` handles missing directory/file/load errors gracefully
- [ ] Menu entries from plugins are injected into correct `PopupMenu` with IDs ≥ 1000
- [ ] Multiple plugins don't collide on menu IDs
- [ ] Toolbar items injected at correct level
- [ ] Dock panels injected into correct zone
- [ ] Sequence tabs injected into sequence editor
- [ ] Background services added as child nodes
- [ ] AI Studio plugin declares `"ai_studio"` name and `"Studio IA"` menu entry in `"parametres"`
- [ ] All AI Studio dialog files moved to `plugins/ai_studio/`
- [ ] AI Studio no longer referenced in `menu_controller.gd`
- [ ] All existing tests still pass after migration
- [ ] Coverage target 65% maintained
