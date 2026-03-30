# Toolbar Toggle Default Hidden — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Change game toolbar default to hidden, add a small toggle button at bottom-right to show/hide the play buttons bar during gameplay.

**Architecture:** The existing `toolbar_visible` setting in `GameSettings` already controls the play buttons bar visibility. We change its default to `false`, add a `_toolbar_toggle_button` built by `GameUIBuilder`, and wire toggle logic through `GamePlayController`. The button syncs with the options menu via `GameSettings`.

**Tech Stack:** GDScript, Godot 4.6.1, GUT testing framework

---

### Task 1: Change `toolbar_visible` default to `false`

**Files:**
- Modify: `src/ui/menu/game_settings.gd:37` (default value)
- Modify: `src/ui/menu/game_settings.gd:96` (load fallback)
- Modify: `specs/ui/menu/test_game_settings.gd` (adapt tests)

- [ ] **Step 1: Update test expectations for new default**

In `specs/ui/menu/test_game_settings.gd`, add a test verifying the new default:

```gdscript
func test_toolbar_visible_defaults_to_false():
	var settings = GameSettingsScript.new()
	assert_false(settings.toolbar_visible, "toolbar_visible should default to false")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `timeout 30 /Applications/Godot-4.6.1.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/ui/menu/test_game_settings.gd`
Expected: FAIL — `toolbar_visible` currently defaults to `true`

- [ ] **Step 3: Change the default in GameSettings**

In `src/ui/menu/game_settings.gd`, change line 37:

```gdscript
var toolbar_visible: bool = false
```

And change line 96 (load fallback):

```gdscript
toolbar_visible = cfg.get_value("display", "toolbar_visible", false)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `timeout 30 /Applications/Godot-4.6.1.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/ui/menu/test_game_settings.gd`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add src/ui/menu/game_settings.gd specs/ui/menu/test_game_settings.gd
git commit -m "feat: change toolbar_visible default to false"
```

---

### Task 2: Add `_toolbar_toggle_button` variable to `game.gd`

**Files:**
- Modify: `src/game.gd:62` (add variable declaration)

- [ ] **Step 1: Add the variable declaration**

In `src/game.gd`, after line 62 (`var _play_buttons_bar: HBoxContainer`), add:

```gdscript
var _toolbar_toggle_button: Button
```

- [ ] **Step 2: Run existing tests to verify nothing broke**

Run: `timeout 30 /Applications/Godot-4.6.1.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/game/test_game_play_controller.gd`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add src/game.gd
git commit -m "feat: add _toolbar_toggle_button variable to game.gd"
```

---

### Task 3: Build the toggle button in `GameUIBuilder`

**Files:**
- Modify: `src/controllers/game_ui_builder.gd:142-159` (add button build in `_build_play_buttons_bar`)

- [ ] **Step 1: Write failing test for toggle button existence**

In `specs/game/test_game_play_controller.gd`, add:

```gdscript
func test_toolbar_toggle_button_exists() -> void:
	assert_not_null(_game._toolbar_toggle_button, "toolbar toggle button should exist")
	assert_is(_game._toolbar_toggle_button, Button)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `timeout 30 /Applications/Godot-4.6.1.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/game/test_game_play_controller.gd`
Expected: FAIL — `_toolbar_toggle_button` is null

- [ ] **Step 3: Build the toggle button in `_build_play_buttons_bar`**

In `src/controllers/game_ui_builder.gd`, at the end of `_build_play_buttons_bar()` (after `game.add_child(game._play_buttons_bar)` on line 159), add:

```gdscript
	# Toggle button — small button at bottom-right to show/hide toolbar
	game._toolbar_toggle_button = Button.new()
	game._toolbar_toggle_button.text = "≡"
	game._toolbar_toggle_button.visible = false
	game._toolbar_toggle_button.z_index = SequenceVisualEditorScript.UI_OVERLAY_Z
	game._toolbar_toggle_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	game._toolbar_toggle_button.offset_left = -roundi(40 * s)
	game._toolbar_toggle_button.offset_right = -roundi(4 * s)
	game._toolbar_toggle_button.offset_top = -roundi(188 * s)
	game._toolbar_toggle_button.offset_bottom = -roundi(150 * s)
	game._toolbar_toggle_button.self_modulate = Color(1, 1, 1, 0.6)
	game._toolbar_toggle_button.mouse_filter = Control.MOUSE_FILTER_STOP
	game.add_child(game._toolbar_toggle_button)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `timeout 30 /Applications/Godot-4.6.1.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/game/test_game_play_controller.gd`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add src/controllers/game_ui_builder.gd specs/game/test_game_play_controller.gd
git commit -m "feat: build toolbar toggle button in GameUIBuilder"
```

---

### Task 4: Wire toggle logic in `GamePlayController`

**Files:**
- Modify: `src/controllers/game_play_controller.gd:94-123` (setup — grab reference + connect signal)
- Modify: `src/controllers/game_play_controller.gd:82-83` (set_toolbar_visible — update toggle button text)
- Modify: `src/controllers/game_play_controller.gd:233-245` (_start_sequence_actually — show toggle button)
- Modify: `src/controllers/game_play_controller.gd:505-508` (_handle_play_stopped — hide toggle button)
- Modify: `src/controllers/game_play_controller.gd:860-867` (stop_story — hide toggle button)

- [ ] **Step 1: Write failing tests for toggle behavior**

In `specs/game/test_game_play_controller.gd`, add:

```gdscript
func test_toggle_button_click_shows_toolbar() -> void:
	_game._play_ctrl.set_toolbar_visible(false)
	_game._play_ctrl._on_toolbar_toggle_pressed()
	assert_true(_game._play_ctrl._toolbar_visible, "toolbar should be visible after toggle")

func test_toggle_button_click_hides_toolbar() -> void:
	_game._play_ctrl.set_toolbar_visible(true)
	_game._play_ctrl._on_toolbar_toggle_pressed()
	assert_false(_game._play_ctrl._toolbar_visible, "toolbar should be hidden after toggle")

func test_toggle_button_updates_text_to_close() -> void:
	_game._play_ctrl.set_toolbar_visible(false)
	_game._play_ctrl._on_toolbar_toggle_pressed()
	assert_eq(_game._toolbar_toggle_button.text, "×", "should show close icon when toolbar visible")

func test_toggle_button_updates_text_to_hamburger() -> void:
	_game._play_ctrl.set_toolbar_visible(true)
	_game._play_ctrl._on_toolbar_toggle_pressed()
	assert_eq(_game._toolbar_toggle_button.text, "≡", "should show hamburger when toolbar hidden")
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `timeout 30 /Applications/Godot-4.6.1.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/game/test_game_play_controller.gd`
Expected: FAIL — `_on_toolbar_toggle_pressed` doesn't exist

- [ ] **Step 3: Implement toggle logic in GamePlayController**

In `src/controllers/game_play_controller.gd`:

**a)** Add variable after `_toolbar_visible` (line 43):

```gdscript
var _toolbar_toggle_button: Button = null
```

**b)** In `setup()`, after the `_history_button` block (after line 117), add:

```gdscript
	if game.get("_toolbar_toggle_button") != null:
		_toolbar_toggle_button = game._toolbar_toggle_button
		_toolbar_toggle_button.pressed.connect(_on_toolbar_toggle_pressed)
```

**c)** Update `set_toolbar_visible()` (replace lines 82-83):

```gdscript
func set_toolbar_visible(p_visible: bool) -> void:
	_toolbar_visible = p_visible
	if _play_buttons_bar:
		_play_buttons_bar.visible = _toolbar_visible
	if _toolbar_toggle_button:
		_toolbar_toggle_button.text = "×" if _toolbar_visible else "≡"
```

**d)** Add the toggle handler after `set_toolbar_visible`:

```gdscript
func _on_toolbar_toggle_pressed() -> void:
	set_toolbar_visible(not _toolbar_visible)
```

**e)** In `_start_sequence_actually()`, after `_game.move_child(_play_buttons_bar, -1)` (line 245), add:

```gdscript
		if _toolbar_toggle_button:
			_toolbar_toggle_button.visible = true
			_game.move_child(_toolbar_toggle_button, -1)
```

**f)** In `_handle_play_stopped()`, after `_play_buttons_bar.visible = false` (line 508), add:

```gdscript
	if _toolbar_toggle_button:
		_toolbar_toggle_button.visible = false
```

**g)** In `stop_story()`, after `_play_buttons_bar.visible = false` (line 867), add:

```gdscript
	if _toolbar_toggle_button:
		_toolbar_toggle_button.visible = false
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `timeout 30 /Applications/Godot-4.6.1.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/game/test_game_play_controller.gd`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add src/controllers/game_play_controller.gd specs/game/test_game_play_controller.gd
git commit -m "feat: wire toolbar toggle button logic in GamePlayController"
```

---

### Task 5: Sync toggle with settings persistence and options menu

**Files:**
- Modify: `src/controllers/game_play_controller.gd` (persist on toggle)
- Modify: `src/game.gd:443-458` (`_on_options_applied` — already syncs, verify toggle button text updates)
- Modify: `src/game.gd:687-707` (`_hide_play_ui_for_menu` / `_restore_play_ui_after_menu` — handle toggle button)

- [ ] **Step 1: Write failing test for settings persistence on toggle**

In `specs/game/test_game_play_controller.gd`, add:

```gdscript
func test_toggle_emits_toolbar_toggled_signal() -> void:
	watch_signals(_game._play_ctrl)
	_game._play_ctrl._on_toolbar_toggle_pressed()
	assert_signal_emitted(_game._play_ctrl, "toolbar_toggled")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `timeout 30 /Applications/Godot-4.6.1.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/game/test_game_play_controller.gd`
Expected: FAIL — signal doesn't exist

- [ ] **Step 3: Add signal and persistence wiring**

**a)** In `src/controllers/game_play_controller.gd`, add signal after `play_finished_show_menu()` (line 53):

```gdscript
signal toolbar_toggled(visible: bool)
```

**b)** Update `_on_toolbar_toggle_pressed`:

```gdscript
func _on_toolbar_toggle_pressed() -> void:
	set_toolbar_visible(not _toolbar_visible)
	toolbar_toggled.emit(_toolbar_visible)
```

**c)** In `src/game.gd`, in `_ready()` where signals are connected (around line 195, after `_play_ctrl.play_finished_show_menu.connect`), add:

```gdscript
	_play_ctrl.toolbar_toggled.connect(_on_toolbar_toggled)
```

**d)** In `src/game.gd`, add the handler (near `_on_options_applied`):

```gdscript
func _on_toolbar_toggled(visible: bool) -> void:
	_settings.toolbar_visible = visible
	_settings.save_settings()
```

**e)** In `src/game.gd`, update `_hide_play_ui_for_menu()` — save and hide toggle button:

After `"menu_button": _menu_button.visible,` in the dictionary, add:

```gdscript
		"toolbar_toggle": _toolbar_toggle_button.visible if _toolbar_toggle_button else false,
```

After `_menu_button.visible = false`, add:

```gdscript
	if _toolbar_toggle_button:
		_toolbar_toggle_button.visible = false
```

**f)** In `src/game.gd`, update `_restore_play_ui_after_menu()` — restore toggle button:

After `_menu_button.visible = ...`, add:

```gdscript
	if _toolbar_toggle_button:
		_toolbar_toggle_button.visible = _play_ui_state_before_menu.get("toolbar_toggle", false)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `timeout 30 /Applications/Godot-4.6.1.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/game/test_game_play_controller.gd`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add src/controllers/game_play_controller.gd src/game.gd specs/game/test_game_play_controller.gd
git commit -m "feat: sync toolbar toggle with settings persistence"
```

---

### Task 6: Run all tests and verify

**Files:** None (verification only)

- [ ] **Step 1: Run full test suite**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 120 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd
```

Expected: All tests pass, including the adapted settings tests and new toggle tests.

- [ ] **Step 2: Fix any failures**

If any existing tests fail due to the default change (e.g., a test that assumed `toolbar_visible` defaults to `true`), update those tests to match the new `false` default.

- [ ] **Step 3: Final commit if fixes were needed**

```bash
git add -A
git commit -m "fix: adapt tests for toolbar_visible default change"
```
