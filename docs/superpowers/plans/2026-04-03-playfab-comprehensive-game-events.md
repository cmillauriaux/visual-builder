# PlayFab Comprehensive Game Events — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a generic `on_game_event` plugin hook and 11 new analytics events to comprehensively track player behavior (options, links, ending screens, premium code, skip, auto-play, history, PWA, save deletion).

**Architecture:** One generic hook `on_game_event(ctx, event_name, data)` in the plugin system, implemented by PlayFab to forward to `track_event`. A `Callable` on `GamePluginContext` lets plugins (like premium_code) emit events without signals. UI scripts emit `external_link_opened` signals caught by game.gd.

**Tech Stack:** GDScript (Godot 4.6.1), GUT test framework, PlayFab REST API (via existing service)

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `src/plugins/game_plugin.gd` | Modify (line ~134) | Add `on_game_event` virtual hook |
| `src/plugins/game_plugin_manager.gd` | Modify (line ~276) | Add `dispatch_on_game_event` |
| `src/plugins/game_plugin_context.gd` | Modify (line ~34) | Add `emit_game_event: Callable` |
| `plugins/playfab_analytics/game_plugin.gd` | Modify (line ~173) | Implement `on_game_event` → `track_event` |
| `src/game.gd` | Modify (multiple) | Configure callable, connect signals, 8 direct dispatches |
| `src/ui/menu/main_menu.gd` | Modify (lines ~15, ~322-329) | Add+emit `external_link_opened` signal |
| `src/ui/menu/pause_menu.gd` | Modify (lines ~15, ~160-167) | Add+emit `external_link_opened` signal |
| `src/ui/menu/ending_screen.gd` | Modify (lines ~16, ~150-157) | Add+emit `external_link_opened` signal |
| `plugins/premium_code/game_plugin.gd` | Modify (lines ~276, ~298-304) | Use `ctx.emit_game_event` for tracking |
| `specs/plugins/test_game_plugin_manager.gd` | Modify | Tests for `dispatch_on_game_event` + update TestPlugin |
| `specs/plugins/playfab_analytics/test_playfab_analytics_plugin.gd` | Modify | Tests for `on_game_event` |

---

### Task 1: Add `on_game_event` hook to base class and manager (TDD)

**Files:**
- Modify: `src/plugins/game_plugin.gd:134` (after `on_main_menu_displayed`)
- Modify: `src/plugins/game_plugin_manager.gd:276` (after `dispatch_on_main_menu_displayed`)
- Test: `specs/plugins/test_game_plugin_manager.gd`

- [ ] **Step 1: Update TestPlugin and helper classes**

In `specs/plugins/test_game_plugin_manager.gd`, add to the `TestPlugin` inner class (after the `on_main_menu_displayed` method):

```gdscript
	func on_game_event(ctx, event_name: String, data: Dictionary):
		calls.append("game_event:" + event_name)
```

Add the same no-op to `_UpperPlugin`, `_PrefixPlugin`, `_ToolbarPlugin`, `_OverlayPlugin`:

```gdscript
	func on_game_event(_ctx, _e: String, _d: Dictionary): pass
```

- [ ] **Step 2: Write failing tests**

In `specs/plugins/test_game_plugin_manager.gd`, add after the `test_dispatch_on_main_menu_displayed_skips_disabled` test:

```gdscript
func test_dispatch_on_game_event():
	var p = TestPlugin.new("a")
	_manager.register_plugin(p)
	_manager.dispatch_on_game_event(_create_context(), "options_changed", {"language": "fr"})
	assert_has(p.calls, "game_event:options_changed")


func test_dispatch_on_game_event_skips_disabled():
	var p = TestPlugin.new("a")
	_manager.register_plugin(p)
	_manager.set_plugin_enabled("a", false)
	_manager.dispatch_on_game_event(_create_context(), "options_changed", {"language": "fr"})
	assert_does_not_have(p.calls, "game_event:options_changed")
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `timeout 120 /Applications/Godot-4.6.1.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/plugins/test_game_plugin_manager.gd`

Expected: FAIL — `dispatch_on_game_event` does not exist.

- [ ] **Step 4: Add the hook to base class**

In `src/plugins/game_plugin.gd`, insert after line 134 (after `on_main_menu_displayed`):

```gdscript

## Hook générique pour les événements analytics (options, liens, écrans de fin, etc.).
func on_game_event(ctx: RefCounted, event_name: String, data: Dictionary) -> void:
	pass
```

- [ ] **Step 5: Add the dispatch to manager**

In `src/plugins/game_plugin_manager.gd`, insert after line 275 (after `dispatch_on_main_menu_displayed`):

```gdscript

func dispatch_on_game_event(ctx: RefCounted, event_name: String, data: Dictionary) -> void:
	for plugin in _get_active_plugins():
		plugin.on_game_event(ctx, event_name, data)
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `timeout 120 /Applications/Godot-4.6.1.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/plugins/test_game_plugin_manager.gd`

Expected: All tests PASS.

- [ ] **Step 7: Commit**

```bash
git add src/plugins/game_plugin.gd src/plugins/game_plugin_manager.gd specs/plugins/test_game_plugin_manager.gd
git commit -m "feat(plugins): add generic on_game_event hook and dispatch"
```

---

### Task 2: Add `emit_game_event` Callable to GamePluginContext

**Files:**
- Modify: `src/plugins/game_plugin_context.gd:34` (end of file)

- [ ] **Step 1: Add the property**

In `src/plugins/game_plugin_context.gd`, append at the end of the file (after line 34):

```gdscript

## Callable pour émettre un game event depuis un plugin.
## Signature : func(event_name: String, data: Dictionary) -> void
var emit_game_event: Callable = Callable()
```

- [ ] **Step 2: Configure the callable in game.gd**

In `src/game.gd`, in the `_build_game_plugin_context()` function (around line 1060-1072), add before the `return ctx` line:

```gdscript
	ctx.emit_game_event = func(event_name: String, data: Dictionary):
		if _game_plugin_manager:
			_game_plugin_manager.dispatch_on_game_event(ctx, event_name, data)
```

- [ ] **Step 3: Run plugin tests to verify nothing broken**

Run: `timeout 120 /Applications/Godot-4.6.1.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://specs/plugins/`

Expected: All tests PASS.

- [ ] **Step 4: Commit**

```bash
git add src/plugins/game_plugin_context.gd src/game.gd
git commit -m "feat(plugins): add emit_game_event callable to GamePluginContext"
```

---

### Task 3: Implement `on_game_event` in PlayFab plugin (TDD)

**Files:**
- Modify: `plugins/playfab_analytics/game_plugin.gd:173` (after `on_main_menu_displayed`)
- Test: `specs/plugins/playfab_analytics/test_playfab_analytics_plugin.gd`

- [ ] **Step 1: Write the test**

In `specs/plugins/playfab_analytics/test_playfab_analytics_plugin.gd`, add after `test_on_main_menu_displayed_safe_without_service`:

```gdscript
func test_on_game_event_safe_without_service():
	var ctx = _create_context()
	_plugin.on_game_event(ctx, "options_changed", {"language": "fr"})
	assert_null(_plugin.get_service())
	ctx.game_node.queue_free()
```

- [ ] **Step 2: Run tests to confirm new test passes (base class no-op)**

Run: `timeout 30 /Applications/Godot-4.6.1.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/plugins/playfab_analytics/test_playfab_analytics_plugin.gd`

Expected: PASS.

- [ ] **Step 3: Implement the hook**

In `plugins/playfab_analytics/game_plugin.gd`, insert after line 173 (after `on_main_menu_displayed`):

```gdscript

func on_game_event(_ctx: RefCounted, event_name: String, data: Dictionary) -> void:
	if _service == null or not _service.is_active():
		return
	_service.track_event(event_name, data)
```

- [ ] **Step 4: Run tests**

Run: `timeout 30 /Applications/Godot-4.6.1.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/plugins/playfab_analytics/test_playfab_analytics_plugin.gd`

Expected: All PASS.

- [ ] **Step 5: Commit**

```bash
git add plugins/playfab_analytics/game_plugin.gd specs/plugins/playfab_analytics/test_playfab_analytics_plugin.gd
git commit -m "feat(playfab): implement on_game_event to forward all analytics events"
```

---

### Task 4: Add `external_link_opened` signal to UI scripts

**Files:**
- Modify: `src/ui/menu/main_menu.gd:15,322-329`
- Modify: `src/ui/menu/pause_menu.gd:15,160-167`
- Modify: `src/ui/menu/ending_screen.gd:16,150-157`

- [ ] **Step 1: Add signal and emit in main_menu.gd**

In `src/ui/menu/main_menu.gd`, add signal after existing signals (after line 19):

```gdscript
signal external_link_opened(link_type: String, context: String)
```

Modify `_on_patreon_pressed()` (line 322-324):

```gdscript
func _on_patreon_pressed() -> void:
	if _current_story and _current_story.patreon_url != "":
		OS.shell_open(_current_story.patreon_url)
		external_link_opened.emit("patreon", "main_menu")
```

Modify `_on_itchio_pressed()` (line 327-329):

```gdscript
func _on_itchio_pressed() -> void:
	if _current_story and _current_story.itchio_url != "":
		OS.shell_open(_current_story.itchio_url)
		external_link_opened.emit("itchio", "main_menu")
```

- [ ] **Step 2: Add signal and emit in pause_menu.gd**

In `src/ui/menu/pause_menu.gd`, add signal after existing signals (after line 21):

```gdscript
signal external_link_opened(link_type: String, context: String)
```

Modify `_on_patreon_pressed()` (line 160-162):

```gdscript
func _on_patreon_pressed() -> void:
	if _patreon_url != "":
		OS.shell_open(_patreon_url)
		external_link_opened.emit("patreon", "pause")
```

Modify `_on_itchio_pressed()` (line 165-167):

```gdscript
func _on_itchio_pressed() -> void:
	if _itchio_url != "":
		OS.shell_open(_itchio_url)
		external_link_opened.emit("itchio", "pause")
```

- [ ] **Step 3: Add signal and emit in ending_screen.gd**

In `src/ui/menu/ending_screen.gd`, add signal after existing signals (after line 17):

```gdscript
signal external_link_opened(link_type: String, context: String)
```

Modify `_on_patreon_pressed()` (line 150-152):

```gdscript
func _on_patreon_pressed() -> void:
	if _patreon_url != "":
		OS.shell_open(_patreon_url)
		external_link_opened.emit("patreon", "ending")
```

Modify `_on_itchio_pressed()` (line 155-157):

```gdscript
func _on_itchio_pressed() -> void:
	if _itchio_url != "":
		OS.shell_open(_itchio_url)
		external_link_opened.emit("itchio", "ending")
```

- [ ] **Step 4: Run tests to verify no regressions**

Run: `timeout 120 /Applications/Godot-4.6.1.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://specs/`

Expected: No new failures.

- [ ] **Step 5: Commit**

```bash
git add src/ui/menu/main_menu.gd src/ui/menu/pause_menu.gd src/ui/menu/ending_screen.gd
git commit -m "feat(ui): add external_link_opened signal to main menu, pause menu, ending screen"
```

---

### Task 5: Add `emit_game_event` calls to premium_code plugin

**Files:**
- Modify: `plugins/premium_code/game_plugin.gd:276,298-304`

- [ ] **Step 1: Add tracking to the purchase link button**

In `plugins/premium_code/game_plugin.gd`, modify line 276 (inside `_show_code_popup`). Replace:

```gdscript
		link_btn.pressed.connect(func(): OS.shell_open(purchase_url))
```

With:

```gdscript
		link_btn.pressed.connect(func():
			OS.shell_open(purchase_url)
			if ctx.emit_game_event.is_valid():
				ctx.emit_game_event.call("premium_code_purchase_link", {"url": purchase_url})
				ctx.emit_game_event.call("external_link_opened", {"link_type": "itchio", "context": "premium_code"})
		)
```

- [ ] **Step 2: Add tracking to code validation**

In `plugins/premium_code/game_plugin.gd`, modify the `on_validate` callable (around line 292-305). Replace:

```gdscript
	var on_validate := func():
		var code := code_input.text.strip_edges()
		if code == "":
			error_label.text = "Veuillez entrer un code."
			error_label.visible = true
			return
		if _is_code_valid(code):
			_add_validated_code(code)
			overlay.get_tree().paused = false
			overlay.queue_free()
			_popup = null
		else:
			error_label.text = "Code invalide."
			error_label.visible = true
```

With:

```gdscript
	var chapter_uuid: String = ctx.current_chapter.uuid if ctx.current_chapter else ""
	var on_validate := func():
		var code := code_input.text.strip_edges()
		if code == "":
			error_label.text = "Veuillez entrer un code."
			error_label.visible = true
			return
		if _is_code_valid(code):
			_add_validated_code(code)
			if ctx.emit_game_event.is_valid():
				ctx.emit_game_event.call("premium_code_attempt", {"success": true, "chapter_uuid": chapter_uuid})
			overlay.get_tree().paused = false
			overlay.queue_free()
			_popup = null
		else:
			error_label.text = "Code invalide."
			error_label.visible = true
			if ctx.emit_game_event.is_valid():
				ctx.emit_game_event.call("premium_code_attempt", {"success": false, "chapter_uuid": chapter_uuid})
```

- [ ] **Step 3: Run premium_code tests**

Run: `timeout 30 /Applications/Godot-4.6.1.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://specs/plugins/premium_code/`

Expected: All PASS.

- [ ] **Step 4: Commit**

```bash
git add plugins/premium_code/game_plugin.gd
git commit -m "feat(premium_code): emit analytics events for code attempts and purchase links"
```

---

### Task 6: Wire up signal connections and direct dispatches in game.gd

**Files:**
- Modify: `src/game.gd` (signal connections ~line 237-244, handlers, new dispatches)

- [ ] **Step 1: Connect external_link_opened signals**

In `src/game.gd`, after line 244 (after `_game_over_screen.load_last_autosave_pressed.connect(...)`), add:

```gdscript
	_main_menu.external_link_opened.connect(_on_external_link_opened)
	_pause_menu.external_link_opened.connect(_on_external_link_opened)
	_game_over_screen.external_link_opened.connect(_on_external_link_opened)
	_to_be_continued_screen.external_link_opened.connect(_on_external_link_opened)
```

- [ ] **Step 2: Add the `_on_external_link_opened` handler**

In `src/game.gd`, after the `_on_pwa_prompt_closed` function (after line 1263), add:

```gdscript

func _on_external_link_opened(link_type: String, context: String) -> void:
	if _game_plugin_manager:
		var ctx = _build_game_plugin_context()
		_game_plugin_manager.dispatch_on_game_event(ctx, "external_link_opened", {
			"link_type": link_type,
			"context": context,
		})
```

- [ ] **Step 3: Add `options_changed` dispatch**

In `src/game.gd`, at the end of `_on_options_applied()` (after line 470, after `_play_ctrl.set_voice_language(...)`), add:

```gdscript
	if _game_plugin_manager:
		var ctx = _build_game_plugin_context()
		_game_plugin_manager.dispatch_on_game_event(ctx, "options_changed", {
			"music_enabled": _settings.music_enabled,
			"music_volume": _settings.music_volume,
			"voice_enabled": _settings.voice_enabled,
			"voice_volume": _settings.voice_volume,
			"voice_language": _settings.voice_language,
			"fx_enabled": _settings.fx_enabled,
			"fx_volume": _settings.fx_volume,
			"language": _settings.language,
			"fullscreen": _settings.fullscreen,
			"auto_play_enabled": _settings.auto_play_enabled,
			"auto_play_delay": _settings.auto_play_delay,
			"typewriter_speed": _settings.typewriter_speed,
			"dialogue_opacity": _settings.dialogue_opacity,
			"autosave_enabled": _settings.autosave_enabled,
			"ui_scale_mode": _settings.ui_scale_mode,
			"toolbar_visible": _settings.toolbar_visible,
		})
```

**Important:** This must be added BEFORE the early return on line 460 (`get_tree().reload_current_scene(); return`). The options_changed event should only fire when options are applied WITHOUT a scene reload. If there's a UI scale change, the scene reloads and options_applied will be called again from the new scene — the event will fire then. So placing it at the END of the function (after line 470) is correct.

- [ ] **Step 4: Add `ending_screen_displayed` dispatch**

In `src/game.gd`, in `_on_analytics_story_finished(reason)` (line 1165-1168), add after the existing dispatch:

```gdscript
func _on_analytics_story_finished(reason: String) -> void:
	if _game_plugin_manager:
		var ctx = _build_game_plugin_context()
		_game_plugin_manager.dispatch_on_story_finished(ctx, reason)
		if reason == "game_over" or reason == "to_be_continued":
			_game_plugin_manager.dispatch_on_game_event(ctx, "ending_screen_displayed", {
				"type": reason,
			})
```

- [ ] **Step 5: Add `ending_screen_action` dispatches**

In `src/game.gd`, modify `_on_play_finished_return()` (line 565-571). This is called from both ending screens' `back_to_menu_pressed` AND from `play_finished_show_menu`. We need to detect which ending screen was visible. Replace:

```gdscript
func _on_play_finished_return() -> void:
	_game_over_screen.hide_screen()
	_to_be_continued_screen.hide_screen()
	if _current_story:
		_show_main_menu(_current_story)
	else:
		_show_story_selector()
```

With:

```gdscript
func _on_play_finished_return() -> void:
	if _game_plugin_manager:
		var ending_type := ""
		if _game_over_screen.visible:
			ending_type = "game_over"
		elif _to_be_continued_screen.visible:
			ending_type = "to_be_continued"
		if ending_type != "":
			var ctx = _build_game_plugin_context()
			_game_plugin_manager.dispatch_on_game_event(ctx, "ending_screen_action", {
				"type": ending_type,
				"action": "back_to_menu",
			})
	_game_over_screen.hide_screen()
	_to_be_continued_screen.hide_screen()
	if _current_story:
		_show_main_menu(_current_story)
	else:
		_show_story_selector()
```

Modify `_on_game_over_load_autosave()` (line 574-580). Replace:

```gdscript
func _on_game_over_load_autosave() -> void:
	_game_over_screen.hide_screen()
	var autosaves := GameSaveManager.list_autosaves()
	if autosaves.is_empty():
		return
	var latest_slot: int = autosaves[0]["slot_index"]
	_on_load_slot(-(latest_slot + 2))
```

With:

```gdscript
func _on_game_over_load_autosave() -> void:
	if _game_plugin_manager:
		var ctx = _build_game_plugin_context()
		_game_plugin_manager.dispatch_on_game_event(ctx, "ending_screen_action", {
			"type": "game_over",
			"action": "load_autosave",
		})
	_game_over_screen.hide_screen()
	var autosaves := GameSaveManager.list_autosaves()
	if autosaves.is_empty():
		return
	var latest_slot: int = autosaves[0]["slot_index"]
	_on_load_slot(-(latest_slot + 2))
```

- [ ] **Step 6: Add `save_deleted` dispatch**

In `src/game.gd`, modify `_on_delete_slot(slot_index)` (line 909-911). Replace:

```gdscript
func _on_delete_slot(slot_index: int) -> void:
	GameSaveManager.delete_save(slot_index)
	_save_load_menu.refresh()
```

With:

```gdscript
func _on_delete_slot(slot_index: int) -> void:
	GameSaveManager.delete_save(slot_index)
	_save_load_menu.refresh()
	if _game_plugin_manager:
		var ctx = _build_game_plugin_context()
		_game_plugin_manager.dispatch_on_game_event(ctx, "save_deleted", {
			"slot_index": slot_index,
		})
```

- [ ] **Step 7: Add `pwa_prompt_response` dispatch**

In `src/game.gd`, modify `_on_pwa_prompt_closed(dont_show_again)` (line 1259-1262). Replace:

```gdscript
func _on_pwa_prompt_closed(dont_show_again: bool) -> void:
	if dont_show_again:
		_settings.pwa_prompt_dismissed = true
		_settings.save_settings()
```

With:

```gdscript
func _on_pwa_prompt_closed(dont_show_again: bool) -> void:
	if _game_plugin_manager:
		var ctx = _build_game_plugin_context()
		var platform := "unknown"
		if _pwa_install_prompt and _pwa_install_prompt.has_method("get_platform_name"):
			platform = _pwa_install_prompt.get_platform_name()
		else:
			platform = _get_platform_string()
		_game_plugin_manager.dispatch_on_game_event(ctx, "pwa_prompt_response", {
			"dismissed": dont_show_again,
			"platform": platform,
		})
	if dont_show_again:
		_settings.pwa_prompt_dismissed = true
		_settings.save_settings()
```

- [ ] **Step 8: Commit**

```bash
git add src/game.gd
git commit -m "feat(game): wire up external links, options, ending screens, save delete, PWA dispatches"
```

---

### Task 7: Wire up skip, auto-play, and history dispatches in game_play_controller

**Files:**
- Modify: `src/controllers/game_play_controller.gd:631,698,732`

The play controller doesn't have direct access to the plugin manager. But it already has `_game_plugin_manager` and `_plugin_ctx` references (set from game.gd). We'll use these to dispatch events.

- [ ] **Step 1: Add `skip_used` dispatch**

In `src/controllers/game_play_controller.gd`, modify `execute_skip()` (line 698-707). Replace:

```gdscript
func execute_skip() -> void:
	if _skip_button == null or _skip_button.disabled:
		return
	if not _sequence_editor_ctrl.is_playing():
		return
	_typewriter_timer.stop()
	if _auto_play:
		_auto_play.stop_timer()
	_sequence_editor_ctrl.skip_to_end()
	_handle_play_stopped()
```

With:

```gdscript
func execute_skip() -> void:
	if _skip_button == null or _skip_button.disabled:
		return
	if not _sequence_editor_ctrl.is_playing():
		return
	if _game_plugin_manager and _plugin_ctx:
		var ch = _story_play_ctrl.get_current_chapter() if _story_play_ctrl else null
		var sc = _story_play_ctrl.get_current_scene() if _story_play_ctrl else null
		var seq = _story_play_ctrl.get_current_sequence() if _story_play_ctrl else null
		_game_plugin_manager.dispatch_on_game_event(_plugin_ctx, "skip_used", {
			"chapter": ch.chapter_name if ch else "",
			"scene": sc.scene_name if sc else "",
			"sequence": seq.seq_name if seq else "",
		})
	_typewriter_timer.stop()
	if _auto_play:
		_auto_play.stop_timer()
	_sequence_editor_ctrl.skip_to_end()
	_handle_play_stopped()
```

- [ ] **Step 2: Add `auto_play_toggled` dispatch**

In `src/controllers/game_play_controller.gd`, modify `_on_auto_play_toggled(active)` (line 631-641). Add dispatch at the start:

```gdscript
func _on_auto_play_toggled(active: bool) -> void:
	if _game_plugin_manager and _plugin_ctx:
		_game_plugin_manager.dispatch_on_game_event(_plugin_ctx, "auto_play_toggled", {
			"enabled": active,
			"delay": _auto_play.delay if _auto_play else 0.0,
		})
	if _auto_play_button:
		_auto_play_button.text = StoryI18nService.get_ui_string("Auto [ON]" if active else "Auto", _i18n)
		if active:
			_auto_play_button.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
		else:
			_auto_play_button.remove_theme_color_override("font_color")
	if active and _sequence_editor_ctrl.is_playing() and _sequence_editor_ctrl.is_text_fully_displayed():
		_try_start_auto_play_timer()
	elif not active:
		_cancel_voice_auto_play_wait()
```

- [ ] **Step 3: Add `history_opened` dispatch**

In `src/controllers/game_play_controller.gd`, modify `open_history()` (line 732-738). Replace:

```gdscript
func open_history() -> void:
	if _history_open:
		close_history()
		return
	_history_open = true
	_update_history_button_text()
	_show_history_panel()
```

With:

```gdscript
func open_history() -> void:
	if _history_open:
		close_history()
		return
	_history_open = true
	_update_history_button_text()
	_show_history_panel()
	if _game_plugin_manager and _plugin_ctx:
		_game_plugin_manager.dispatch_on_game_event(_plugin_ctx, "history_opened", {
			"entry_count": _dialogue_history.size(),
		})
```

- [ ] **Step 4: Run tests**

Run: `timeout 120 /Applications/Godot-4.6.1.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://specs/`

Expected: No new failures.

- [ ] **Step 5: Commit**

```bash
git add src/controllers/game_play_controller.gd
git commit -m "feat(play): add skip_used, auto_play_toggled, history_opened analytics events"
```

---

### Task 8: Run full test suite and commit docs

- [ ] **Step 1: Run all tests**

Run: `timeout 120 /Applications/Godot-4.6.1.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd`

Expected: All tests PASS, no regressions beyond pre-existing failures.

- [ ] **Step 2: Commit spec and plan**

```bash
git add docs/superpowers/specs/2026-04-03-playfab-comprehensive-game-events-design.md docs/superpowers/plans/2026-04-03-playfab-comprehensive-game-events.md
git commit -m "docs: add spec and plan for comprehensive PlayFab game events"
```
