# Architecture

This document describes the architecture of Frame Novel Studio for developers and contributors.

Frame Novel Studio is a visual novel editor and game engine built with Godot 4.6.1, using GDScript and the GL Compatibility renderer (required for HTML5/web export). The codebase is approximately 32K lines of GDScript.

---

## Table of Contents

1. [Overview](#overview)
2. [High-Level Architecture](#high-level-architecture)
3. [Directory Structure](#directory-structure)
4. [Architectural Patterns](#architectural-patterns)
5. [Data Model](#data-model)
6. [Data Flow](#data-flow)
7. [Plugin Architecture](#plugin-architecture)
8. [Key Design Decisions](#key-design-decisions)

---

## Overview

Frame Novel Studio operates in two distinct modes, both built from the same codebase:

- **Editor Mode** (`main.tscn` / `main.gd`): A full story editing suite with graph editors, sequence editors, dialogue editors, export tools, and plugin support. This is where authors create and edit their visual novels.

- **Game Player Mode** (`game.tscn` / `game.gd`): A standalone story playback engine used in exported games. Provides story playback, save/load, menus, options, and runtime plugin support.

Both modes share the same models, services, persistence layer, and plugin framework. The separation ensures that exported games contain only the player code, keeping the final build lightweight.

---

## High-Level Architecture

```
+-------------------------------------------------------------+
|                     Frame Novel Studio                       |
+-----------------------------+-------------------------------+
|   Editor (main.gd)          |   Game Player (game.gd)       |
|   - Graph editors           |   - Story playback            |
|   - Sequence editor         |   - Save/load                 |
|   - Dialogue editor         |   - Menus & options           |
|   - Export UI                |   - Settings                  |
|   - Image/audio pickers     |   - PWA support               |
+-----------------------------+-------------------------------+
|                        Controllers                           |
|  NavigationController  PlayController  UIController          |
|  MenuController  SequenceUIController  PlayUIController      |
|  EditorState  GamePlayController                             |
+-------------------------------------------------------------+
|                         Services                             |
|  ExportService  MusicPlayer  UndoRedoService  EventBus      |
|  StoryVerifier  StoryI18nService  PckChapterLoader           |
|  ScreenshotService  NotificationService  LocaleDetector     |
+-------------------------------------------------------------+
|                          Models                              |
|  Story  Chapter  SceneData  Sequence  Dialogue  Foreground   |
|  Choice  Consequence  Condition  ConditionRule  Ending       |
|  VariableDefinition  VariableEffect  SequenceFX              |
+-------------------------------------------------------------+
|                       Persistence                            |
|  StorySaver (save + load)  YamlParser  GameSaveManager       |
+-------------------------------------------------------------+
|                         Plugins                              |
|  PluginManager  GamePluginManager                            |
|  VBPlugin (editor)  VBGamePlugin (runtime)                   |
|  PluginContext  GamePluginContext  Contributions              |
+-------------------------------------------------------------+
```

---

## Directory Structure

### `src/` -- Application Source

```
src/
|-- main.gd / main.tscn         # Editor entry point
|-- game.gd / game.tscn         # Game player entry point
|
|-- commands/                    # Undo/redo command objects
|   |-- base_command.gd         # Abstract base (execute, undo, get_label)
|   |-- add_chapter_command.gd
|   |-- add_scene_command.gd
|   |-- add_sequence_command.gd
|   |-- add_dialogue_command.gd
|   |-- add_condition_command.gd
|   |-- remove_chapter_command.gd
|   |-- remove_scene_command.gd
|   |-- remove_sequence_command.gd
|   |-- remove_dialogue_command.gd
|   |-- remove_condition_command.gd
|   |-- edit_dialogue_command.gd
|   |-- rename_node_command.gd
|   |-- move_node_command.gd
|   |-- replace_foreground_image_command.gd
|   |-- replace_with_new_foreground_command.gd
|   +-- set_sequence_transition_command.gd
|
|-- controllers/                 # Business logic orchestrators
|   |-- main_ui_builder.gd      # Constructs the editor interface
|   |-- game_ui_builder.gd      # Constructs the game player interface
|   |-- navigation_controller.gd # Story navigation (create/delete/rename)
|   |-- play_controller.gd      # Sequence/story playback logic
|   |-- game_play_controller.gd # Game-mode playback controller
|   |-- menu_controller.gd      # Menu interactions in editor
|   |-- sequence_ui_controller.gd # Sequence editing actions
|   |-- ui_controller.gd        # General UI orchestration (undo/redo, etc.)
|   |-- play_ui_controller.gd   # Game play UI controller
|   |-- play_context.gd         # Playback state context
|   +-- editor_state.gd         # Tracks current editor mode/selection
|
|-- export/                      # Export pipeline
|   |-- pck_chapter_builder.gd  # Builds per-chapter PCK files
|   |-- story_path_rewriter.gd  # Rewrites asset paths for export
|   +-- rewrite_runner.gd       # Orchestrates path rewriting
|
|-- models/                      # Pure data classes (no game logic)
|   |-- story.gd                # Root model: metadata, chapters, variables
|   |-- chapter.gd              # Contains scenes
|   |-- scene_data.gd           # Contains sequences and conditions
|   |-- sequence.gd             # Dialogues, foregrounds, FX, ending
|   |-- dialogue.gd             # Character name, text, audio, timing
|   |-- foreground.gd           # Visual layer (image, position, effects)
|   |-- choice.gd               # Player choice with consequences
|   |-- consequence.gd          # Navigation target from a choice
|   |-- condition.gd            # Variable-based branching node
|   |-- condition_rule.gd       # Individual condition rule
|   |-- ending.gd               # Sequence ending (choices or next target)
|   |-- variable_definition.gd  # Story variable schema
|   |-- variable_effect.gd      # Variable mutation on choice
|   |-- sequence_fx.gd          # Visual/audio effects on sequences
|   +-- story_notification.gd   # In-game notification model
|
|-- persistence/                 # YAML serialization/deserialization
|   |-- story_saver.gd          # Save and load stories (YAML <-> models)
|   |-- yaml_parser.gd          # Low-level YAML read/write
|   +-- game_save_manager.gd    # Player save game slots
|
|-- plugins/                     # Plugin framework
|   |-- plugin_manager.gd       # Editor plugin discovery and loading
|   |-- game_plugin_manager.gd  # Game plugin discovery and loading
|   |-- editor_plugin.gd        # Base class for editor plugins (VBPlugin)
|   |-- game_plugin.gd          # Base class for game plugins (VBGamePlugin)
|   |-- plugin_context.gd       # Context passed to editor plugins
|   |-- game_plugin_context.gd  # Context passed to game plugins
|   |-- contributions.gd        # Editor contribution types (menus, toolbars, docks)
|   +-- game_contributions.gd   # Game contribution types (overlays, options)
|
|-- services/                    # Reusable utilities and background services
|   |-- event_bus.gd            # Global signal bus (autoload)
|   |-- export_service.gd       # Story export pipeline orchestration
|   |-- story_i18n_service.gd   # Multi-language support
|   |-- story_verifier.gd       # Story validation and linting
|   |-- story_verifier_formatter.gd # Formats verification reports
|   |-- music_player.gd         # Audio playback manager
|   |-- undo_redo_service.gd    # Undo/redo command stack
|   |-- pck_chapter_loader.gd   # Dynamic chapter PCK loading at runtime
|   |-- comfyui_client.gd       # ComfyUI API client (used by AI Studio plugin)
|   |-- comfyui_config.gd       # ComfyUI configuration (used by AI Studio plugin)
|   |-- notification_service.gd # In-editor notification manager
|   |-- screenshot_service.gd   # Screenshot capture utility
|   |-- locale_detector.gd      # System locale detection
|   |-- auto_play_manager.gd    # Auto-play mode for story playback
|   |-- gallery_cache_service.gd    # Image gallery caching
|   |-- gallery_cleaner_service.gd  # Gallery cleanup utilities
|   |-- image_category_service.gd   # Image categorization
|   |-- image_normalizer_service.gd # Image format normalization
|   |-- image_rename_service.gd     # Batch image renaming
|   |-- blink_manifest_service.gd   # Character blink animation manifests
|   |-- blink_queue_service.gd      # Blink animation queue
|   +-- expression_queue_service.gd # Character expression queue
|
|-- ui/                          # User interface components
|   |-- editors/                 # Story content editors
|   |   |-- editor_main.gd      # Main editor panel orchestrator
|   |   |-- dialogue_editor.gd  # Dialogue text/audio editor
|   |   |-- condition_editor.gd # Condition rule editor
|   |   |-- ending_editor.gd    # Ending/choice editor
|   |   |-- variable_panel.gd   # Story variable manager
|   |   +-- verifier_report_panel.gd # Validation report display
|   |
|   |-- sequence/               # Sequence visual editor and canvas
|   |   |-- dialogue_list_panel.gd   # Dialogue list sidebar
|   |   |-- dialogue_edit_section.gd # Dialogue editing area
|   |   |-- dialogue_timeline.gd     # Timeline view
|   |   |-- foreground_layer_panel.gd # Foreground layer management
|   |   |-- foreground_properties_panel.gd # Foreground properties
|   |   |-- audio_panel.gd          # Audio controls
|   |   +-- fx_panel.gd             # Visual effects panel
|   |
|   |-- dialogs/                # Modal dialogs
|   |   |-- export_dialog.gd    # Export configuration
|   |   |-- image_picker_dialog.gd  # Image selection
|   |   |-- audio_picker_dialog.gd  # Audio selection
|   |   |-- gallery_dialog.gd       # Image gallery browser
|   |   |-- i18n_dialog.gd          # Translation management
|   |   |-- language_manager_dialog.gd # Language configuration
|   |   |-- category_manager_dialog.gd # Asset categories
|   |   |-- image_normalizer_dialog.gd # Image format tools
|   |   |-- menu_config_dialog.gd    # Menu configuration
|   |   +-- notification_dialog.gd   # Notification editing
|   |
|   |-- menu/                   # Game menus
|   |   |-- main_menu.gd       # Title screen
|   |   |-- pause_menu.gd      # In-game pause
|   |   |-- save_load_menu.gd  # Save/load slots
|   |   |-- options_menu.gd    # Game options
|   |   |-- chapter_scene_menu.gd  # Chapter/scene selection
|   |   |-- ending_screen.gd   # End-of-story screen
|   |   |-- game_settings.gd   # Settings persistence
|   |   +-- pwa_install_prompt.gd  # PWA install prompt (web)
|   |
|   |-- play/                   # Playback UI
|   |   |-- story_play_controller.gd # Story playback orchestrator
|   |   |-- variable_sidebar.gd     # Variable state display
|   |   +-- variable_details_overlay.gd # Variable detail popup
|   |
|   |-- navigation/             # Navigation UI
|   |   +-- breadcrumb.gd      # Breadcrumb trail
|   |
|   |-- shared/                 # Reusable UI components
|   |   |-- consequence_target_helper.gd # Target selection helper
|   |   |-- effect_row_builder.gd  # Variable effect row builder
|   |   |-- image_file_dialog.gd   # Image file picker
|   |   |-- image_preview_popup.gd # Image preview tooltip
|   |   +-- texture_loader.gd     # Async texture loading
|   |
|   |-- visual/                 # Visual rendering components
|   |   |-- foreground_transition.gd   # Foreground crossfade transitions
|   |   |-- foreground_blink_player.gd # Character blink animations
|   |   |-- foreground_clipboard.gd    # Foreground copy/paste
|   |   |-- placement_grid.gd         # Foreground placement grid
|   |   +-- sequence_fx_player.gd     # Sequence effect player
|   |
|   +-- themes/                 # UI theming
|       |-- editor_main.tres   # Editor theme resource
|       |-- game_theme.gd      # Game runtime theme builder
|       +-- ui_scale.gd        # DPI-aware UI scaling
|
+-- views/                      # GraphEdit-based node editors
    |-- chapter_graph_view.gd   # Chapter flow graph
    |-- scene_graph_view.gd     # Scene graph within a chapter
    |-- sequence_graph_view.gd  # Sequence/condition branching graph
    |-- story_map_view.gd       # Full story overview map
    |-- graph_node_item.gd      # Base graph node widget
    |-- graph_connections.gd    # Connection management
    |-- graph_reload.gd         # Graph state reload
    +-- connection_colors.gd    # Connection color scheme
```

### `plugins/` -- External Plugins (Project Root)

Plugins are separate directories at the project root, distinct from the plugin framework in `src/plugins/`. Editor plugins use a `plugin.gd` entry point, while game-only plugins use `game_plugin.gd` instead.

```
plugins/
|-- launcher/           # Splash screen and disclaimers
|-- playfab_analytics/  # Cloud analytics via PlayFab
|-- censure/            # Content filtering
+-- walkthrough/        # In-game hints and walkthrough
```

Additional plugins (such as AI image generation or voice synthesis) are available as separate repositories and can be installed by cloning them into this directory.

---

## Architectural Patterns

### MVC with Controllers and Services

The architecture follows a layered pattern inspired by MVC:

- **Models** (`src/models/`): Pure data classes with no game logic. They hold the story structure and can be serialized to YAML. Models are plain `RefCounted` objects with properties -- they do not depend on Godot nodes or the scene tree.

- **Controllers** (`src/controllers/`): Orchestrate business logic. They react to user actions, modify models, and coordinate between services and UI. Each controller has a focused responsibility (navigation, playback, UI state, etc.).

- **Services** (`src/services/`): Stateless or singleton utilities providing cross-cutting functionality (export, i18n, verification, audio, undo/redo). Services do not reference specific UI elements.

- **Views** (`src/views/`): GraphEdit-based visual editors that display and allow manipulation of the story graph. Views observe models and update when data changes.

- **UI** (`src/ui/`): Godot Control nodes organized by function (editors, sequence, dialogs, menus, play, visual, themes).

### Signal-Based Communication

Components communicate through Godot signals, ensuring loose coupling:

- **EventBus** (`src/services/event_bus.gd`): A global autoload that centralizes cross-cutting signals. Events include `story_loaded`, `story_modified`, `navigation_requested`, `editor_mode_changed`, `play_started`, `play_stopped`, `play_dialogue_changed`, `play_choice_requested`, and more.

- **Local signals**: Individual components emit signals for their own state changes, consumed by their direct collaborators.

### Command Pattern

All story editing operations are encapsulated as command objects (`src/commands/`):

- Each command extends `base_command.gd` and implements `execute()`, `undo()`, and `get_label()`.
- Commands are pushed onto the `UndoRedoService` stack, enabling full undo/redo support.
- Examples: `AddChapterCommand`, `RemoveDialogueCommand`, `RenameNodeCommand`, `MoveNodeCommand`, `EditDialogueCommand`.

### Composition Over Inheritance

UI components are composed from reusable pieces rather than deep inheritance hierarchies:

- The editor and game player are assembled by dedicated builder classes (`MainUIBuilder`, `GameUIBuilder`) that construct the UI from independent components.
- Shared components in `src/ui/shared/` are reused across editors.
- Plugin contributions are injected at runtime rather than hardcoded.

### Dual Entry Points

The two modes share the same underlying code:

- `main.gd` instantiates `MainUIBuilder`, `NavigationController`, `UIController`, `PluginManager`, and the full editor stack.
- `game.gd` instantiates `GameUIBuilder`, `GamePlayController`, `GamePluginManager`, and only the playback/menu stack.
- Both use the same models, persistence, and services.

---

## Data Model

### Hierarchy

```
Story
|-- metadata (title, author, languages, variables, plugin_settings)
|-- Chapter[]
    |-- SceneData[]
        |-- Sequence[]
        |   |-- Dialogue[]        (character, text, audio, timing)
        |   |-- Foreground[]      (image layers, position, effects)
        |   |-- SequenceFX[]      (visual/audio effects)
        |   +-- Ending
        |       +-- Choice[]
        |           |-- Consequence   (navigation target)
        |           +-- VariableEffect[] (variable mutations)
        |
        +-- Condition[]
            |-- ConditionRule[]   (variable checks)
            +-- default_consequence
```

### Key Properties

- **All elements are identified by UUID**. References between elements (e.g., a choice pointing to a target sequence) use UUIDs, not object references. This makes serialization straightforward and avoids circular dependencies.

- **Models are pure data**. They extend `RefCounted`, contain only properties and simple accessors, and have no awareness of the UI or scene tree.

- **VariableDefinition** defines the schema for story variables (name, type, default value). **VariableEffect** defines mutations applied when a player makes a choice. **ConditionRule** checks variable state to determine branching.

---

## Data Flow

### Story Loading

```
YAML files on disk
    |
    v
StorySaver.load_story(path, lang)
    |  Reads story.yaml, chapter.yaml, scene YAML files
    |  Uses YamlParser for low-level parsing
    v
Model object tree (Story -> Chapter[] -> SceneData[] -> ...)
    |
    v
EventBus.story_loaded signal
    |
    v
Views and editors populate from model data
```

### Editing (Editor Mode)

```
User interaction (click, type, drag)
    |
    v
Controller receives action
    |
    v
Controller creates Command object
    |
    v
UndoRedoService.execute(command)
    |  Command.execute() mutates the model
    v
EventBus.story_modified signal
    |
    v
UI components observe signal and refresh
```

### Saving

```
User triggers save (Ctrl+S or menu)
    |
    v
StorySaver.save_story(story, path)
    |  Serializes models to YAML via YamlParser
    v
YAML files written to disk
    |
    v
EventBus.story_saved signal
```

### Exporting

```
User configures export (ExportDialog)
    |
    v
ExportService orchestrates the pipeline:
    1. Copy project to temp directory
    2. Copy story assets into temp project
    3. StoryPathRewriter rewrites asset paths
    4. PckChapterBuilder creates per-chapter PCK files
    5. Configure project.godot for game mode
    6. Run Godot export (macOS, Windows, Web)
    |
    v
Standalone game package (app bundle, exe, or HTML5)
```

### Game Playback

```
Game starts (game.gd)
    |
    v
StorySaver.load_story(story_path)
    |
    v
PckChapterLoader loads chapter PCK files on demand
    |
    v
GamePlayController drives playback:
    Sequence -> Dialogue[] (typewriter, audio, foreground transitions)
    |
    v
Ending reached:
    - Choices displayed -> player picks -> Consequence evaluated
    - Variable effects applied
    - Next sequence/scene/chapter loaded
    |
    v
Conditions evaluated (ConditionRule[] against variable state)
    |
    v
Loop continues until story end or player quits
```

---

## Plugin Architecture

### Overview

Plugins extend Frame Novel Studio without modifying core code. The framework supports two plugin types, matching the dual-mode architecture:

- **Editor plugins** (`VBPlugin`): Extend the editing experience with menus, toolbar buttons, dock panels, sequence tabs, and image picker tabs.
- **Game plugins** (`VBGamePlugin`): Extend the runtime player with lifecycle hooks, dialogue/choice transformation, toolbar buttons, overlay panels, and options controls.

### Discovery and Loading

1. `PluginManager` (editor) or `GamePluginManager` (game) scans the `plugins/` directory at project root.
2. Each subdirectory containing a `plugin.gd` file is loaded.
3. The plugin script is instantiated and registered.
4. Contributions are collected and injected into the UI.

### Editor Plugin API (`VBPlugin`)

Editor plugins can provide:

| Method                   | Returns            | Description                          |
|--------------------------|--------------------|--------------------------------------|
| `get_plugin_name()`      | `String`           | Unique plugin identifier             |
| `get_menu_entries()`     | `Array[MenuEntry]` | Menu items (in "parametres" or "histoire" menus) |
| `get_toolbar_items()`    | `Array[ToolbarItem]` | Context-sensitive toolbar buttons  |
| `get_dock_panels()`      | `Array[DockPanelDef]` | Side/bottom dock panels           |
| `get_sequence_tabs()`    | `Array`            | Additional tabs in the sequence editor |
| `get_image_picker_tabs()`| `Array`            | Additional tabs in the image picker |
| `get_background_services()` | `Array`         | Background services to run          |

Plugins receive a `PluginContext` with access to the current story, selected elements, and utility methods.

### Game Plugin API (`VBGamePlugin`)

Game plugins receive lifecycle hooks called by the `GamePlayController`:

| Method                    | Description                                    |
|---------------------------|------------------------------------------------|
| `on_game_ready(ctx)`      | Called when the game is initialized             |
| `on_game_cleanup(ctx)`    | Called on shutdown                               |
| `on_before_chapter(ctx)`  | Called before entering a chapter                 |
| `on_after_chapter(ctx)`   | Called after leaving a chapter                   |
| `on_before_scene(ctx)`    | Called before entering a scene                   |
| `on_after_scene(ctx)`     | Called after leaving a scene                     |
| `on_before_sequence(ctx)` | Called before entering a sequence                |
| `on_after_sequence(ctx)`  | Called after leaving a sequence                  |
| `on_before_dialogue(ctx, character, text)` | Can transform dialogue before display |
| `on_after_dialogue(ctx, character, text)`  | Called after dialogue is shown        |
| `on_before_choice(ctx, choices)` | Can filter/reorder choices before display |

Game plugins can also contribute toolbar buttons, overlay panels, options controls, and export options via `GameContributions`.

### Plugin Settings

Plugin configuration is stored in the story's `story.yaml` file under the `plugin_settings` key. This allows each story to have its own plugin configuration, versioned alongside the story content.

---

## Key Design Decisions

### GL Compatibility Renderer

The project uses Godot's GL Compatibility (OpenGL) renderer instead of Vulkan. This is required for HTML5/web export via WebGL and ensures broad hardware compatibility, including older GPUs and integrated graphics.

### YAML Story Format

Stories are stored as plain YAML files organized in a directory hierarchy:

```
story/
|-- story.yaml              # Story metadata, variables, plugin settings
+-- chapters/
    +-- <chapter-uuid>/
        |-- chapter.yaml    # Chapter metadata
        +-- scenes/
            +-- <scene-uuid>.yaml  # Scene with sequences and conditions
```

This format is:
- **Human-readable**: Authors can inspect and edit stories with any text editor.
- **Version-control friendly**: YAML diffs are clean and meaningful, enabling collaboration via Git.
- **Tool-agnostic**: Stories are not locked into a binary format; external tools can generate or process them.

### UUID-Based References

All story elements (chapters, scenes, sequences, conditions, choices) are identified by UUIDs. Cross-references between elements use these UUIDs rather than indices or object pointers. This ensures:
- Stable references that survive reordering.
- Clean serialization without circular dependency issues.
- Safe concurrent editing (no positional conflicts).

### Separate Editor and Player

The editor (`main.gd`) and player (`game.gd`) are distinct entry points sharing the same underlying code:
- Exported games include only the player, reducing the final build size.
- The editor can be updated independently of exported games.
- The plugin system mirrors this split with `VBPlugin` (editor) and `VBGamePlugin` (runtime).

### Per-Chapter PCK Files

For large stories, chapters can be packaged as individual PCK files and loaded on demand at runtime via `PckChapterLoader`. This enables:
- Smaller initial download sizes for web exports.
- Streaming chapter content as needed.
- Independent chapter updates without re-exporting the entire game.

### Custom YAML Parser

Rather than depending on an external YAML library, Frame Novel Studio includes a custom `YamlParser` (`src/persistence/yaml_parser.gd`) tailored to the story format. This avoids external dependencies and ensures consistent behavior across all platforms Godot supports.
