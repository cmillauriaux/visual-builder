# Frame Novel Studio

**A visual novel editor and engine built with Godot**

<!-- TODO: Add screenshot -->

## What is Frame Novel Studio?

Frame Novel Studio is a complete visual novel creation suite built with Godot 4.6.1. It provides a full-featured visual editor that lets creators build interactive fiction stories without writing a single line of code. Stories are organized into chapters, scenes, and sequences, and can be exported as standalone games for Windows, macOS, and the Web.

The project operates in two modes. The **Editor** is a rich authoring environment with graph editors, a dialogue timeline, and a visual sequence editor for laying out characters, backgrounds, and effects. The **Game Player** is a lightweight runtime engine that plays back exported stories with full support for branching narratives, save/load, and multi-language text.

Whether you are a solo writer prototyping a short narrative or a small team producing a polished release, Frame Novel Studio gives you the tools to go from idea to published game entirely within one application.

## Key Features

### Story Editing
- Hierarchical story structure: chapters, scenes, and sequences
- Visual graph editors for scene and chapter flow
- Dialogue timeline with drag-and-drop ordering
- Sequence visual editor with foreground layer composition

### Branching and Variables
- Player choices with up to 8 options per sequence
- Story variables with configurable effects
- Condition nodes for automatic branching based on variable state

### Visual Features
- Foreground layers with inheritance across sequences
- Transitions including fade, pixelate, and custom shaders
- Blink animation system for character sprites
- Visual effects: screen shake, flash, and more
- Drag-and-drop positioning for all visual elements

### Audio
- Background music with crossfade support
- Sound effects triggered from the dialogue timeline

### Multi-Platform Export
- Windows (.exe)
- macOS (.app)
- Web (HTML5 with PWA support)

### Internationalization
- Multi-language story support
- Automatic language detection
- YAML-based translation files

### Plugin System
- Extensible architecture with editor and game plugins
- Built-in plugins: launcher, analytics, access control, content filtering, walkthrough
- Transformation pipelines for dialogue and choices
- Full lifecycle hooks (chapter, scene, sequence, save/load events)
- Create your own plugins with a simple GDScript API

### Gameplay
- Save and load with 6 slots plus quick save
- Auto-play and skip modes
- Dialogue history log
- Typewriter text effect with configurable speed
- Chapter and scene selection screen

## Download

Pre-built binaries for Windows and macOS are available on the [Releases](https://github.com/Raccoons-Studio/frame-novel-studio/releases) page.

## Quick Start

1. Download the latest release from the [Releases](https://github.com/Raccoons-Studio/frame-novel-studio/releases) page, or clone the repository and open it in [Godot 4.6.1](https://godotengine.org/).
2. Launch Frame Novel Studio and create a new story project.
3. Add chapters, scenes, and sequences using the graph editors.
4. Write dialogue, place characters, and configure choices in the visual sequence editor.
5. Export your finished story as a standalone game for your target platform.

## Documentation

- [Architecture](docs/architecture.md) -- Technical architecture and design patterns
- [Features](docs/features.md) -- Complete feature reference
- [Developer Guide](docs/developer-guide.md) -- Build, test, and contribute
- [Plugin Development](docs/plugin-development.md) -- Create editor and game plugins
- [Story Writer's Guide](docs/story-writers-guide.md) -- Create and publish your stories

## Tech Stack

- **Engine**: Godot 4.6.1
- **Language**: GDScript
- **Renderer**: GL Compatibility (OpenGL-based, required for web export)
- **Story Format**: YAML
- **Testing**: GUT (Godot Unit Test) framework

## License

TBD

## Contributing

Contributions are welcome. See the [Developer Guide](docs/developer-guide.md) for instructions on building, testing, and submitting changes.
