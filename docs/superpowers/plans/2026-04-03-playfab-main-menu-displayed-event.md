# PlayFab `main_menu_displayed` Event — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Send a one-time PlayFab analytics event when the main menu first appears, reporting platform (with Web mobile/desktop distinction) and version info.

**Architecture:** New `on_main_menu_displayed` hook in the plugin system (base class + manager + dispatch in game.gd), implemented by the PlayFab plugin to track the event. A `_main_menu_event_sent` flag in game.gd ensures single-fire per session.

**Tech Stack:** GDScript (Godot 4.6.1), GUT test framework, PlayFab REST API (via existing service)

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `src/plugins/game_plugin.gd` | Modify (line ~129) | Add `on_main_menu_displayed` virtual hook |
| `src/plugins/game_plugin_manager.gd` | Modify (line ~271) | Add `dispatch_on_main_menu_displayed` |
| `src/game.gd` | Modify (lines ~134, ~477-508) | Add flag + `_get_platform_string()` + dispatch call in `_show_main_menu()` |
| `plugins/playfab_analytics/game_plugin.gd` | Modify (line ~161) | Implement `on_main_menu_displayed` |
| `specs/plugins/test_game_plugin_manager.gd` | Modify | Add dispatch test + update TestPlugin with new hook |
| `specs/plugins/playfab_analytics/test_playfab_analytics_plugin.gd` | Modify | Add tests for new hook |

---

### Task 1: Add `on_main_menu_displayed` hook to `VBGamePlugin` base class

**Files:**
- Modify: `src/plugins/game_plugin.gd:129` (after `on_quickload`)
- Test: `specs/plugins/test_game_plugin_manager.gd` (update `TestPlugin` inner class)

- [ ] **Step 1: Add the hook to the base class**

In `src/plugins/game_plugin.gd`, insert after line 129 (after the `on_quickload` method):

```gdscript
## Appelé quand le menu principal est affiché pour la première fois (une fois par session).
func on_main_menu_displayed(ctx: RefCounted, platform: String, app_version: String, story_version: String) -> void:
	pass
```

- [ ] **Step 2: Update the `TestPlugin` inner class in the manager tests**

In `specs/plugins/test_game_plugin_manager.gd`, add this method to the `TestPlugin` inner class (after line 59, after `get_options_controls`):

```gdscript
	func on_main_menu_displayed(ctx, platform: String, app_version: String, story_version: String):
		calls.append("main_menu_displayed")
```

Also add the same method to `_UpperPlugin` (after line 400), `_PrefixPlugin` (after line 422), `_ToolbarPlugin` (after line 447), and `_OverlayPlugin` (after line 472):

```gdscript
	func on_main_menu_displayed(_ctx, _p: String, _av: String, _sv: String): pass
```

- [ ] **Step 3: Run tests to verify nothing is broken**

Run: `timeout 120 /Applications/Godot-4.6.1.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/plugins/test_game_plugin_manager.gd`

Expected: All existing tests PASS.

- [ ] **Step 4: Commit**

```bash
git add src/plugins/game_plugin.gd specs/plugins/test_game_plugin_manager.gd
git commit -m "feat(plugins): add on_main_menu_displayed virtual hook to VBGamePlugin base class"
```

---

### Task 2: Add `dispatch_on_main_menu_displayed` to `GamePluginManager`

**Files:**
- Modify: `src/plugins/game_plugin_manager.gd:271` (after `dispatch_on_quickload`)
- Test: `specs/plugins/test_game_plugin_manager.gd`

- [ ] **Step 1: Write the failing test**

In `specs/plugins/test_game_plugin_manager.gd`, add after the existing `test_dispatch_on_after_choice` test (around line 231):

```gdscript
func test_dispatch_on_main_menu_displayed():
	var p = TestPlugin.new("a")
	_manager.register_plugin(p)
	_manager.dispatch_on_main_menu_displayed(_create_context(), "macOS", "1.2.0", "1.0.0")
	assert_has(p.calls, "main_menu_displayed")


func test_dispatch_on_main_menu_displayed_skips_disabled():
	var p = TestPlugin.new("a")
	_manager.register_plugin(p)
	_manager.set_plugin_enabled("a", false)
	_manager.dispatch_on_main_menu_displayed(_create_context(), "macOS", "1.2.0", "1.0.0")
	assert_does_not_have(p.calls, "main_menu_displayed")
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `timeout 120 /Applications/Godot-4.6.1.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/plugins/test_game_plugin_manager.gd`

Expected: FAIL — `dispatch_on_main_menu_displayed` does not exist on manager.

- [ ] **Step 3: Implement the dispatch method**

In `src/plugins/game_plugin_manager.gd`, insert after line 271 (after `dispatch_on_quickload`):

```gdscript

func dispatch_on_main_menu_displayed(ctx: RefCounted, platform: String, app_version: String, story_version: String) -> void:
	for plugin in _get_active_plugins():
		plugin.on_main_menu_displayed(ctx, platform, app_version, story_version)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `timeout 120 /Applications/Godot-4.6.1.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/plugins/test_game_plugin_manager.gd`

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add src/plugins/game_plugin_manager.gd specs/plugins/test_game_plugin_manager.gd
git commit -m "feat(plugins): add dispatch_on_main_menu_displayed to GamePluginManager"
```

---

### Task 3: Implement `on_main_menu_displayed` in PlayFab plugin

**Files:**
- Modify: `plugins/playfab_analytics/game_plugin.gd:161` (after `on_quickload`)
- Test: `specs/plugins/playfab_analytics/test_playfab_analytics_plugin.gd`

- [ ] **Step 1: Write the failing tests**

In `specs/plugins/playfab_analytics/test_playfab_analytics_plugin.gd`, add after the `test_on_quickload_safe_without_service` test (around line 193):

```gdscript
func test_on_main_menu_displayed_safe_without_service():
	var ctx = _create_context()
	_plugin.on_main_menu_displayed(ctx, "macOS", "1.2.0", "1.0.0")
	assert_null(_plugin.get_service())
	ctx.game_node.queue_free()
```

- [ ] **Step 2: Run tests to verify the new test passes (base class default)**

Run: `timeout 30 /Applications/Godot-4.6.1.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/plugins/playfab_analytics/test_playfab_analytics_plugin.gd`

Expected: PASS — the base class has a no-op default for `on_main_menu_displayed`.

- [ ] **Step 3: Implement the hook in the PlayFab plugin**

In `plugins/playfab_analytics/game_plugin.gd`, insert after line 161 (after `on_quickload`):

```gdscript

func on_main_menu_displayed(_ctx: RefCounted, platform: String, app_version: String, story_version: String) -> void:
	if _service == null or not _service.is_active():
		return
	_service.track_event("main_menu_displayed", {
		"platform": platform,
		"app_version": app_version,
		"story_version": story_version,
		"story_title": _story_title,
	})
```

- [ ] **Step 4: Run tests to verify all pass**

Run: `timeout 30 /Applications/Godot-4.6.1.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/plugins/playfab_analytics/test_playfab_analytics_plugin.gd`

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add plugins/playfab_analytics/game_plugin.gd specs/plugins/playfab_analytics/test_playfab_analytics_plugin.gd
git commit -m "feat(playfab): implement on_main_menu_displayed hook to track platform and version"
```

---

### Task 4: Add `_get_platform_string()` and dispatch in `game.gd`

**Files:**
- Modify: `src/game.gd:134` (add flag in State section), `src/game.gd:477-508` (modify `_show_main_menu`), add helper function

- [ ] **Step 1: Add the `_main_menu_event_sent` flag**

In `src/game.gd`, insert after line 141 (after `_play_ui_state_before_menu`):

```gdscript
var _main_menu_event_sent: bool = false
```

- [ ] **Step 2: Add the `_get_platform_string()` helper**

In `src/game.gd`, insert after the `_build_game_plugin_context()` function (after line 1064):

```gdscript

func _get_platform_string() -> String:
	var os_name := OS.get_name()
	if os_name == "Web":
		if GameSettings._is_mobile_browser():
			return "Web_mobile"
		return "Web_desktop"
	return os_name
```

- [ ] **Step 3: Add the dispatch call in `_show_main_menu()`**

In `src/game.gd`, at the end of the `_show_main_menu()` function (after line 507, which is the `_music_player.play_menu_music` block), insert:

```gdscript
	if not _main_menu_event_sent and _game_plugin_manager:
		_main_menu_event_sent = true
		var ctx = _build_game_plugin_context()
		var platform = _get_platform_string()
		var app_version = ProjectSettings.get_setting("application/config/version", "")
		var story_version = _current_story.version if _current_story and _current_story.get("version") != null else ""
		_game_plugin_manager.dispatch_on_main_menu_displayed(ctx, platform, app_version, story_version)
```

- [ ] **Step 4: Run all plugin tests to verify nothing is broken**

Run: `timeout 120 /Applications/Godot-4.6.1.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://specs/plugins/`

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add src/game.gd
git commit -m "feat(game): dispatch main_menu_displayed event once per session with platform and version info"
```

---

### Task 5: Run full test suite and verify

- [ ] **Step 1: Run all tests**

Run: `timeout 120 /Applications/Godot-4.6.1.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd`

Expected: All tests PASS, no regressions.

- [ ] **Step 2: Commit spec and plan docs**

```bash
git add docs/superpowers/specs/2026-04-03-playfab-main-menu-displayed-event-design.md docs/superpowers/plans/2026-04-03-playfab-main-menu-displayed-event.md
git commit -m "docs: add spec and plan for playfab main_menu_displayed event"
```
