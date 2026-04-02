# Frame Novel Studio -- Feature Reference

Frame Novel Studio is an open-source visual novel editor and player built on Godot 4.6.1. It provides a complete authoring pipeline: write branching stories, compose scenes visually, then export standalone games for Windows, macOS, and the web. Its plugin system lets you extend the editor and player with additional features.

This document is the functional feature reference for users evaluating the tool and story writers wanting to know what is possible.

---

## Table of Contents

1. [Story Editor](#story-editor)
2. [Sequence Visual Editor](#sequence-visual-editor)
3. [Foreground Management](#foreground-management)
4. [Dialogue Editor](#dialogue-editor)
5. [Endings and Choices](#endings-and-choices)
6. [Variable System](#variable-system)
7. [Condition Nodes](#condition-nodes)
8. [Playback and Reader Experience](#playback-and-reader-experience)
9. [Audio System](#audio-system)
10. [Visual Effects](#visual-effects)
11. [Internationalization (i18n)](#internationalization-i18n)
14. [Export and Distribution](#export-and-distribution)
15. [Plugin System](#plugin-system)
16. [Accessibility](#accessibility)

---

## Story Editor

### Three-Level Graph Navigation

Stories are organized into three hierarchical levels, each presented as a Godot GraphEdit canvas with draggable nodes and visual connections:

| Level | Contains | Purpose |
|-------|----------|---------|
| **Chapters** | One or more scenes | Top-level story arcs |
| **Scenes** | One or more sequences and conditions | Narrative beats within a chapter |
| **Sequences / Conditions** | Dialogues, foregrounds, endings | The atomic unit of storytelling |

Each graph supports drag-and-drop node placement, connection drawing between nodes, and standard zoom and pan controls.

### Story Map

The Story Map provides a full hierarchical overview of every chapter, scene, and sequence in a single zoomable, pannable view. It is useful for reviewing the overall structure of a large story at a glance.

### Breadcrumb Navigation

A navigation bar at the top of the editor displays the current location as a breadcrumb trail (Story > Chapter > Scene > Sequence). Click any segment to jump back to that level.

### Story Metadata

Edit top-level story information including title, author, description, and version number.

### Story Verifier

An automated verification tool checks the entire story for structural problems:

- Dead-end sequences with no outgoing connection or ending
- Missing or broken asset references
- Undefined variables referenced in conditions or effects
- Orphaned condition nodes

### Undo / Redo

A full undo/redo stack tracks every editor action. The stack persists during the editing session.

### Keyboard Shortcuts

- **Ctrl+S** -- Save the current story

---

## Sequence Visual Editor

The sequence editor is the primary workspace for composing individual story beats.

| Zone | Approximate Size | Description |
|------|-----------------|-------------|
| **Main canvas** | ~65% width | Displays the background image with positioned foreground layers |
| **Right panel** | ~35% width | Dialogue editing, layer management, properties, secondary tabs |
| **Bottom timeline** | ~120px height | Horizontal scrollable strip of dialogue thumbnails with foreground count badges |

A configurable grid overlay with snap-to-grid support helps with precise foreground positioning on the canvas.

---

## Foreground Management

Foreground layers represent characters, objects, or decorative elements placed on top of the background image.

### Layer List

A visual layer list in the right panel supports:

- Drag-and-drop reordering
- Per-layer visibility and selection
- Z-order control

### Inheritance

Child dialogues inherit foregrounds from their parent. Inherited foregrounds are indicated by an orange dotted border. Writers can override inherited foregrounds on a per-dialogue basis without affecting the parent.

### Positioning

Foreground placement uses a dual-anchor system:

- **anchor_bg** -- The point on the background where the foreground is attached (e.g., center, bottom-left)
- **anchor_fg** -- The point on the foreground image used as the attachment origin (e.g., bottom-center)

This system makes it intuitive to place a character's feet at a specific floor position regardless of image dimensions.

### Properties

| Property | Description |
|----------|-------------|
| Position | Anchor-based placement (see above) |
| Scale | Uniform or non-uniform scaling |
| Z-order | Drawing order relative to other foregrounds |
| Flip H/V | Horizontal and vertical mirroring |
| Opacity | 0.0 (fully transparent) to 1.0 (fully opaque) |
| Transition | None, or fade with configurable duration |

---

## Dialogue Editor

### Text Editing

Each dialogue has a character name field and a text field. Changes are reflected in real time across the canvas, timeline, and preview.

### Timeline

The bottom timeline displays a horizontal strip of thumbnail cards for every dialogue in the current sequence. Each thumbnail shows:

- A mini-preview of the scene composition
- The character name
- A text excerpt
- A badge indicating the number of foreground layers

Dialogues can be reordered by dragging thumbnails in the timeline.

### Per-Dialogue Foreground Overrides

Any dialogue can override the foregrounds inherited from its parent, allowing character expressions or positions to change from line to line without duplicating the full layer setup.

---

## Endings and Choices

The ending editor determines what happens after the last dialogue in a sequence.

### Modes

| Mode | Description |
|------|-------------|
| **Choices** | Present 1 to 8 selectable options to the player |
| **Auto-redirect** | Automatically proceed to the next sequence, scene, chapter, or condition |

### Consequence Types

Each choice or auto-redirect can lead to one of the following:

- Redirect to a specific sequence, scene, chapter, or condition node
- Game over screen (with optional custom message)
- "To be continued" screen

### Variable Effects

Choices can modify story variables when selected. Supported operations: set, increment, decrement, delete. Multiple variable effects can be attached to a single choice.

### Conditional Visibility

Individual choices can be shown or hidden based on variable conditions, enabling dynamic menus that adapt to player decisions.

---

## Variable System

Story-level variables track player state across the entire narrative.

- Variables are defined at the story level with initial values
- A dedicated variable panel is accessible from the editor toolbar
- Four operations are available: **set**, **increment**, **decrement**, **delete**
- Pattern-based notifications using glob patterns allow scripts to react when specific variables change

---

## Condition Nodes

Condition nodes appear in the sequence graph and provide rule-based branching.

### Supported Operators

| Operator | Description |
|----------|-------------|
| `equal` | Variable equals a value |
| `not_equal` | Variable does not equal a value |
| `greater_than` | Variable is greater than a value |
| `greater_than_equal` | Variable is greater than or equal to a value |
| `less_than` | Variable is less than a value |
| `less_than_equal` | Variable is less than or equal to a value |
| `exists` | Variable is defined |
| `not_exists` | Variable is not defined |

Rules are evaluated in order. A default fallback consequence handles cases where no rule matches.

---

## Playback and Reader Experience

The built-in player provides a complete visual novel reading experience.

### Text Display

- **Typewriter effect** -- Text is revealed character by character at a configurable speed
- **Auto-play** -- Configurable delay (1.0, 2.0, 3.0, or 5.0 seconds); waits for typewriter completion; pauses automatically when choices are presented
- **Skip mode** -- Fast-forward through dialogues

### Dialogue History

A scrollable history panel lets readers review all previously read dialogues and navigate back through the conversation.

### Save and Load

- 6 persistent save slots displayed in a 3x2 grid
- Each slot shows an auto-captured screenshot thumbnail
- Quick save and quick load shortcuts

### Navigation

- Chapter and scene selection menu for jumping to any point in the story
- Pause menu with resume, save, load, settings, and return-to-main-menu options

### Settings

| Setting | Options |
|---------|---------|
| Volume | Independent master, music, and SFX sliders |
| Text speed | Adjustable typewriter speed |
| Auto-play delay | 1.0 / 2.0 / 3.0 / 5.0 seconds |
| Resolution | Multiple resolution presets |
| Fullscreen | Toggle |
| UI scale | Manual adjustment |
| Language | Select from available translations |

### Ending Screens

Dedicated screens for "game over" and "to be continued" endings, each supporting custom messages.

---

## Audio System

### Background Music

- Looping playback with automatic 2-second crossfade when transitioning between tracks
- Assigned per sequence
- Separate configurable music track for the main menu

### Sound Effects

- One-shot FX triggered on sequence entry
- Assigned per sequence

### Supported Formats

OGG, MP3, and WAV.

### Audio Import

A built-in import dialog organizes audio files into the correct asset directories (`assets/music/` and `assets/fx/`).

### Volume Control

Independent music and SFX volume sliders in the settings menu.

---

## Visual Effects

### Sequence Transitions

| Transition | Description |
|------------|-------------|
| Fade | Smooth opacity transition on sequence entry/exit |
| Pixelate | Pixelation effect on sequence entry/exit |

Both support configurable duration.

### Foreground Transitions

Fade animation for character appearance and disappearance, with configurable duration.

### FX System

| Effect | Parameters |
|--------|------------|
| Screen shake | Duration, intensity |
| Fade in | Duration |
| Blink (eyes) | Duration, intensity |
| Flash | Duration, intensity |
| Zoom in / Zoom out | Duration, intensity |
| Vignette | Duration, intensity |
| Desaturation | Duration, intensity |
| Pan (right, left, up, down) | Duration, intensity |

### Blink Animation

Automatic eyelid blink animation for character foregrounds:

- Approximately 5-second interval with plus or minus 1 second of randomization
- Per-character desynchronization so characters do not blink in unison
- YAML manifest system for defining blink assets per character

---

## Internationalization (i18n)

Frame Novel Studio supports multi-language stories through YAML translation files.

### Translated Fields

- Story metadata: title, author, description
- Chapter, scene, and sequence names
- Dialogue text and character names
- Choice text
- Notification messages

### Language Detection

- Automatic detection based on system locale
- Manual override available in settings
- Fallback to source language when a translation is missing

---

## Export and Distribution

### Target Platforms

| Platform | Output Format |
|----------|--------------|
| **Windows** | Standalone `.exe` with embedded PCK |
| **macOS** | `.app` bundle compressed as `.zip` |
| **Web / HTML5** | Progressive Web App with offline support and PWA install prompts for mobile |

### Quality Settings

| Quality | Description |
|---------|-------------|
| HD | Original resolution assets |
| SD | 2x downscaled assets |
| Ultra SD | 4x downscaled assets |

### Export Options

- **Partial export** -- Select a subset of chapters to include
- **Single language export** -- Export with only one language to reduce file size
- **Unused asset cleanup** -- Automatically remove orphaned assets before packaging
- **PCK chapter system** -- Per-chapter asset bundling for optimized web delivery

---

## Plugin System

Frame Novel Studio uses an extensible plugin architecture that lets you add features to both the editor and the game player. This is a core design principle: the engine provides the foundation, and plugins add domain-specific functionality on top.

### Two Plugin Types

- **Editor plugins** (`VBPlugin`) -- Add UI panels, menus, toolbar buttons, sequence editor tabs, and background services to the editor
- **Game plugins** (`VBGamePlugin`) -- Hook into the story lifecycle (chapter/scene/sequence events, dialogue and choice pipelines, save/load) and contribute toolbar buttons, overlay panels, and options controls to the player

Both types are discovered automatically from the `plugins/` directory. Plugin settings are stored per-story in `story.yaml`, making each story's plugin configuration portable.

### Bundled Plugins

| Plugin | Type | Description |
|--------|------|-------------|
| **Launcher** | Game | Splash screens for studio logo, engine logo, and disclaimer |
| **PlayFab Analytics** | Game | Cloud analytics and session telemetry |
| **Premium Code** | Game | Chapter access control via unlock codes |
| **Censure** | Game | Content filtering |
| **Walkthrough** | Game | In-game hints system with choice color-coding |

Additional community and first-party plugins (AI image generation, voice synthesis, etc.) are available as separate repositories and can be installed by cloning them into the `plugins/` directory.

### Writing Your Own Plugins

See the [Plugin Development Guide](plugin-development.md) for a complete reference on creating editor and game plugins, including the full API, contribution types, and step-by-step examples.

---

## Accessibility

- **DPI-aware UI scaling** -- Automatic detection with manual adjustment
- **Keyboard navigation** -- Full keyboard support during gameplay
- **Input flexibility** -- Both mouse and keyboard selection for choices
- **Dialogue box opacity** -- Adjustable from 0.0 to 1.0 for readability over backgrounds
- **Configurable text size** -- Adjust dialogue text for comfortable reading
- **Resolution adaptation** -- Multiple resolutions with aspect ratio preservation
