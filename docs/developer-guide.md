# Developer Guide

This guide covers everything you need to contribute to **Frame Novel Studio**, a visual novel editor and player built with Godot 4.6.1.

GitHub repository: [https://github.com/Raccoons-Studio/frame-novel-studio](https://github.com/Raccoons-Studio/frame-novel-studio)

---

## 1. Prerequisites

- **Godot 4.6.1** -- Download from [godotengine.org](https://godotengine.org/download). The project uses the GL Compatibility renderer (OpenGL-based), which supports web/HTML5 export and older hardware.
- **Git** with **LFS** support -- The project uses Git LFS for binary assets.

### Platform-specific setup

| Platform | Godot binary location | Notes |
|----------|----------------------|-------|
| macOS | `/Applications/Godot-4.6.1.app/Contents/MacOS/Godot` | Default path used by scripts |
| Linux | `godot` in `PATH` | Install the binary or set `GODOT_PATH` |
| Windows | Set `GODOT_PATH` environment variable | Point to your `Godot.exe` location |

On all platforms, the `GODOT_PATH` environment variable takes priority if set. Scripts auto-detect the binary with:

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
```

---

## 2. Getting Started

Clone the repository and pull LFS objects:

```bash
git clone https://github.com/Raccoons-Studio/frame-novel-studio.git
cd frame-novel-studio
```

Open the project in the Godot editor or run it from the command line:

```bash
# Auto-detect Godot binary
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}

# Open in editor
$GODOT --editor --path .

# Run the project
$GODOT --path .
```

---

## 3. Project Structure

```
frame-novel-studio/
├── src/                  # Main source code
│   ├── models/           # Data models (Story, Chapter, Scene, Sequence, etc.)
│   ├── controllers/      # Business logic and orchestration
│   ├── services/         # Reusable stateless utilities
│   ├── persistence/      # YAML save/load layer
│   ├── ui/               # User interface components
│   ├── views/            # Graph editors and visual panels
│   ├── commands/         # Story operations (undo/redo capable)
│   ├── export/           # Export pipeline (PCK builder, packaging)
│   └── plugins/          # Plugin framework (base classes, managers)
├── plugins/              # Plugin implementations (launcher, walkthrough, etc.)
├── specs/                # Tests (GUT) and specifications
├── docs/                 # Documentation
├── addons/               # Third-party addons (GUT, coverage)
├── project.godot         # Godot project configuration
└── export_presets.cfg    # Export platform presets
```

See [architecture.md](architecture.md) for detailed architecture documentation.

---

## 4. Running Tests

The project uses the [GUT](https://github.com/bitwes/Gut) (Godot Unit Testing) framework. Test configuration lives in `.gutconfig.json`, which sets `should_exit` to `true` so Godot exits automatically after running tests.

### Unit tests (headless)

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}

# Run all tests
timeout 120 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd

# Run a specific test file
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/models/test_story.gd
```

### E2E tests (non-headless)

End-to-end tests simulate real user interactions (mouse clicks at actual coordinates) and require a **visible window** for controls to have a real layout. Do not use `--headless`.

```bash
# Run all e2e tests
timeout 120 $GODOT --path . -s addons/gut/gut_cmdln.gd -gdir=res://specs/e2e/

# Run a specific e2e test
timeout 60 $GODOT --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/e2e/test_e2e_editor_ui_clicks.gd

# Linux CI (virtual framebuffer for headless environments)
xvfb-run -a $GODOT --path . -s addons/gut/gut_cmdln.gd -gdir=res://specs/e2e/
```

### Code coverage

The project uses `addons/coverage/` for code coverage instrumentation and reporting:

- **Pre-run hook** (`specs/pre_run_hook.gd`): Instruments all scripts under `src/` before tests run.
- **Post-run hook** (`specs/post_run_hook.gd`): Generates the coverage report and checks against targets.
- Coverage results are printed at the end of every test run.
- **Current target**: 80% total coverage.

---

## 5. Building and Exporting

### Local export

Before exporting, run a headless editor import pass so Godot processes all resources:

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}

# Import resources first
$GODOT --headless --path . --editor --quit

# Export for Windows
$GODOT --headless --path . --export-release "Windows" build/windows/frame-novel-studio.exe

# Export for macOS
$GODOT --headless --path . --export-release "macOS" build/macos/frame-novel-studio.zip

# Export for Web
$GODOT --headless --path . --export-release "Web" build/web/index.html
```

### CI/CD Pipeline

The GitHub Actions workflow (`.github/workflows/build-visual-builder.yml`) automates builds:

- **Triggers**: Push to `main` or `master`, manual `workflow_dispatch`.
- **Platforms**: Windows and macOS exports run in parallel on `ubuntu-latest`.
- **Godot setup**: Uses [`chickensoft-games/setup-godot@v2`](https://github.com/chickensoft-games/setup-godot) with version `4.6.1` and export templates included.
- **Steps**: Checkout (with LFS) -> Setup Godot -> Import resources -> Export builds -> Upload artifacts -> Create GitHub release.
- **Release tags**: Format `v{YYYY.MM.DD}-b{BUILD_NUMBER}`.
- **Release creation**: Uses [`softprops/action-gh-release@v2`](https://github.com/softprops/action-gh-release).

---

## 6. Code Conventions

### Language and style

- **Language**: GDScript (Godot's built-in scripting language).
- **File organization**: One class per file, organized by architectural layer.
- **Naming conventions**:
  - `snake_case` for variables, functions, and file names.
  - `PascalCase` for class names.
  - `UPPER_CASE` for constants.
- **Line endings**: LF enforced via `.gitattributes`.

### Architecture guidelines

- **Models** (`src/models/`): Pure data classes. Hold properties and serialization helpers only -- no game logic, no side effects.
- **Controllers** (`src/controllers/`): Orchestrate business logic. Receive signals, coordinate between services, and update models.
- **Services** (`src/services/`): Stateless or singleton utilities. Reusable across both the editor and game player.
- **Signals**: Prefer signals over direct references for loose coupling between components. Models emit signals when data changes; controllers listen and react.

---

## 7. Writing Plugins

Frame Novel Studio has an extensible plugin system with two plugin types:

- **Editor plugins** (`VBPlugin`) -- Add UI panels, menus, toolbar buttons, and tabs to the editor
- **Game plugins** (`VBGamePlugin`) -- Hook into the story lifecycle and contribute runtime UI to the player

Plugins live in the `plugins/` directory and are discovered automatically. Each plugin has either a `plugin.gd` (editor), a `game_plugin.gd` (game), or both.

For the complete plugin API reference, contribution types, and step-by-step tutorial, see the [Plugin Development Guide](plugin-development.md).

---

## 8. Writing Tests

Tests live in `specs/` and follow GUT conventions.

### File and directory layout

Organize test files to mirror the source structure:

```
specs/
├── models/           # Tests for src/models/
├── controllers/      # Tests for src/controllers/
├── services/         # Tests for src/services/
├── persistence/      # Tests for src/persistence/
├── ui/               # Tests for src/ui/
├── export/           # Tests for src/export/
├── plugins/          # Tests for plugin implementations
├── e2e/              # End-to-end tests (non-headless)
└── integration/      # Integration tests
```

### Test file conventions

- File names start with `test_` (e.g., `test_story.gd`).
- Test classes extend `GutTest`.
- Test methods start with `test_`.

### Example test

```gdscript
extends GutTest

var _model: MyModel

func before_each():
    _model = MyModel.new()

func after_each():
    _model = null

func test_default_values():
    assert_eq(_model.name, "", "Name should default to empty string")
    assert_eq(_model.count, 0, "Count should default to zero")

func test_set_name():
    _model.name = "Test"
    assert_eq(_model.name, "Test")

func test_validation_rejects_empty():
    assert_false(_model.is_valid(), "Empty model should not be valid")
```

### Common assertions

| Assertion | Usage |
|-----------|-------|
| `assert_eq(got, expected)` | Equality check |
| `assert_ne(got, unexpected)` | Inequality check |
| `assert_true(condition)` | Boolean true |
| `assert_false(condition)` | Boolean false |
| `assert_null(value)` | Value is null |
| `assert_not_null(value)` | Value is not null |
| `assert_has(array, value)` | Array contains value |
| `assert_gt(a, b)` | a > b |
| `assert_lt(a, b)` | a < b |

### Running a single test

```bash
timeout 30 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/models/test_story.gd
```

New test directories must be registered in `.gutconfig.json` under the `dirs` array.
