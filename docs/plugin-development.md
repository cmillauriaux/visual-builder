# Plugin Development Guide

This guide explains how to create plugins for Frame Novel Studio. Plugins extend either the story editor, the game player, or both.

---

## Table of Contents

1. [Overview](#overview)
2. [Plugin Directory Structure](#plugin-directory-structure)
3. [Editor Plugins](#editor-plugins)
4. [Game Plugins](#game-plugins)
5. [Plugin Context](#plugin-context)
6. [Plugin Settings](#plugin-settings)
7. [Tutorial: Building a Word Count Plugin](#tutorial-building-a-word-count-plugin)

---

## Overview

Frame Novel Studio has two plugin types:

| Type | Base class | Entry point | Loaded in |
|------|-----------|-------------|-----------|
| **Editor plugin** | `VBPlugin` | `plugin.gd` | Editor only |
| **Game plugin** | `VBGamePlugin` | `game_plugin.gd` | Game player (and editor config) |

A single plugin can have both an editor and a game component by including both files in its directory.

Plugins are discovered automatically. Place your plugin folder inside `plugins/` at the project root and restart the application.

---

## Plugin Directory Structure

```
plugins/
└── my_plugin/
    ├── plugin.gd           # Editor plugin (optional)
    ├── game_plugin.gd      # Game plugin (optional)
    └── ...                 # Any additional scripts, scenes, assets
```

At least one of `plugin.gd` or `game_plugin.gd` must be present.

---

## Editor Plugins

Editor plugins extend `VBPlugin` (`src/plugins/editor_plugin.gd`) and contribute UI elements to the story editor.

### Minimal editor plugin

```gdscript
extends "res://src/plugins/editor_plugin.gd"

func get_plugin_name() -> String:
    return "my_plugin"
```

### Available contribution methods

Override any of these methods to register UI contributions:

| Method | Returns | Description |
|--------|---------|-------------|
| `get_plugin_name()` | `String` | **Required.** Unique plugin identifier |
| `get_menu_entries()` | `Array[MenuEntry]` | Add items to editor menus |
| `get_toolbar_items()` | `Array[ToolbarItem]` | Add buttons to the toolbar |
| `get_dock_panels()` | `Array[DockPanelDef]` | Add dockable panels |
| `get_sequence_tabs()` | `Array[SequenceTabDef]` | Add tabs to the sequence editor |
| `get_background_services()` | `Array[BackgroundServiceDef]` | Add persistent background services |
| `get_image_picker_tabs()` | `Array[ImagePickerTabDef]` | Add tabs to the image picker dialog |

### Contribution types

All contribution types are defined in `src/plugins/contributions.gd`.

#### MenuEntry

Add an item to an editor menu.

```gdscript
const Contributions = preload("res://src/plugins/contributions.gd")

func get_menu_entries() -> Array:
    var entry = Contributions.MenuEntry.new()
    entry.menu_id = "parametres"   # "parametres" (Settings) or "histoire" (Story)
    entry.label = "My Action"
    entry.callback = _on_my_action
    return [entry]

func _on_my_action(ctx: RefCounted) -> void:
    # ctx is a PluginContext instance
    print("Story title: ", ctx.story.title if ctx.story else "none")
```

#### ToolbarItem

Add a button to the toolbar at a specific navigation level.

```gdscript
func get_toolbar_items() -> Array:
    var item = Contributions.ToolbarItem.new()
    item.level = "sequence"    # "chapter", "scene", or "sequence"
    item.label = "My Button"
    item.icon = null           # Optional Texture2D
    item.callback = _on_toolbar_pressed
    return [item]
```

#### DockPanelDef

Add a dockable panel to the editor.

```gdscript
func get_dock_panels() -> Array:
    var panel_def = Contributions.DockPanelDef.new()
    panel_def.title = "My Panel"
    panel_def.position = "right"   # "left", "right", or "bottom"
    panel_def.create_panel = func(ctx: RefCounted) -> Control:
        var panel = VBoxContainer.new()
        var label = Label.new()
        label.text = "Hello from my plugin!"
        panel.add_child(label)
        return panel
    return [panel_def]
```

#### SequenceTabDef

Add a tab to the sequence editor's right panel.

```gdscript
func get_sequence_tabs() -> Array:
    var tab_def = Contributions.SequenceTabDef.new()
    tab_def.title = "My Tab"
    tab_def.create_tab = func(ctx: RefCounted) -> Control:
        var tab = VBoxContainer.new()
        # Build your tab UI here
        return tab
    return [tab_def]
```

#### BackgroundServiceDef

Register a persistent Node that runs in the background while the editor is open.

```gdscript
func get_background_services() -> Array:
    var service_def = Contributions.BackgroundServiceDef.new()
    service_def.service_script = preload("res://plugins/my_plugin/my_service.gd")
    service_def.setup_callback = func(node: Node, ctx: RefCounted) -> void:
        node.initialize(ctx)
    return [service_def]
```

#### ImagePickerTabDef

Add a tab to the image picker dialog.

```gdscript
func get_image_picker_tabs() -> Array:
    var tab_def = Contributions.ImagePickerTabDef.new()
    tab_def.label = "My Images"
    tab_def.create_tab = func(context: Dictionary) -> Control:
        # context keys: mode, story_base_path, story,
        #   category_service, on_image_selected, on_show_preview
        var tab = VBoxContainer.new()
        return tab
    return [tab_def]
```

---

## Game Plugins

Game plugins extend `VBGamePlugin` (`src/plugins/game_plugin.gd`) and hook into the story playback lifecycle.

### Minimal game plugin

```gdscript
extends "res://src/plugins/game_plugin.gd"

func get_plugin_name() -> String:
    return "my_plugin"

func get_plugin_folder() -> String:
    return "my_plugin"
```

### Identification methods

| Method | Returns | Description |
|--------|---------|-------------|
| `get_plugin_name()` | `String` | **Required.** Unique plugin identifier |
| `get_plugin_folder()` | `String` | **Required.** Folder name under `plugins/` |
| `get_plugin_description()` | `String` | Short description for UI labels |
| `is_configurable()` | `bool` | Whether the player can toggle this plugin on/off (default: `true`) |

### Lifecycle hooks

These methods are called at key moments during story playback. All receive a `GamePluginContext` as the `ctx` parameter.

#### Game lifecycle

| Hook | When |
|------|------|
| `on_game_ready(ctx)` | Game is ready (story loaded, UI built) |
| `on_game_cleanup(ctx)` | Game is shutting down |

#### Story navigation

| Hook | When |
|------|------|
| `on_before_chapter(ctx)` | Before entering a chapter |
| `on_after_chapter(ctx)` | After entering a chapter |
| `on_before_scene(ctx)` | Before entering a scene |
| `on_after_scene(ctx)` | After entering a scene |
| `on_before_sequence(ctx)` | Before entering a sequence |
| `on_after_sequence(ctx)` | After entering a sequence |

#### Story events

| Hook | Signature | When |
|------|-----------|------|
| `on_story_started` | `(ctx, story_title: String, story_version: String)` | New game starts |
| `on_story_finished` | `(ctx, reason: String)` | Story ends (narrative end or player quit) |
| `on_story_saved` | `(ctx, story_title: String, slot_index: int, chapter: String, scene: String, sequence: String)` | Save created |
| `on_story_loaded` | `(ctx, story_title: String, slot_index: int)` | Save loaded |
| `on_game_quit` | `(ctx, chapter: String, scene: String, sequence: String)` | Player quits to menu |
| `on_quicksave` | `(ctx, story_title: String, chapter: String)` | Quick save |
| `on_quickload` | `(ctx, story_title: String)` | Quick load |

### Transformation pipelines

These methods let plugins transform content before it is displayed. They are chained across all enabled plugins, so each plugin receives the output of the previous one.

#### Dialogue pipeline

```gdscript
# Called before displaying a dialogue line.
# Return a modified dictionary to transform the dialogue.
func on_before_dialogue(ctx: RefCounted, character: String, text: String) -> Dictionary:
    return {"character": character, "text": text}

# Called after a dialogue line is displayed.
func on_after_dialogue(ctx: RefCounted, character: String, text: String) -> void:
    pass
```

#### Choice pipeline

```gdscript
# Called before displaying choices. Return a modified array to transform them.
func on_before_choice(ctx: RefCounted, choices: Array) -> Array:
    return choices

# Style individual choice buttons (colors, icons, etc.).
func on_style_choice_button(ctx: RefCounted, btn: Button, choice: RefCounted, index: int) -> void:
    pass

# Called after the player makes a choice.
func on_after_choice(ctx: RefCounted, choice_index: int, choice_text: String) -> void:
    pass
```

### UI contributions (game)

Game plugins can contribute UI elements to the player interface.

| Method | Returns | Description |
|--------|---------|-------------|
| `get_toolbar_buttons()` | `Array[GameToolbarButton]` | Buttons above the dialogue area |
| `get_overlay_panels()` | `Array[GameOverlayPanelDef]` | Panels on the left, right, or top of the game view |
| `get_options_controls()` | `Array[GameOptionsControlDef]` | Controls in the Plugins section of the options menu |
| `get_editor_config_controls()` | `Array[GameOptionsControlDef]` | Configuration controls in the editor's plugin settings dialog |
| `get_export_options()` | `Array[ExportOptionDef]` | Checkboxes in the export dialog to include/exclude the plugin |

All game contribution types are defined in `src/plugins/game_contributions.gd`.

#### GameToolbarButton

```gdscript
const GameContributions = preload("res://src/plugins/game_contributions.gd")

func get_toolbar_buttons() -> Array:
    var btn = GameContributions.GameToolbarButton.new()
    btn.label = "My Button"
    btn.icon = null
    btn.callback = func(ctx: RefCounted) -> void:
        print("Button pressed!")
    return [btn]
```

#### GameOverlayPanelDef

```gdscript
func get_overlay_panels() -> Array:
    var panel = GameContributions.GameOverlayPanelDef.new()
    panel.position = "right"   # "left", "right", or "top"
    panel.create_panel = func(ctx: RefCounted) -> Control:
        var container = VBoxContainer.new()
        return container
    return [panel]
```

#### GameOptionsControlDef

```gdscript
# In-game options (receives GameSettings)
func get_options_controls() -> Array:
    var def = GameContributions.GameOptionsControlDef.new()
    def.create_control = func(settings: RefCounted) -> Control:
        var checkbox = CheckBox.new()
        checkbox.text = "Enable my feature"
        return checkbox
    return [def]

# Editor config (receives plugin_settings Dictionary)
func get_editor_config_controls() -> Array:
    var def = GameContributions.GameOptionsControlDef.new()
    def.create_control = func(plugin_settings: Dictionary) -> Control:
        var container = VBoxContainer.new()
        # Build configuration UI
        return container
    return [def]
```

#### ExportOptionDef

```gdscript
func get_export_options() -> Array:
    var def = GameContributions.ExportOptionDef.new()
    def.label = "Include My Plugin"
    def.key = "my_plugin"
    def.default_value = true
    return [def]
```

### Reading editor config

When your plugin provides editor configuration controls, implement `read_editor_config()` to extract the settings from the UI control:

```gdscript
func read_editor_config(control: Control) -> Dictionary:
    return {
        "enabled": control.get_node("EnableCheckbox").button_pressed,
        "api_key": control.get_node("ApiKeyField").text,
    }
```

The returned dictionary is stored in `story.plugin_settings[plugin_name]` and can be read at runtime via `ctx.story.plugin_settings[get_plugin_name()]`.

---

## Plugin Context

### PluginContext (editor)

Passed to editor plugin callbacks. Defined in `src/plugins/plugin_context.gd`.

| Property | Type | Description |
|----------|------|-------------|
| `story` | `Story` | Current story model (may be `null`) |
| `story_base_path` | `String` | Absolute path to story directory |
| `current_chapter` | `Chapter` | Currently active chapter (may be `null`) |
| `current_scene` | `SceneData` | Currently active scene (may be `null`) |
| `current_sequence` | `Sequence` | Currently active sequence (may be `null`) |
| `main_node` | `Control` | Reference to the editor's main node |

### GamePluginContext (game)

Passed to game plugin hooks. Defined in `src/plugins/game_plugin_context.gd`.

| Property | Type | Description |
|----------|------|-------------|
| `story` | `Story` | Current story model (may be `null`) |
| `story_base_path` | `String` | Absolute path to story directory |
| `current_chapter` | `Chapter` | Currently active chapter (may be `null`) |
| `current_scene` | `SceneData` | Currently active scene (may be `null`) |
| `current_sequence` | `Sequence` | Currently active sequence (may be `null`) |
| `current_dialogue_index` | `int` | Index of current dialogue (`-1` if none) |
| `variables` | `Dictionary` | Game variables -- read and write directly |
| `game_node` | `Control` | Main game node -- use for adding overlays and popups |
| `settings` | `GameSettings` | Player settings reference |

---

## Plugin Settings

Plugin configuration is stored per-story in `story.yaml` under the `plugin_settings` key:

```yaml
plugin_settings:
  my_plugin:
    enabled: true
    api_key: "abc123"
    custom_option: "value"
```

### Workflow

1. In the editor, the user opens the plugin settings dialog
2. Your plugin's `get_editor_config_controls()` builds the configuration UI
3. When the user saves, `read_editor_config(control)` extracts a Dictionary from your UI
4. The dictionary is stored in `story.plugin_settings["my_plugin"]`
5. At runtime, your game plugin reads it via `ctx.story.plugin_settings[get_plugin_name()]`

### Enabling and disabling

If `is_configurable()` returns `true` (the default), the player can toggle your plugin on or off in the options menu. The enabled/disabled state is stored in the player's game settings, separate from the story file.

---

## Tutorial: Building a Word Count Plugin

Let's build a simple editor plugin that displays the total word count of the current story.

### Step 1: Create the plugin directory

```
plugins/
└── word_count/
    └── plugin.gd
```

### Step 2: Write the plugin

```gdscript
# plugins/word_count/plugin.gd
extends "res://src/plugins/editor_plugin.gd"

const Contributions = preload("res://src/plugins/contributions.gd")

func get_plugin_name() -> String:
    return "word_count"

func get_dock_panels() -> Array:
    var panel_def = Contributions.DockPanelDef.new()
    panel_def.title = "Word Count"
    panel_def.position = "bottom"
    panel_def.create_panel = _create_panel
    return [panel_def]

func _create_panel(ctx: RefCounted) -> Control:
    var panel = HBoxContainer.new()

    var label = Label.new()
    label.text = "Words: --"
    label.name = "WordCountLabel"
    panel.add_child(label)

    var button = Button.new()
    button.text = "Refresh"
    button.pressed.connect(_on_refresh.bind(ctx, label))
    panel.add_child(button)

    return panel

func _on_refresh(ctx: RefCounted, label: Label) -> void:
    if not ctx.story:
        label.text = "Words: no story loaded"
        return

    var total_words := 0
    for chapter in ctx.story.chapters:
        for scene in chapter.scenes:
            for sequence in scene.sequences:
                for dialogue in sequence.dialogues:
                    total_words += dialogue.text.split(" ").size()

    label.text = "Words: %d" % total_words
```

### Step 3: Test

1. Restart Frame Novel Studio (or re-open the project in Godot)
2. The "Word Count" panel appears at the bottom of the editor
3. Load a story and click "Refresh" to see the word count

### Next steps

- Add a game plugin component (`game_plugin.gd`) to display word count during playback
- Use `get_sequence_tabs()` to show per-sequence word counts in the sequence editor
- Use `get_toolbar_items()` for a toolbar button that triggers the count
