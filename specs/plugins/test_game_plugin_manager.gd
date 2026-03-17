extends GutTest

const GamePluginManagerScript = preload("res://src/plugins/game_plugin_manager.gd")
const VBGamePluginScript = preload("res://src/plugins/game_plugin.gd")
const GamePluginContextScript = preload("res://src/plugins/game_plugin_context.gd")
const GameContributions = preload("res://src/plugins/game_contributions.gd")

var _manager: Node


func before_each():
	_manager = Node.new()
	_manager.set_script(GamePluginManagerScript)
	add_child(_manager)


func after_each():
	_manager.queue_free()


func _create_context() -> RefCounted:
	return GamePluginContextScript.new()


# --- Helper : plugin de test ---

class TestPlugin extends RefCounted:
	var _name: String
	var _configurable: bool
	var calls: Array = []

	func _init(p_name: String = "test", p_configurable: bool = true):
		_name = p_name
		_configurable = p_configurable

	func get_plugin_name() -> String: return _name
	func get_plugin_description() -> String: return "Plugin " + _name
	func is_configurable() -> bool: return _configurable
	func on_game_ready(ctx): calls.append("game_ready")
	func on_game_cleanup(ctx): calls.append("game_cleanup")
	func on_before_chapter(ctx): calls.append("before_chapter")
	func on_after_chapter(ctx): calls.append("after_chapter")
	func on_before_scene(ctx): calls.append("before_scene")
	func on_after_scene(ctx): calls.append("after_scene")
	func on_before_sequence(ctx): calls.append("before_sequence")
	func on_after_sequence(ctx): calls.append("after_sequence")
	func on_before_dialogue(ctx, character: String, text: String) -> Dictionary:
		calls.append("before_dialogue")
		return {"character": character, "text": text}
	func on_after_dialogue(ctx, character: String, text: String):
		calls.append("after_dialogue")
	func on_before_choice(ctx, choices: Array) -> Array:
		calls.append("before_choice")
		return choices
	func on_after_choice(ctx, idx: int, text: String):
		calls.append("after_choice")
	func get_toolbar_buttons() -> Array: return []
	func get_overlay_panels() -> Array: return []
	func get_options_controls() -> Array: return []


# --- Tests enregistrement ---

func test_initial_plugin_count_is_zero():
	assert_eq(_manager.get_plugin_count(), 0)


func test_register_plugin_increments_count():
	var p = TestPlugin.new("a")
	_manager.register_plugin(p)
	assert_eq(_manager.get_plugin_count(), 1)


func test_register_multiple_plugins():
	_manager.register_plugin(TestPlugin.new("a"))
	_manager.register_plugin(TestPlugin.new("b"))
	assert_eq(_manager.get_plugin_count(), 2)


# --- Tests enabled/disabled ---

func test_plugin_enabled_by_default():
	var p = TestPlugin.new("a")
	_manager.register_plugin(p)
	assert_true(_manager.is_plugin_enabled("a"))


func test_set_plugin_disabled():
	var p = TestPlugin.new("a")
	_manager.register_plugin(p)
	_manager.set_plugin_enabled("a", false)
	assert_false(_manager.is_plugin_enabled("a"))


func test_set_plugin_reenabled():
	var p = TestPlugin.new("a")
	_manager.register_plugin(p)
	_manager.set_plugin_enabled("a", false)
	_manager.set_plugin_enabled("a", true)
	assert_true(_manager.is_plugin_enabled("a"))


func test_get_configurable_plugins():
	_manager.register_plugin(TestPlugin.new("a", true))
	_manager.register_plugin(TestPlugin.new("b", false))
	var configurables = _manager.get_configurable_plugins()
	assert_eq(configurables.size(), 1)
	assert_eq(configurables[0].get_plugin_name(), "a")


# --- Tests dispatch hooks ---

func test_dispatch_on_game_ready():
	var p = TestPlugin.new("a")
	_manager.register_plugin(p)
	_manager.dispatch_on_game_ready(_create_context())
	assert_has(p.calls, "game_ready")


func test_dispatch_on_before_chapter():
	var p = TestPlugin.new("a")
	_manager.register_plugin(p)
	_manager.dispatch_on_before_chapter(_create_context())
	assert_has(p.calls, "before_chapter")


func test_dispatch_on_after_chapter():
	var p = TestPlugin.new("a")
	_manager.register_plugin(p)
	_manager.dispatch_on_after_chapter(_create_context())
	assert_has(p.calls, "after_chapter")


func test_dispatch_on_before_scene():
	var p = TestPlugin.new("a")
	_manager.register_plugin(p)
	_manager.dispatch_on_before_scene(_create_context())
	assert_has(p.calls, "before_scene")


func test_dispatch_on_after_scene():
	var p = TestPlugin.new("a")
	_manager.register_plugin(p)
	_manager.dispatch_on_after_scene(_create_context())
	assert_has(p.calls, "after_scene")


func test_dispatch_on_before_sequence():
	var p = TestPlugin.new("a")
	_manager.register_plugin(p)
	_manager.dispatch_on_before_sequence(_create_context())
	assert_has(p.calls, "before_sequence")


func test_dispatch_on_after_sequence():
	var p = TestPlugin.new("a")
	_manager.register_plugin(p)
	_manager.dispatch_on_after_sequence(_create_context())
	assert_has(p.calls, "after_sequence")


# --- Tests disabled plugins not dispatched ---

func test_disabled_plugin_not_dispatched():
	var p = TestPlugin.new("a")
	_manager.register_plugin(p)
	_manager.set_plugin_enabled("a", false)
	_manager.dispatch_on_game_ready(_create_context())
	_manager.dispatch_on_before_chapter(_create_context())
	_manager.dispatch_on_before_dialogue(_create_context(), "X", "Y") if false else null
	assert_eq(p.calls, [])


func test_disabled_plugin_skipped_in_pipeline():
	var p = TestPlugin.new("a")
	_manager.register_plugin(p)
	_manager.set_plugin_enabled("a", false)
	var result = _manager.pipeline_before_dialogue(_create_context(), "Alice", "Hi")
	assert_eq(result["character"], "Alice")
	assert_eq(result["text"], "Hi")
	assert_eq(p.calls, [])


# --- Tests pipeline dialogue ---

func test_pipeline_before_dialogue_passthrough():
	var p = TestPlugin.new("a")
	_manager.register_plugin(p)
	var result = _manager.pipeline_before_dialogue(_create_context(), "Alice", "Bonjour")
	assert_eq(result["character"], "Alice")
	assert_eq(result["text"], "Bonjour")
	assert_has(p.calls, "before_dialogue")


func test_pipeline_before_dialogue_chained():
	# Plugin that uppercases text
	var p1 = TestPlugin.new("upper")
	p1.set_script(null)

	# Use a proper approach: two actual plugin instances with custom behavior
	var upper_plugin = _UpperPlugin.new()
	var prefix_plugin = _PrefixPlugin.new()
	_manager.register_plugin(upper_plugin)
	_manager.register_plugin(prefix_plugin)
	var result = _manager.pipeline_before_dialogue(_create_context(), "Alice", "hello")
	# upper first → "HELLO", then prefix → "[MOD] HELLO"
	assert_eq(result["text"], "[MOD] HELLO")


func test_dispatch_on_after_dialogue():
	var p = TestPlugin.new("a")
	_manager.register_plugin(p)
	_manager.dispatch_on_after_dialogue(_create_context(), "Alice", "Hi")
	assert_has(p.calls, "after_dialogue")


# --- Tests pipeline choix ---

func test_pipeline_before_choice_passthrough():
	var p = TestPlugin.new("a")
	_manager.register_plugin(p)
	var choices = ["A", "B"]
	var result = _manager.pipeline_before_choice(_create_context(), choices)
	assert_eq(result, choices)


func test_dispatch_on_after_choice():
	var p = TestPlugin.new("a")
	_manager.register_plugin(p)
	_manager.dispatch_on_after_choice(_create_context(), 1, "B")
	assert_has(p.calls, "after_choice")


# --- Tests scan résilient ---

func test_scan_nonexistent_directory_does_not_crash():
	_manager.scan_and_load_plugins(["res://nonexistent_dir_xyz/"])
	assert_eq(_manager.get_plugin_count(), 0)


# --- Tests UI injection ---

func test_inject_toolbar_buttons_null_container():
	_manager.inject_toolbar_buttons(null, _create_context())
	assert_true(true, "Should not crash with null container")


func test_inject_overlay_panels_null_containers():
	_manager.inject_overlay_panels(null, null, null, _create_context())
	assert_true(true, "Should not crash with null containers")


func test_inject_options_controls_null_container():
	_manager.inject_options_controls(null, null)
	assert_true(true, "Should not crash with null container")


func test_inject_toolbar_buttons_creates_buttons():
	var plugin = _ToolbarPlugin.new()
	_manager.register_plugin(plugin)
	var container = HBoxContainer.new()
	add_child(container)
	_manager.inject_toolbar_buttons(container, _create_context())
	assert_eq(container.get_child_count(), 1)
	assert_eq(container.get_child(0).text, "MyBtn")
	assert_true(container.visible)
	container.queue_free()


func test_inject_toolbar_empty_hides_container():
	var container = HBoxContainer.new()
	add_child(container)
	_manager.inject_toolbar_buttons(container, _create_context())
	assert_false(container.visible)
	container.queue_free()


func test_inject_overlay_panels_creates_panels():
	var plugin = _OverlayPlugin.new()
	_manager.register_plugin(plugin)
	var left = VBoxContainer.new()
	var right = VBoxContainer.new()
	var top = HBoxContainer.new()
	add_child(left)
	add_child(right)
	add_child(top)
	_manager.inject_overlay_panels(left, right, top, _create_context())
	assert_eq(right.get_child_count(), 1)
	assert_true(right.visible)
	assert_eq(left.get_child_count(), 0)
	left.queue_free()
	right.queue_free()
	top.queue_free()


# --- Tests enabled states persistence ---

func test_load_enabled_states_from_settings():
	var settings = _FakeSettings.new()
	settings.game_plugins_enabled = {"my_plugin": false}
	_manager.load_enabled_states(settings)
	assert_false(_manager.is_plugin_enabled("my_plugin"))


func test_save_enabled_states_to_settings():
	var settings = _FakeSettings.new()
	_manager.register_plugin(TestPlugin.new("a"))
	_manager.set_plugin_enabled("a", false)
	_manager.save_enabled_states(settings)
	assert_false(settings.game_plugins_enabled["a"])


func test_load_null_settings_does_not_crash():
	_manager.load_enabled_states(null)
	assert_true(true)


# --- Helper plugins for pipeline tests ---

class _UpperPlugin extends RefCounted:
	func get_plugin_name() -> String: return "upper"
	func get_plugin_description() -> String: return ""
	func is_configurable() -> bool: return true
	func on_game_ready(_ctx): pass
	func on_game_cleanup(_ctx): pass
	func on_before_chapter(_ctx): pass
	func on_after_chapter(_ctx): pass
	func on_before_scene(_ctx): pass
	func on_after_scene(_ctx): pass
	func on_before_sequence(_ctx): pass
	func on_after_sequence(_ctx): pass
	func on_before_dialogue(_ctx, character: String, text: String) -> Dictionary:
		return {"character": character, "text": text.to_upper()}
	func on_after_dialogue(_ctx, _c: String, _t: String): pass
	func on_before_choice(_ctx, choices: Array) -> Array: return choices
	func on_after_choice(_ctx, _i: int, _t: String): pass
	func get_toolbar_buttons() -> Array: return []
	func get_overlay_panels() -> Array: return []
	func get_options_controls() -> Array: return []


class _PrefixPlugin extends RefCounted:
	func get_plugin_name() -> String: return "prefix"
	func get_plugin_description() -> String: return ""
	func is_configurable() -> bool: return true
	func on_game_ready(_ctx): pass
	func on_game_cleanup(_ctx): pass
	func on_before_chapter(_ctx): pass
	func on_after_chapter(_ctx): pass
	func on_before_scene(_ctx): pass
	func on_after_scene(_ctx): pass
	func on_before_sequence(_ctx): pass
	func on_after_sequence(_ctx): pass
	func on_before_dialogue(_ctx, character: String, text: String) -> Dictionary:
		return {"character": character, "text": "[MOD] " + text}
	func on_after_dialogue(_ctx, _c: String, _t: String): pass
	func on_before_choice(_ctx, choices: Array) -> Array: return choices
	func on_after_choice(_ctx, _i: int, _t: String): pass
	func get_toolbar_buttons() -> Array: return []
	func get_overlay_panels() -> Array: return []
	func get_options_controls() -> Array: return []


class _ToolbarPlugin extends RefCounted:
	func get_plugin_name() -> String: return "toolbar_test"
	func get_plugin_description() -> String: return ""
	func is_configurable() -> bool: return true
	func on_game_ready(_ctx): pass
	func on_game_cleanup(_ctx): pass
	func on_before_chapter(_ctx): pass
	func on_after_chapter(_ctx): pass
	func on_before_scene(_ctx): pass
	func on_after_scene(_ctx): pass
	func on_before_sequence(_ctx): pass
	func on_after_sequence(_ctx): pass
	func on_before_dialogue(_ctx, c: String, t: String) -> Dictionary: return {"character": c, "text": t}
	func on_after_dialogue(_ctx, _c: String, _t: String): pass
	func on_before_choice(_ctx, choices: Array) -> Array: return choices
	func on_after_choice(_ctx, _i: int, _t: String): pass
	func get_toolbar_buttons() -> Array:
		var btn = GameContributions.GameToolbarButton.new()
		btn.label = "MyBtn"
		btn.callback = func(_ctx): pass
		return [btn]
	func get_overlay_panels() -> Array: return []
	func get_options_controls() -> Array: return []


class _OverlayPlugin extends RefCounted:
	func get_plugin_name() -> String: return "overlay_test"
	func get_plugin_description() -> String: return ""
	func is_configurable() -> bool: return true
	func on_game_ready(_ctx): pass
	func on_game_cleanup(_ctx): pass
	func on_before_chapter(_ctx): pass
	func on_after_chapter(_ctx): pass
	func on_before_scene(_ctx): pass
	func on_after_scene(_ctx): pass
	func on_before_sequence(_ctx): pass
	func on_after_sequence(_ctx): pass
	func on_before_dialogue(_ctx, c: String, t: String) -> Dictionary: return {"character": c, "text": t}
	func on_after_dialogue(_ctx, _c: String, _t: String): pass
	func on_before_choice(_ctx, choices: Array) -> Array: return choices
	func on_after_choice(_ctx, _i: int, _t: String): pass
	func get_toolbar_buttons() -> Array: return []
	func get_overlay_panels() -> Array:
		var def = GameContributions.GameOverlayPanelDef.new()
		def.position = "right"
		def.create_panel = func(_ctx): return Label.new()
		return [def]
	func get_options_controls() -> Array: return []


class _FakeSettings extends RefCounted:
	var game_plugins_enabled: Dictionary = {}
	func save_settings(_path: String = "") -> void: pass
