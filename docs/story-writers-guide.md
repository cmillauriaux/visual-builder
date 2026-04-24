# Frame Novel Studio -- Story Writer's Guide

This guide covers everything you need to create interactive visual novel stories with **Frame Novel Studio**. Whether you prefer the visual editor or hand-editing YAML files, you will find detailed instructions and reference material here.

---

## Table of Contents

### Introduction
- [What is a Story?](#what-is-a-story)
- [Who This Guide Is For](#who-this-guide-is-for)
- [Two Ways to Create Stories](#two-ways-to-create-stories)

### Part 1: Using the Editor
1. [Creating a New Story](#creating-a-new-story)
2. [Story Hierarchy](#story-hierarchy)
3. [Working with Graph Editors](#working-with-graph-editors)
4. [Editing Sequences](#editing-sequences)
5. [Setting Up Choices and Branching](#setting-up-choices-and-branching)
6. [Using Variables and Conditions](#using-variables-and-conditions)
7. [Adding Music and Sound Effects](#adding-music-and-sound-effects)
8. [Configuring Transitions and Effects](#configuring-transitions-and-effects)
9. [Multi-Language Support](#multi-language-support)
10. [Story Verification](#story-verification)
11. [Plugin Configuration](#plugin-configuration)

### Part 2: YAML Format Reference
12. [File Organization](#file-organization)
13. [General Structure](#general-structure)
14. [story.yaml -- Main Story File](#storyyaml----main-story-file)
15. [Chapters](#chapters)
16. [Scenes](#scenes)
17. [Sequences](#sequences)
18. [Dialogues](#dialogues)
19. [Foregrounds](#foregrounds)
20. [Visual Effects (FX)](#visual-effects-fx)
21. [Sequence Endings](#sequence-endings)
22. [Choices](#choices)
23. [Consequences](#consequences)
24. [Variables](#variables)
25. [Variable Effects](#variable-effects)
26. [Notifications](#notifications)
27. [Conditions](#conditions)
28. [Connections](#connections)
29. [Internationalization (i18n)](#internationalization-i18n)
30. [Complete Example](#complete-example)
31. [Practical Tips](#practical-tips)

### Part 3: Releasing Your Story
32. [Exporting from the Editor](#exporting-from-the-editor)
33. [Windows Export](#windows-export)
34. [macOS Export](#macos-export)
35. [Web / HTML5 Export](#web--html5-export)
36. [Testing Your Export](#testing-your-export)

---

# Introduction

## What is a Story?

A story in Frame Novel Studio is a self-contained interactive narrative. It combines background images, character art, dialogue, branching choices, variables, music, sound effects, and visual transitions into a complete visual novel experience. Stories are stored as a collection of YAML files and image assets in a structured directory, making them easy to version-control, share, and collaborate on.

## Who This Guide Is For

This guide is written for **story writers** -- people who want to create interactive narratives without writing code. Frame Novel Studio handles all the technical details of rendering, saving, exporting, and packaging. You focus on the story.

Whether you are a novelist exploring interactive fiction, a game designer prototyping branching narratives, or a hobbyist creating a visual novel for fun, this guide will walk you through every feature available to you.

## Two Ways to Create Stories

Frame Novel Studio offers two equally valid approaches to story creation:

1. **The visual editor** (recommended) -- A graphical interface where you arrange story elements on node graphs, compose scenes visually, write dialogue in text fields, and preview your story in real time. This is the fastest and most intuitive way to work.

2. **Hand-editing YAML files** -- Every story is stored as plain YAML files on disk. If you prefer working in a text editor, or if you want to automate parts of your workflow with scripts, you can create and edit these files directly. The YAML format is documented in full in Part 2 of this guide.

Both approaches produce identical results. You can freely switch between them: create a story in the editor, then fine-tune the YAML by hand, or write YAML from scratch and open it in the editor for visual adjustments.

---

# Part 1: Using the Editor

## Creating a New Story

To create a new story:

1. Open Frame Novel Studio.
2. Select **File > New Story** from the menu bar.
3. Choose an empty directory where the story files will be created.
4. Frame Novel Studio generates the default story structure: a `story.yaml` file, an `assets/` directory for images and audio, a `chapters/` directory with one starter chapter and scene, and an `i18n/` directory for translations.

You can also open an existing story by selecting **File > Open Story** and navigating to the directory containing the `story.yaml` file.

## Story Hierarchy

Stories in Frame Novel Studio follow a four-level hierarchy:

```
Story
  └── Chapters
        └── Scenes
              └── Sequences (dialogues + choices)
```

- A **Story** is the top-level container. It holds metadata (title, author, description), global variables, notifications, and one or more chapters.
- A **Chapter** represents a major story arc. Each chapter contains one or more scenes.
- A **Scene** is a narrative segment within a chapter. Scenes contain one or more sequences and optionally condition nodes for automatic branching.
- A **Sequence** is the atomic unit of storytelling. It combines a background image, foreground layers (characters and objects), a series of dialogue lines, and an ending (player choices or automatic redirection to the next sequence).

Each level has its own graph editor for visual navigation. You drill down by double-clicking nodes and navigate back up using the breadcrumb bar.

## Working with Graph Editors

The editor uses node-based graphs at every level of the story hierarchy. Here is how to work with them:

**Adding nodes** -- Right-click on the graph canvas to open the context menu. Select the type of node you want to add (chapter, scene, sequence, or condition). The new node appears at the click location.

**Creating connections** -- Drag from an output port on one node to an input port on another node to create a connection. Connections indicate the flow of the narrative and are reflected in the underlying YAML as `connections` entries.

**Navigating into a node** -- Double-click a node to open its contents. For example, double-clicking a chapter node opens the scene graph for that chapter; double-clicking a scene node opens the sequence graph.

**Breadcrumb bar** -- The bar at the top of the editor shows your current location in the hierarchy (e.g., Story > Chapter 1 > Scene 1 > Sequence: Introduction). Click any segment to jump back to that level.

**Story map** -- Click the map view button in the toolbar to see a full hierarchical overview of every chapter, scene, and sequence in a single zoomable, pannable view. This is useful for reviewing the structure of a large story at a glance.

**Zoom and pan** -- Use the scroll wheel to zoom in and out. Click and drag on empty space to pan the view.

## Editing Sequences

The sequence editor is the primary workspace where you compose individual story beats. It is divided into three zones:

**Main canvas** (left, approximately 65% of the width) -- Displays the background image with foreground layers positioned on top. Click on foreground elements to select them. Drag to reposition. A configurable grid overlay with snap-to-grid support helps with precise placement.

**Right panel** (approximately 35% of the width) -- Contains multiple tabs and sections:
- **Dialogue editing** -- Edit the character name and dialogue text for the currently selected dialogue.
- **Layer panel** -- View and manage all foreground layers in the current dialogue. Supports drag-and-drop reordering for z-order, per-layer visibility toggles, and selection highlighting.
- **Foreground properties** -- When a foreground is selected, adjust its position (anchor-based), scale, opacity, flip, and transition settings.
- **Ending editor** -- Configure how the sequence ends (choices or auto-redirect).
- **Audio tab** -- Set background music and sound effects.
- **FX tab** -- Add visual effects (screen shake, fade in, eyes blink).
- **Transition panel** -- Set entry and exit transition effects for the sequence.

**Bottom timeline** (approximately 120 pixels high) -- A horizontal scrollable strip showing thumbnail cards for every dialogue in the current sequence. Each thumbnail displays a mini-preview of the scene composition, the character name, a text excerpt, and a badge showing the number of foreground layers. Click a thumbnail to select that dialogue. Drag thumbnails to reorder dialogues within the sequence.

### Foreground Inheritance

Foregrounds follow an inheritance model: each dialogue inherits the foreground setup from the previous dialogue in the sequence (or from the sequence-level foregrounds for the first dialogue). Inherited foregrounds are indicated by an orange dotted border in the layer panel.

You can override any inherited foreground on a per-dialogue basis -- for example, to change a character's expression or position for a specific line of dialogue -- without affecting the parent. This keeps your workflow efficient: set up the scene once, then only specify what changes.

## Setting Up Choices and Branching

At the end of every sequence, you must define what happens next. Open the **Ending Editor** tab in the right panel to configure this.

### Choices Mode

Select "Choices" to present the player with selectable options. You can define between 1 and 8 choices per sequence.

For each choice, you configure:
- **Text** -- The label displayed on the choice button.
- **Consequence** -- Where selecting this choice leads (see consequence types below).
- **Variable effects** (optional) -- Variables to modify when the player selects this choice.
- **Nature** (optional) -- A visual hint about the choice tone (positive, balanced, negative).

### Auto-Redirect Mode

Select "Auto-redirect" to have the sequence automatically proceed to the next destination without presenting any choices to the player. You configure a single consequence for where to go.

### Consequence Types

Both choices and auto-redirects use the same consequence system:

| Consequence | Description |
|-------------|-------------|
| Go to sequence | Navigate to another sequence within the same scene |
| Go to scene | Navigate to a scene (within the same chapter or another) |
| Go to chapter | Navigate to a different chapter |
| Go to condition | Evaluate a condition node for automatic branching |
| Game over | End the game and display the game over screen |
| To be continued | Display a "to be continued" screen (temporary ending) |

## Using Variables and Conditions

### Variables

Variables track player state across the story -- things like scores, collected items, relationship levels, or flags for past decisions.

To manage variables:
1. Open the **Variables** panel from the editor toolbar.
2. Click "Add Variable" to create a new variable.
3. Give it a name and an initial value. All values are stored as strings (write `"0"` not `0`, `"true"` not `true`).

Variables can optionally be displayed to the player during gameplay. Configure display settings (show on main screen, show in details panel, icon image, description) in the variable properties.

### Variable Effects

Attach variable effects to choices to modify variables when the player makes a selection. Four operations are available:

| Operation | Description |
|-----------|-------------|
| Set | Assign a specific value to the variable |
| Increment | Add a numeric value to the variable |
| Decrement | Subtract a numeric value from the variable |
| Delete | Remove the variable entirely |

You can attach multiple effects to a single choice.

### Condition Nodes

Condition nodes provide automatic branching based on variable values. They appear as special nodes in the scene graph alongside sequences.

To add a condition:
1. Right-click in the scene graph and select "Add Condition."
2. Open the condition editor to define rules.
3. Each rule checks a variable against a value using an operator (equal, not equal, greater than, etc.).
4. Rules are evaluated in order -- the first matching rule determines where the story goes.
5. A default fallback handles the case where no rules match.

To use a condition, set a choice or auto-redirect consequence to "Go to condition" and select the condition node as the target.

## Adding Music and Sound Effects

Use the **Audio** tab in the sequence right panel to add audio to your story.

**Background music** -- Select a music track for the sequence. Music loops continuously and crossfades automatically (over 2 seconds) when transitioning between sequences with different tracks. If you want to stop music playback at a particular sequence, enable the "Stop music" option.

**Sound effects** -- Select a sound effect to play once when the player enters the sequence. Sound effects do not loop.

**Supported formats** -- OGG, MP3, and WAV files are supported.

**Importing audio** -- Use the built-in audio import dialog to organize files into your story's `assets/music/` and `assets/audio_fx/` directories.

**Menu music** -- You can also set a music track for the main menu screen in the story settings.

## Configuring Transitions and Effects

### Sequence Transitions

Set entry and exit transition effects for each sequence in the **Transition** panel:

| Transition | Description |
|------------|-------------|
| None | Instant change, no animation |
| Fade | Smooth fade to/from black |
| Pixelate | Progressive pixelation effect |

Both fade and pixelate support configurable duration (in seconds).

### Foreground Transitions

Each foreground layer can have its own transition effect for when it appears or disappears:

| Transition | Description |
|------------|-------------|
| None | Instant appearance, faded disappearance |
| Fade | Smooth fade in and fade out |

The transition duration is configurable between 0.1 and 5.0 seconds.

### Visual Effects (FX)

Add visual effects to a sequence from the **FX** tab. Available effects:

| Effect | Description |
|--------|-------------|
| Screen shake | Shakes the screen (for explosions, earthquakes, dramatic moments) |
| Fade in | Fades the scene in from a color |
| Eyes blink | Simulates an eye-blink effect |
| Flash | Brief screen flash |
| Zoom | Zoom in or out with configurable start and end values |
| Vignette | Dark vignette overlay |
| Desaturation | Removes color from the scene |
| Pan (up/down/left/right) | Camera pan in specified direction |

Each effect has configurable duration (0.1 to 5.0 seconds) and intensity (0.1 to 3.0).

## Multi-Language Support

Frame Novel Studio supports exporting stories in multiple languages.

**Translation files** are stored in the `i18n/` folder within your story directory as YAML key-value pairs. Each language gets its own file (e.g., `en.yaml`, `fr.yaml`, `es.yaml`).

**Setting up languages:**
1. Open the language manager from the story settings.
2. Add the language codes you want to support.
3. Set the default (source) language.

**What gets translated:**
- Story title, author name, description
- Menu title and subtitle
- Chapter, scene, and sequence names and subtitles
- Dialogue text and character names
- Choice text
- Notification messages

**Automatic language detection** -- The player detects the system language at startup and selects the best matching translation. Players can also manually select a language from the settings menu.

**Fallback behavior** -- If a translation is missing or empty for a given string, the source language text is used instead.

**Voice files** -- Voice audio files can be generated and stored per language, allowing full spoken dialogue localization.

## Story Verification

Before exporting your story, use the built-in **Story Verifier** to check for structural problems. Access it from the toolbar.

The verifier detects:
- **Dead-end sequences** -- Sequences with no outgoing connection or ending definition.
- **Undefined variables** -- Variables referenced in conditions or effects that are not declared in the story.
- **Missing assets** -- Background or foreground images referenced in YAML that do not exist on disk.
- **Orphaned conditions** -- Condition nodes that are not referenced by any choice or auto-redirect.

Fix all reported issues before exporting to ensure a smooth player experience.

## Plugin Configuration

Frame Novel Studio supports an extensible plugin system. Plugins add functionality to either the editor, the game player, or both. Plugin settings are configured per-story from the **Settings** menu.

### Available Plugins

**Launcher** (Game plugin) -- Adds splash screens before the main menu: studio logo, engine logo, and a customizable disclaimer screen.

**PlayFab Analytics** (Game plugin) -- Cloud analytics and session telemetry via Microsoft PlayFab.

**Censure** (Game plugin) -- Content filtering for age-appropriate distribution.

**Walkthrough** (Game plugin) -- In-game hints system to help players navigate branching paths.

Additional community and first-party plugins (such as AI image generation or voice synthesis) are available as separate repositories. Install them by cloning into the `plugins/` directory.

---

# Part 2: YAML Format Reference

This section documents every YAML structure used by Frame Novel Studio. You can create and edit stories entirely by hand using a text editor, or use this as a reference to understand files generated by the visual editor.

## File Organization

A story is a directory with the following structure:

```
my_story/
├── story.yaml                    # Main story file
├── assets/
│   ├── backgrounds/              # Background images
│   ├── foregrounds/              # Character/object images
│   ├── music/                    # Background music (OGG, MP3, WAV)
│   ├── audio_fx/                 # Sound effects (OGG, MP3, WAV)
│   └── voices/                   # Voice files (per language)
├── chapters/
│   └── ch-001/
│       ├── chapter.yaml          # Chapter definition
│       └── scenes/
│           ├── scene-001.yaml    # Scene definition
│           └── scene-002.yaml
└── i18n/                         # Translations (optional)
    ├── languages.yaml            # Language configuration
    ├── en.yaml                   # Source text
    └── fr.yaml                   # French translation
```

Images (backgrounds and foregrounds) go in the `assets/` directory. YAML files describe the narrative structure. The `i18n/` directory is optional and enables multi-language support (see [Internationalization](#internationalization-i18n)).

---

## General Structure

The story is organized as a four-level hierarchy:

```
Story (story.yaml)
  └── Chapters (chapters/{uuid}/chapter.yaml)
        └── Scenes (chapters/{uuid}/scenes/{uuid}.yaml)
              └── Sequences (dialogues + choices)
```

- A **story** contains one or more **chapters**.
- A **chapter** contains one or more **scenes**.
- A **scene** contains one or more **sequences**.
- A **sequence** contains **dialogues** and ends with **choices** or an automatic redirect.

Each element is identified by a `uuid` -- a unique string of your choosing. You do not need to use actual UUIDs; short readable identifiers work perfectly well (e.g., `"ch-001"`, `"scene-intro"`, `"seq-final-battle"`).

---

## story.yaml -- Main Story File

This is the entry point for your story.

```yaml
title: "The Cursed Forest"
author: "Jane Smith"
description: "An interactive adventure in a mysterious forest."
version: "1.0.0"
created_at: "2026-01-15T10:00:00Z"
updated_at: "2026-02-27T14:30:00Z"
entry_point: "ch-001"
menu_title: "The Cursed Forest"
menu_subtitle: "An interactive adventure"
menu_background: "menu_bg.png"
menu_music: "main_theme.ogg"
chapters:
  - uuid: "ch-001"
    name: "Chapter 1 -- Into the Forest"
    subtitle: "Where it all begins"
    position: { x: 0, y: 0 }
    entry_point: "scene-001"
  - uuid: "ch-002"
    name: "Chapter 2 -- The Heart of Darkness"
    position: { x: 400, y: 0 }
    entry_point: "scene-010"
variables:
  - name: "score"
    initial_value: "0"
  - name: "has_key"
    initial_value: "false"
notifications:
  - pattern: "score"
    message: "Your score has changed!"
  - pattern: "*_affinity"
    message: "A relationship has evolved..."
connections:
  - from: "ch-001"
    to: "ch-002"
```

| Field | Required | Description |
|-------|:--------:|-------------|
| `title` | yes | Story title |
| `author` | yes | Author name |
| `description` | no | Story summary |
| `version` | no | Version number (default: `"1.0.0"`) |
| `created_at` | no | Creation date (ISO 8601 format) |
| `updated_at` | no | Last modification date (ISO 8601 format) |
| `entry_point` | yes | UUID of the starting chapter |
| `menu_title` | no | Title displayed on the game menu screen |
| `menu_subtitle` | no | Subtitle displayed on the game menu screen |
| `menu_background` | no | Menu background image filename (in `assets/backgrounds/`) |
| `menu_music` | no | Background music for the main menu (in `assets/music/`) |
| `chapters` | yes | List of chapter headers (see below) |
| `variables` | no | Global story variables |
| `notifications` | no | Notifications triggered by variable changes |
| `connections` | no | Links between chapters (for the graph editor) |
| `game_over_title` | no | Title text for the game over screen |
| `game_over_subtitle` | no | Subtitle text for the game over screen |
| `game_over_background` | no | Background image for the game over screen |
| `to_be_continued_title` | no | Title text for the "to be continued" screen |
| `to_be_continued_subtitle` | no | Subtitle text for the "to be continued" screen |
| `to_be_continued_background` | no | Background image for the "to be continued" screen |
| `app_icon` | no | Application icon image (in `assets/icons/`) |
| `plugin_settings` | no | Per-plugin configuration (see [Plugin Configuration](#plugin-configuration)) |

Each entry in the `chapters` list is a header containing the chapter's `uuid`, `name`, `subtitle`, `position`, and `entry_point`. The full chapter definition lives in its own file (see [Chapters](#chapters)).

---

## Chapters

Each chapter has its own file at `chapters/{uuid}/chapter.yaml`.

```yaml
uuid: "ch-001"
name: "Chapter 1 -- Into the Forest"
subtitle: "Where it all begins"
position: { x: 0, y: 0 }
entry_point: "scene-001"
scenes:
  - uuid: "scene-001"
    name: "Arrival"
    subtitle: "First steps into the forest"
    position: { x: 0, y: 0 }
    entry_point: "seq-001"
  - uuid: "scene-002"
    name: "The Clearing"
    position: { x: 300, y: 0 }
    entry_point: "seq-010"
connections:
  - from: "scene-001"
    to: "scene-002"
```

| Field | Required | Description |
|-------|:--------:|-------------|
| `uuid` | yes | Unique chapter identifier |
| `name` | yes | Display name of the chapter |
| `subtitle` | no | Subtitle |
| `position` | no | Position in the graph editor (for visual layout) |
| `entry_point` | yes | UUID of the first scene in this chapter |
| `scenes` | yes | List of scene headers |
| `connections` | no | Links between scenes (for the graph editor) |

---

## Scenes

Each scene is a file at `chapters/{chapter_uuid}/scenes/{scene_uuid}.yaml`.

Scenes are where sequences (the actual narrative content) and condition nodes live.

```yaml
uuid: "scene-001"
name: "Arrival"
subtitle: "First steps into the forest"
position: { x: 0, y: 0 }
entry_point: "seq-001"
sequences:
  - uuid: "seq-001"
    name: "Discovery"
    # ... (see Sequences section)
  - uuid: "seq-002"
    name: "Exploration"
    # ...
conditions: []
connections:
  - from: "seq-001"
    to: "seq-002"
```

| Field | Required | Description |
|-------|:--------:|-------------|
| `uuid` | yes | Unique scene identifier |
| `name` | yes | Display name |
| `subtitle` | no | Subtitle |
| `position` | no | Position in the graph editor |
| `entry_point` | yes | UUID of the first sequence |
| `sequences` | yes | List of sequences |
| `conditions` | no | Condition nodes for automatic branching (see [Conditions](#conditions)) |
| `connections` | no | Links between sequences and/or conditions |

---

## Sequences

A sequence is the fundamental unit of narration. It combines a backdrop (background image), characters and objects (foregrounds), dialogue lines, optional visual effects, audio, and an ending (choices or redirect).

```yaml
uuid: "seq-001"
name: "Discovery"
title: "Chapter 1"
subtitle: "Into the forest"
position: { x: 0, y: 0 }
background: "forest.png"
background_color: "1a3d2aff"
music: "forest_ambiance.ogg"
audio_fx: "door_creak.ogg"
stop_music: false
transition_in_type: "fade"
transition_in_duration: 0.8
transition_out_type: "none"
transition_out_duration: 0.5
foregrounds:
  - uuid: "fg-hero"
    name: "Hero"
    image: "hero.png"
    z_order: 1
    opacity: 1.0
    flip_h: false
    flip_v: false
    scale: 1.0
    anchor_bg: { x: 0.5, y: 0.5 }
    anchor_fg: { x: 0.5, y: 1.0 }
    transition_type: "fade"
    transition_duration: 0.5
dialogues:
  - uuid: "dlg-001"
    character: "Narrator"
    text: "You step into a dark and silent forest."
    foregrounds: []
  - uuid: "dlg-002"
    character: "Hero"
    text: "It's cold in here..."
    foregrounds: []
fx:
  - uuid: "fx-001"
    fx_type: "screen_shake"
    duration: 1.0
    intensity: 0.5
ending:
  type: "choices"
  choices:
    - text: "Advance carefully"
      consequence:
        type: "redirect_sequence"
        target: "seq-002"
        effects: []
      effects: []
      conditions: {}
    - text: "Turn back"
      consequence:
        type: "game_over"
        effects: []
      effects: []
      conditions: {}
```

| Field | Required | Default | Description |
|-------|:--------:|:-------:|-------------|
| `uuid` | yes | -- | Unique identifier |
| `name` | yes | -- | Sequence name |
| `title` | no | `""` | Title displayed to the player (e.g., a chapter title overlay) |
| `subtitle` | no | `""` | Subtitle displayed to the player |
| `position` | no | `{x: 0, y: 0}` | Position in the graph editor |
| `background` | no | `""` | Background image filename (in `assets/backgrounds/`) |
| `background_color` | no | `"00000000"` | Background color in hexadecimal RGBA (8 characters). Transparent by default |
| `foregrounds` | no | `[]` | Default foreground layers (characters/objects) |
| `dialogues` | yes | -- | List of dialogue lines |
| `fx` | no | `[]` | Visual effects applied to the sequence |
| `music` | no | `""` | Background music filename (in `assets/music/`) |
| `audio_fx` | no | `""` | Sound effect filename (in `assets/audio_fx/`) |
| `stop_music` | no | `false` | If `true`, stops any currently playing music |
| `transition_in_type` | no | `"none"` | Entry transition: `"none"`, `"fade"`, or `"pixelate"` |
| `transition_in_duration` | no | `0.5` | Entry transition duration in seconds |
| `transition_out_type` | no | `"none"` | Exit transition: `"none"`, `"fade"`, or `"pixelate"` |
| `transition_out_duration` | no | `0.5` | Exit transition duration in seconds |
| `ending` | yes | -- | How the sequence ends (choices or auto-redirect) |

### Sequence Transition Types

| Type | Description |
|------|-------------|
| `"none"` | Instant change, no animation |
| `"fade"` | Fade to/from black |
| `"pixelate"` | Progressive pixelation effect |

---

## Dialogues

Dialogues are displayed to the player one at a time, in order. Each dialogue represents a single line spoken by a character (or by the narrator).

```yaml
dialogues:
  - uuid: "dlg-001"
    character: "Narrator"
    text: "The wind blows through the trees."
    foregrounds: []
  - uuid: "dlg-002"
    character: "Hero"
    text: "I need to find shelter before nightfall."
    foregrounds:
      - uuid: "fg-rain"
        name: "Rain"
        image: "rain.png"
        z_order: 10
        opacity: 0.6
        flip_h: false
        flip_v: false
        scale: 1.0
        anchor_bg: { x: 0.5, y: 0.5 }
        anchor_fg: { x: 0.5, y: 0.5 }
        transition_type: "fade"
        transition_duration: 1.0
```

| Field | Required | Description |
|-------|:--------:|-------------|
| `uuid` | yes | Unique identifier |
| `character` | yes | Name of the speaking character |
| `text` | yes | Dialogue text |
| `foregrounds` | no | Per-dialogue foreground overrides (see below) |

### Per-Dialogue Foreground Overrides

Each dialogue can specify its own foreground layers in the `foregrounds` array. When present, these override the foregrounds inherited from the previous dialogue (or from the sequence defaults for the first dialogue).

This is how you change character expressions, add or remove objects, or reposition elements between dialogue lines without creating separate sequences.

If the `foregrounds` array is empty (`[]`), the dialogue inherits the foreground setup from the preceding dialogue. If it is omitted entirely, inheritance also applies.

---

## Foregrounds

Foregrounds are images layered on top of the background -- characters, objects, visual decorations. They can be defined at the sequence level (default display) or at the dialogue level (per-line overrides).

```yaml
foregrounds:
  - uuid: "fg-hero"
    name: "Hero"
    image: "hero.png"
    z_order: 1
    opacity: 1.0
    flip_h: false
    flip_v: false
    scale: 1.0
    anchor_bg: { x: 0.3, y: 0.8 }
    anchor_fg: { x: 0.5, y: 1.0 }
    transition_type: "fade"
    transition_duration: 0.5
```

| Field | Required | Default | Description |
|-------|:--------:|:-------:|-------------|
| `uuid` | yes | -- | Unique identifier |
| `name` | yes | -- | Display name of the element |
| `image` | yes | -- | Image filename (in `assets/foregrounds/`) |
| `z_order` | no | `0` | Drawing depth order (higher values = drawn in front) |
| `opacity` | no | `1.0` | Opacity from 0.0 (invisible) to 1.0 (fully opaque) |
| `flip_h` | no | `false` | Flip the image horizontally |
| `flip_v` | no | `false` | Flip the image vertically |
| `scale` | no | `1.0` | Scale factor |
| `anchor_bg` | no | `{x: 0.5, y: 0.5}` | Anchor point on the background (0.0 to 1.0) |
| `anchor_fg` | no | `{x: 0.5, y: 1.0}` | Anchor point on the foreground image (0.0 to 1.0) |
| `transition_type` | no | `"none"` | Transition type: `"none"` or `"fade"` |
| `transition_duration` | no | `0.5` | Transition duration in seconds (0.1 to 5.0) |

### The Dual-Anchor Positioning System

Foreground placement uses two anchor points working together:

- **`anchor_bg`** (background anchor) -- Determines *where on the background* the foreground is placed. Coordinates range from `{x: 0.0, y: 0.0}` (top-left corner) to `{x: 1.0, y: 1.0}` (bottom-right corner). The value `{x: 0.5, y: 0.5}` means the center of the background.

- **`anchor_fg`** (foreground anchor) -- Determines *which point of the foreground image* is aligned to the background anchor position. The value `{x: 0.5, y: 1.0}` means the bottom-center of the image, which is the natural choice for standing characters (their feet are placed at the anchor position).

**Example:** To place a character at the center-bottom of the screen with their feet on the ground:

```yaml
anchor_bg: { x: 0.5, y: 0.9 }   # Background position: center, near the bottom
anchor_fg: { x: 0.5, y: 1.0 }   # Foreground anchor: bottom-center (the feet)
```

**Example:** To place a character on the left side:

```yaml
anchor_bg: { x: 0.2, y: 0.85 }  # Background position: left side, near bottom
anchor_fg: { x: 0.5, y: 1.0 }   # Foreground anchor: bottom-center
```

### Foreground Transition Types

| Type | Description |
|------|-------------|
| `"none"` | Instant appearance; faded disappearance |
| `"fade"` | Smooth fade on both appearance and disappearance |

---

## Visual Effects (FX)

Visual effects add animations to a sequence -- screen shaking, fading, camera movements. They are defined in the `fx` array of a sequence.

```yaml
fx:
  - uuid: "fx-001"
    fx_type: "screen_shake"
    duration: 1.0
    intensity: 0.8
  - uuid: "fx-002"
    fx_type: "fade_in"
    duration: 0.5
    intensity: 1.0
```

| Field | Required | Default | Description |
|-------|:--------:|:-------:|-------------|
| `uuid` | yes | -- | Unique identifier |
| `fx_type` | yes | `"fade_in"` | Effect type (see table below) |
| `duration` | no | `0.5` | Effect duration in seconds (0.1 to 5.0) |
| `intensity` | no | `1.0` | Effect intensity (0.1 to 3.0) |
| `color` | no | `"ffffffff"` | Color for color-based effects (hex RGBA) |
| `zoom_from` | no | `1.0` | Starting zoom level (for zoom effects, minimum 1.0) |
| `zoom_to` | no | `1.5` | Ending zoom level (for zoom effects, minimum 1.0) |
| `continue_during_fx` | no | `false` | If `true`, player can advance dialogue during the effect |

### Available Effect Types

| Type | Description |
|------|-------------|
| `"screen_shake"` | Screen tremor (explosions, earthquakes, dramatic moments) |
| `"fade_in"` | Fade in from a color |
| `"eyes_blink"` | Eye blink effect |
| `"flash"` | Brief screen flash |
| `"zoom"` | Zoom with configurable start and end values |
| `"zoom_in"` | Preset zoom in |
| `"zoom_out"` | Preset zoom out |
| `"vignette"` | Dark vignette overlay |
| `"desaturation"` | Desaturate the scene (grayscale) |
| `"pan_right"` | Camera pan to the right |
| `"pan_left"` | Camera pan to the left |
| `"pan_down"` | Camera pan downward |
| `"pan_up"` | Camera pan upward |

---

## Sequence Endings

Every sequence must define how it ends. There are two types:

### 1. Choices

The player selects from a list of options:

```yaml
ending:
  type: "choices"
  choices:
    - text: "Explore the cave"
      consequence:
        type: "redirect_sequence"
        target: "seq-cave"
        effects: []
      effects:
        - variable: "courage"
          operation: "increment"
          value: "1"
      conditions: {}
    - text: "Run away"
      consequence:
        type: "redirect_sequence"
        target: "seq-flee"
        effects: []
      effects: []
      conditions: {}
```

### 2. Auto-Redirect

The sequence automatically proceeds to the next destination without player input:

```yaml
ending:
  type: "auto_redirect"
  consequence:
    type: "redirect_sequence"
    target: "seq-002"
    effects: []
```

---

## Choices

Each choice presented to the player has the following structure:

```yaml
text: "Text displayed on the button"
consequence:                        # What happens when this choice is selected
  type: "redirect_sequence"
  target: "seq-002"
  effects: []
effects:                            # Variables modified when this choice is selected
  - variable: "score"
    operation: "increment"
    value: "10"
conditions: {}                      # Display conditions (optional)
```

| Field | Required | Description |
|-------|:--------:|-------------|
| `text` | yes | Text displayed on the choice button |
| `consequence` | yes | Action triggered by selecting this choice |
| `effects` | no | Variable modifications applied when this choice is selected |
| `conditions` | no | Conditions that determine whether this choice is visible |
| `nature` | no | Visual hint for the choice tone: `"positive"`, `"balanced"`, or `"negative"` |

> **Limit:** A sequence can offer between **1 and 8 choices** maximum.

---

## Consequences

A consequence determines what happens after a choice is made or after an auto-redirect.

| Type | Description | `target` required? |
|------|-------------|:------------------:|
| `redirect_sequence` | Go to another sequence in the same scene | yes |
| `redirect_scene` | Go to another scene | yes |
| `redirect_chapter` | Go to another chapter | yes |
| `redirect_condition` | Evaluate a condition node | yes |
| `game_over` | End the game | no |
| `to_be_continued` | Temporary ending ("to be continued") | no |

### Examples

**Redirect to a sequence:**
```yaml
consequence:
  type: "redirect_sequence"
  target: "seq-002"
  effects: []
```

**Redirect to a scene:**
```yaml
consequence:
  type: "redirect_scene"
  target: "scene-005"
  effects: []
```

**Redirect to a chapter:**
```yaml
consequence:
  type: "redirect_chapter"
  target: "ch-002"
  effects: []
```

**Redirect to a condition node:**
```yaml
consequence:
  type: "redirect_condition"
  target: "cond-score"
  effects: []
```

**Game over:**
```yaml
consequence:
  type: "game_over"
  effects: []
```

**To be continued:**
```yaml
consequence:
  type: "to_be_continued"
  effects: []
```

Consequences can also include `effects` to modify variables at the moment of transition.

---

## Variables

Variables track game state: scores, collected items, past choices, relationship levels, and more. They are declared in `story.yaml` and their values are always stored as strings.

### Declaration

```yaml
# In story.yaml
variables:
  - name: "score"
    initial_value: "0"
  - name: "has_key"
    initial_value: "false"
  - name: "hero_name"
    initial_value: "Unknown"
```

| Field | Required | Description |
|-------|:--------:|-------------|
| `name` | yes | Variable name (unique identifier) |
| `initial_value` | yes | Starting value (always a string) |
| `description` | no | Description text shown to the player |
| `image` | no | Image displayed alongside the variable (in `assets/`) |
| `show_on_main` | no | If `true`, display this variable on the main game HUD |
| `show_on_details` | no | If `true`, display this variable in the details overlay |
| `visibility_mode` | no | `"always"` (default) or `"variable"` (show only when a condition is met) |
| `visibility_variable` | no | When `visibility_mode` is `"variable"`, the variable name that controls visibility |

### Usage

Variables are used in two contexts:

- **Effects** -- Modify a variable when a choice is selected or a consequence is triggered.
- **Conditions** -- Branch the story based on a variable's current value.

---

## Variable Effects

Effects modify variables. They can be placed in the `effects` array of a choice or a consequence.

```yaml
effects:
  - variable: "score"
    operation: "set"
    value: "100"
  - variable: "health"
    operation: "increment"
    value: "5"
  - variable: "health"
    operation: "decrement"
    value: "10"
  - variable: "temp_item"
    operation: "delete"
```

| Operation | Description | `value` required? |
|-----------|-------------|:-----------------:|
| `set` | Set the variable to a specific value | yes |
| `increment` | Add a numeric value to the variable | yes |
| `decrement` | Subtract a numeric value from the variable | yes |
| `delete` | Remove the variable entirely | no |

For `increment` and `decrement`, both the current variable value and the effect value must be valid numbers. If either is not numeric, the operation is silently skipped.

---

## Notifications

Notifications display a message to the player when a variable is modified. They are declared in `story.yaml` and use **glob patterns** to target one or more variable names.

```yaml
# In story.yaml
notifications:
  - pattern: "score"
    message: "Your score has changed!"
  - pattern: "*_affinity"
    message: "A relationship has evolved..."
  - pattern: "item_*"
    message: "Inventory updated."
```

| Field | Required | Description |
|-------|:--------:|-------------|
| `pattern` | yes | Glob pattern matching variable names |
| `message` | yes | Message displayed to the player (toast/notification style) |

### Glob Patterns

| Character | Meaning |
|-----------|---------|
| `*` | Matches any sequence of characters (including empty) |
| `?` | Matches exactly one character |

**Examples:**
- `"score"` -- Matches exactly the variable named `score`.
- `"*_affinity"` -- Matches `hero_affinity`, `enemy_affinity`, `npc_affinity`, etc.
- `"item_?"` -- Matches `item_a`, `item_b`, but not `item_ab`.

Notifications are evaluated whenever a variable is modified. If the pattern matches the name of the modified variable, the message is shown.

---

## Conditions

Conditions enable automatic branching based on variable values. They are defined at the scene level alongside sequences.

```yaml
conditions:
  - uuid: "cond-score"
    name: "Score Check"
    subtitle: ""
    position: { x: 200, y: 300 }
    rules:
      - variable: "score"
        operator: "greater_than"
        value: "100"
        consequence:
          type: "redirect_sequence"
          target: "seq-victory"
          effects: []
      - variable: "score"
        operator: "greater_than"
        value: "50"
        consequence:
          type: "redirect_sequence"
          target: "seq-middle"
          effects: []
    default_consequence:
      type: "redirect_sequence"
      target: "seq-defeat"
      effects: []
```

Rules are evaluated **in order**. The first rule that matches is applied. If no rule matches, the `default_consequence` is used as a fallback.

### Available Operators

| Operator | Description |
|----------|-------------|
| `equal` | Equal to the specified value |
| `not_equal` | Not equal to the specified value |
| `greater_than` | Greater than (numeric comparison) |
| `greater_than_equal` | Greater than or equal to (numeric comparison) |
| `less_than` | Less than (numeric comparison) |
| `less_than_equal` | Less than or equal to (numeric comparison) |
| `exists` | The variable exists (has been defined). The `value` field is ignored |
| `not_exists` | The variable does not exist. The `value` field is ignored |

For numeric operators (`greater_than`, `less_than`, etc.), both the variable's current value and the comparison value must be valid numbers. If either is not numeric, the rule does not match.

### Using Conditions

To direct the player to a condition node, use a `redirect_condition` consequence:

```yaml
ending:
  type: "auto_redirect"
  consequence:
    type: "redirect_condition"
    target: "cond-score"
    effects: []
```

Or from a choice:

```yaml
choices:
  - text: "Open the chest"
    consequence:
      type: "redirect_condition"
      target: "cond-has-key"
      effects: []
    effects: []
    conditions: {}
```

---

## Connections

Connections describe the links between elements at the same level. They are primarily used by the graph editor for visual layout but also serve as documentation of the story flow.

```yaml
connections:
  - from: "seq-001"
    to: "seq-002"
  - from: "seq-002"
    to: "cond-score"
  - from: "cond-score"
    to: "seq-victory"
  - from: "cond-score"
    to: "seq-defeat"
```

| Field | Required | Description |
|-------|:--------:|-------------|
| `from` | yes | UUID of the source node |
| `to` | yes | UUID of the destination node |

Connections appear at every level: between chapters in `story.yaml`, between scenes in `chapter.yaml`, and between sequences/conditions in scene files.

---

## Internationalization (i18n)

The internationalization system translates a story into multiple languages without modifying the original YAML files. The source text remains in the story files; translations are stored in separate files.

### File Structure

```
my_story/
└── i18n/
    ├── languages.yaml      # Language configuration
    ├── en.yaml             # Source text (English)
    └── fr.yaml             # French translation
```

### Language Configuration -- languages.yaml

```yaml
default: "en"
languages:
  - "en"
  - "fr"
  - "es"
```

| Field | Description |
|-------|-------------|
| `default` | Language code of the source language |
| `languages` | List of all available language codes |

If the `languages.yaml` file is absent, the system automatically detects available languages from the `*.yaml` files present in `i18n/`.

### Translation File Format

Each translation file is a simple key-value dictionary where the key is the source text and the value is the translation:

```yaml
# i18n/fr.yaml
"The Cursed Forest": "La Foret Maudite"
"Jane Smith": "Jane Smith"
"You step into a dark and silent forest.": "Vous penetrez dans une foret sombre et silencieuse."
"It's cold in here...": "Il fait froid ici..."
"Advance carefully": "Avancer prudemment"
"Turn back": "Faire demi-tour"
"Narrator": "Narrateur"
"Hero": "Heros"
```

The source language file (e.g., `en.yaml`) uses the format `"text": "text"` (key and value are identical) and serves as the reference.

### Translated Fields

The following fields are automatically translated when a language is selected:

| Model | Translated Fields |
|-------|-------------------|
| Story | `title`, `author`, `description`, `menu_title`, `menu_subtitle` |
| Chapter | `name`, `subtitle` |
| Scene | `name`, `subtitle` |
| Sequence | `name`, `subtitle` |
| Dialogue | `character`, `text` |
| Choice | `text` |
| Notification | `message` |

### Fallback Behavior

- If a translation is missing or empty, the source language text is preserved.
- Game interface strings (menus, buttons) can also be included in the translation files.

### Per-Language Voice Files

Voice audio files are stored and served per language, enabling full localization of spoken dialogue. Voice files are organized in the `assets/voices/` directory, with each dialogue's voice file stored per language:

```yaml
# In a dialogue definition
voice_files:
  en: "assets/voices/dlg-001_en.mp3"
  fr: "assets/voices/dlg-001_fr.mp3"
```

---

## Complete Example

Here is a complete mini-story with two sequences, a choice, a variable, and a condition.

### story.yaml

```yaml
title: "The Mysterious Chest"
author: "Jane Smith"
description: "Will you find the key to the chest?"
version: "1.0.0"
created_at: "2026-02-27T10:00:00Z"
updated_at: "2026-02-27T10:00:00Z"
entry_point: "ch-1"
menu_title: "The Mysterious Chest"
menu_subtitle: "A short adventure"
chapters:
  - uuid: "ch-1"
    name: "The Only Chapter"
    position: { x: 0, y: 0 }
    entry_point: "sc-1"
variables:
  - name: "has_key"
    initial_value: "false"
notifications:
  - pattern: "has_key"
    message: "You found an item!"
connections: []
```

### chapters/ch-1/chapter.yaml

```yaml
uuid: "ch-1"
name: "The Only Chapter"
position: { x: 0, y: 0 }
entry_point: "sc-1"
scenes:
  - uuid: "sc-1"
    name: "The Chest Room"
    position: { x: 0, y: 0 }
    entry_point: "seq-entrance"
connections: []
```

### chapters/ch-1/scenes/sc-1.yaml

```yaml
uuid: "sc-1"
name: "The Chest Room"
position: { x: 0, y: 0 }
entry_point: "seq-entrance"
sequences:
  - uuid: "seq-entrance"
    name: "Entrance"
    position: { x: 0, y: 0 }
    background: "room.png"
    background_color: "2b1d0eff"
    transition_in_type: "fade"
    transition_in_duration: 1.0
    foregrounds: []
    dialogues:
      - uuid: "dlg-1"
        character: "Narrator"
        text: "You enter a dusty room. A massive chest sits in the center."
        foregrounds: []
      - uuid: "dlg-2"
        character: "Narrator"
        text: "To the left, a small table with a drawer. To the right, the locked chest."
        foregrounds: []
    ending:
      type: "choices"
      choices:
        - text: "Search the drawer"
          consequence:
            type: "redirect_sequence"
            target: "seq-drawer"
            effects: []
          effects: []
          conditions: {}
        - text: "Try to open the chest"
          consequence:
            type: "redirect_condition"
            target: "cond-key"
            effects: []
          effects: []
          conditions: {}

  - uuid: "seq-drawer"
    name: "The Drawer"
    position: { x: 300, y: 0 }
    background: "room.png"
    foregrounds: []
    fx:
      - uuid: "fx-key"
        fx_type: "screen_shake"
        duration: 0.3
        intensity: 0.4
    dialogues:
      - uuid: "dlg-3"
        character: "Narrator"
        text: "You open the drawer and find a rusty old key!"
        foregrounds:
          - uuid: "fg-key"
            name: "Key"
            image: "key.png"
            z_order: 5
            opacity: 1.0
            flip_h: false
            flip_v: false
            scale: 1.0
            anchor_bg: { x: 0.5, y: 0.5 }
            anchor_fg: { x: 0.5, y: 0.5 }
            transition_type: "fade"
            transition_duration: 0.8
    ending:
      type: "auto_redirect"
      consequence:
        type: "redirect_sequence"
        target: "seq-entrance"
        effects:
          - variable: "has_key"
            operation: "set"
            value: "true"

  - uuid: "seq-chest-open"
    name: "Chest Opened"
    position: { x: 600, y: 0 }
    background: "room.png"
    foregrounds: []
    dialogues:
      - uuid: "dlg-4"
        character: "Narrator"
        text: "The key turns in the lock. The chest opens, revealing a glittering treasure!"
        foregrounds: []
      - uuid: "dlg-5"
        character: "Narrator"
        text: "Congratulations, you found the treasure!"
        foregrounds: []
    ending:
      type: "auto_redirect"
      consequence:
        type: "game_over"
        effects: []

  - uuid: "seq-chest-locked"
    name: "Chest Locked"
    position: { x: 600, y: 200 }
    background: "room.png"
    foregrounds: []
    dialogues:
      - uuid: "dlg-6"
        character: "Narrator"
        text: "The chest is firmly locked. You need a key."
        foregrounds: []
    ending:
      type: "auto_redirect"
      consequence:
        type: "redirect_sequence"
        target: "seq-entrance"
        effects: []

conditions:
  - uuid: "cond-key"
    name: "Do we have the key?"
    subtitle: ""
    position: { x: 450, y: 100 }
    rules:
      - variable: "has_key"
        operator: "equal"
        value: "true"
        consequence:
          type: "redirect_sequence"
          target: "seq-chest-open"
          effects: []
    default_consequence:
      type: "redirect_sequence"
      target: "seq-chest-locked"
      effects: []

connections:
  - from: "seq-entrance"
    to: "seq-drawer"
  - from: "seq-entrance"
    to: "cond-key"
  - from: "cond-key"
    to: "seq-chest-open"
  - from: "cond-key"
    to: "seq-chest-locked"
  - from: "seq-drawer"
    to: "seq-entrance"
```

---

## Practical Tips

- **UUIDs** -- Use short, readable identifiers (`"seq-combat"`, `"ch-01"`, `"scene-intro"`) rather than actual UUIDs. The engine accepts any unique string.

- **Positions** -- The `position` fields are only used by the graph editor for visual layout. When writing YAML by hand, you can set `{ x: 0, y: 0 }` everywhere without any impact on gameplay.

- **Variable values** -- All values are stored as strings. Write `"0"` not `0`, `"true"` not `true`. The engine converts to numbers internally when needed for arithmetic operations.

- **Test progressively** -- Start with a simple story (one chapter, one scene, two sequences) and enrich gradually. This makes it easier to catch errors early.

- **Image filenames** -- The filenames in `background` and `image` fields correspond to files in `assets/backgrounds/` and `assets/foregrounds/` respectively. Only the filename is needed, not the full path.

- **Audio filenames** -- Similarly, `music` values reference files in `assets/music/` and `audio_fx` values reference files in `assets/audio_fx/`.

- **Connections mirror consequences** -- The `connections` arrays should generally mirror the paths defined by your consequences. The editor maintains these automatically; when writing by hand, they help document the flow but are not strictly required for the game to function.

- **Default values** -- Most optional fields have sensible defaults. You only need to specify fields where you want non-default behavior. A minimal sequence only needs `uuid`, `name`, `dialogues`, and `ending`.

---

# Part 3: Releasing Your Story

## Exporting from the Editor

Once your story is complete and verified, you can export it as a standalone application that players can run without installing Frame Novel Studio or Godot.

To export:

1. Click the **Export** button in the editor toolbar.
2. Select the **target platform** (Windows, macOS, or Web/HTML5).
3. Configure export options:
   - **Game name** -- The name displayed in the application title bar and file metadata.
   - **Quality** -- Choose between HD (original resolution), SD (2x downscaled), or Ultra SD (4x downscaled) to control file size.
   - **Language** -- Export with all languages or a single language to reduce file size.
   - **Chapters** -- Export all chapters or select a subset (useful for episodic releases or demos).
4. Click **Export** and choose the output location.

The export process packages your story files, assets, and the Frame Novel Studio player engine into a standalone application.

## Windows Export

- Produces a standalone `.exe` file with all assets embedded.
- Players run the `.exe` directly -- no installation or additional software required.
- Can be distributed via itch.io, Steam, your own website, or any other distribution channel.
- No Godot installation is needed for players.

## macOS Export

- Produces a `.zip` file containing a `.app` bundle.
- Players extract the `.zip` and double-click the `.app` to run.
- Code signing is optional but recommended for public distribution. Without signing, players may need to right-click and select "Open" the first time to bypass Gatekeeper.
- Can be distributed via itch.io, the Mac App Store, or direct download.

## Web / HTML5 Export

- Produces a set of HTML5 files (`index.html` plus supporting JavaScript, WebAssembly, and data files).
- Supports **Progressive Web App (PWA)** features, including install prompts on mobile devices and offline support.
- Host the files on any web server: GitHub Pages, itch.io, Netlify, your own hosting, or any static file server.
- Players access the story through their web browser -- no download or installation needed.
- Works on desktop and mobile browsers.

## Testing Your Export

Always test your exported builds before distributing them to players.

**Windows** -- Run the `.exe` file directly. Verify that the game loads, all images and audio play correctly, choices work, and the story can be completed.

**macOS** -- Extract the `.zip` file and run the `.app` bundle. On your own machine, you may need to right-click and select "Open" if the app is not code-signed.

**Web** -- Serve the exported files with a local HTTP server and open them in your browser:

```bash
cd /path/to/exported/files
python3 -m http.server 8080
```

Then open `http://localhost:8080` in your browser. Test on multiple browsers (Chrome, Firefox, Safari) and on mobile devices if possible. Check the browser's developer console (F12) for any error messages.

In all cases, play through the entire story at least once, testing every branch and choice to ensure nothing is broken in the exported version.
