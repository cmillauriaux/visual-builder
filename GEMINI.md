# Visual Builder - Godot Visual Novel Editor

A comprehensive visual novel editor and standalone player built with Godot 4.4.

## Project Overview
This project provides a professional-grade tool for creating visual novels without coding. It features a graph-based editor for story structure (chapters, scenes, sequences) and a visual editor for composing dialogue and foreground elements.

- **Main Technologies:** Godot 4.4 (GDScript), GL Compatibility renderer (for web/HTML5 support).
- **Architecture:** MVC-inspired structure with dedicated controllers for UI building, navigation, and playback.
- **Key Features:**
    - Graph-based story flow management.
    - Visual sequence editor with drag-and-drop foreground elements.
    - Internationalization (i18n) support.
    - Undo/Redo system using the Command pattern.
    - Standalone game mode for playing exported stories.
    - Story verification and export tools.

## Project Structure
- `src/`: Main source code.
    - `commands/`: Implementation of the Command pattern for undo/redo.
    - `controllers/`: Logic for UI construction and cross-component coordination.
    - `models/`: Data models for stories, chapters, scenes, sequences, etc.
    - `persistence/`: Logic for saving and loading stories (YAML/JSON).
    - `services/`: Specialized logic like I18n, texture loading, and undo/redo services.
    - `ui/`: UI components, dialogs, and specific editor panels.
    - `views/`: Specialized views like GraphEdit implementations and the visual sequence editor.
- `specs/`: Project specifications and tests.
    - Markdown files (`001-...md`) define feature specifications.
    - GDScript files (`test_....gd`) are [GUT](https://github.com/bitwes/Gut) tests.
- `stories/`: Sample stories and default story templates.
- `tools/`: Utility scripts for story generation and verification.

## Building and Running
### Running the Project
- **Editor:** Open `project.godot` in Godot 4.4.
- **Run Editor:** `godot --path .` (or use the absolute path to Godot binary as defined in `CLAUDE.md`).
- **Run Game Mode:** The project can be run with `res://src/game.tscn` as the main scene for standalone play.

### Running Tests
Tests use the GUT framework.
- **Run All Tests:** `godot --headless --path . -s addons/gut/gut_cmdln.gd`
- **Run Specific Test:** `godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/path_to_test.gd`
- **Run E2E Tests Only:** `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://specs/e2e/`

## Development Conventions
- **Specifications First:** Every feature must have a corresponding Markdown specification in `specs/` before implementation.
- **Test-Driven Development:** Aim for 100% test coverage using GUT. Tests should reside in `specs/` following the directory structure of `src/`.
- **UI Construction:** UI is largely built programmatically via builders (e.g., `MainUIBuilder`, `GameUIBuilder`) to maintain flexibility and decoupling.
- **Undo/Redo:** All user actions that modify the story state should be implemented as `Command` objects to support the global undo/redo service.
- **Internationalization:** Use `StoryI18nService` for all user-facing strings to ensure the editor and games can be translated.
- **Validation:** Always run `/check-global-acceptance` (custom script/command mentioned in `CLAUDE.md`) before finalizing tasks.

## Key Files
- `project.godot`: Main Godot configuration.
- `src/main.gd`: Entry point for the visual novel editor.
- `src/game.gd`: Entry point for the standalone game player.
- `CLAUDE.md`: Contains environment-specific commands and detailed developer guidelines.
- `TODO.md`: Tracks project progress and pending features.
