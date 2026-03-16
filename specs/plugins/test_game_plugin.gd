extends GutTest

const VBGamePluginScript = preload("res://src/plugins/game_plugin.gd")
const GamePluginContextScript = preload("res://src/plugins/game_plugin_context.gd")


func _create_plugin() -> RefCounted:
	return VBGamePluginScript.new()


func _create_context() -> RefCounted:
	return GamePluginContextScript.new()


func test_default_name_is_empty():
	var plugin = _create_plugin()
	assert_eq(plugin.get_plugin_name(), "")


func test_default_description_is_empty():
	var plugin = _create_plugin()
	assert_eq(plugin.get_plugin_description(), "")


func test_default_is_configurable():
	var plugin = _create_plugin()
	assert_true(plugin.is_configurable())


func test_on_game_ready_does_not_crash():
	var plugin = _create_plugin()
	var ctx = _create_context()
	plugin.on_game_ready(ctx)
	assert_true(true, "on_game_ready should not crash")


func test_on_game_cleanup_does_not_crash():
	var plugin = _create_plugin()
	var ctx = _create_context()
	plugin.on_game_cleanup(ctx)
	assert_true(true, "on_game_cleanup should not crash")


func test_on_before_chapter_does_not_crash():
	var plugin = _create_plugin()
	var ctx = _create_context()
	plugin.on_before_chapter(ctx)
	assert_true(true)


func test_on_after_chapter_does_not_crash():
	var plugin = _create_plugin()
	var ctx = _create_context()
	plugin.on_after_chapter(ctx)
	assert_true(true)


func test_on_before_scene_does_not_crash():
	var plugin = _create_plugin()
	var ctx = _create_context()
	plugin.on_before_scene(ctx)
	assert_true(true)


func test_on_after_scene_does_not_crash():
	var plugin = _create_plugin()
	var ctx = _create_context()
	plugin.on_after_scene(ctx)
	assert_true(true)


func test_on_before_sequence_does_not_crash():
	var plugin = _create_plugin()
	var ctx = _create_context()
	plugin.on_before_sequence(ctx)
	assert_true(true)


func test_on_after_sequence_does_not_crash():
	var plugin = _create_plugin()
	var ctx = _create_context()
	plugin.on_after_sequence(ctx)
	assert_true(true)


func test_on_before_dialogue_returns_passthrough():
	var plugin = _create_plugin()
	var ctx = _create_context()
	var result = plugin.on_before_dialogue(ctx, "Alice", "Bonjour")
	assert_eq(result["character"], "Alice")
	assert_eq(result["text"], "Bonjour")


func test_on_after_dialogue_does_not_crash():
	var plugin = _create_plugin()
	var ctx = _create_context()
	plugin.on_after_dialogue(ctx, "Alice", "Bonjour")
	assert_true(true)


func test_on_before_choice_returns_passthrough():
	var plugin = _create_plugin()
	var ctx = _create_context()
	var choices = ["A", "B", "C"]
	var result = plugin.on_before_choice(ctx, choices)
	assert_eq(result, choices)


func test_on_after_choice_does_not_crash():
	var plugin = _create_plugin()
	var ctx = _create_context()
	plugin.on_after_choice(ctx, 0, "A")
	assert_true(true)


func test_get_toolbar_buttons_returns_empty():
	var plugin = _create_plugin()
	assert_eq(plugin.get_toolbar_buttons(), [])


func test_get_overlay_panels_returns_empty():
	var plugin = _create_plugin()
	assert_eq(plugin.get_overlay_panels(), [])


func test_get_options_controls_returns_empty():
	var plugin = _create_plugin()
	assert_eq(plugin.get_options_controls(), [])
