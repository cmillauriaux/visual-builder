extends GutTest

const GamePluginContextScript = preload("res://src/plugins/game_plugin_context.gd")


func _create_context() -> RefCounted:
	return GamePluginContextScript.new()


func test_default_story_is_null():
	var ctx = _create_context()
	assert_null(ctx.story)


func test_default_story_base_path_is_empty():
	var ctx = _create_context()
	assert_eq(ctx.story_base_path, "")


func test_default_current_chapter_is_null():
	var ctx = _create_context()
	assert_null(ctx.current_chapter)


func test_default_current_scene_is_null():
	var ctx = _create_context()
	assert_null(ctx.current_scene)


func test_default_current_sequence_is_null():
	var ctx = _create_context()
	assert_null(ctx.current_sequence)


func test_default_current_dialogue_index():
	var ctx = _create_context()
	assert_eq(ctx.current_dialogue_index, -1)


func test_default_variables_is_empty():
	var ctx = _create_context()
	assert_eq(ctx.variables, {})


func test_default_game_node_is_null():
	var ctx = _create_context()
	assert_null(ctx.game_node)


func test_default_settings_is_null():
	var ctx = _create_context()
	assert_null(ctx.settings)


func test_variables_are_writable():
	var ctx = _create_context()
	ctx.variables["score"] = 42
	assert_eq(ctx.variables["score"], 42)


func test_all_fields_settable():
	var ctx = _create_context()
	ctx.story = RefCounted.new()
	ctx.story_base_path = "/some/path"
	ctx.current_chapter = RefCounted.new()
	ctx.current_scene = RefCounted.new()
	ctx.current_sequence = RefCounted.new()
	ctx.current_dialogue_index = 5
	ctx.game_node = Control.new()
	ctx.settings = RefCounted.new()
	assert_not_null(ctx.story)
	assert_eq(ctx.story_base_path, "/some/path")
	assert_not_null(ctx.current_chapter)
	assert_not_null(ctx.current_scene)
	assert_not_null(ctx.current_sequence)
	assert_eq(ctx.current_dialogue_index, 5)
	assert_not_null(ctx.game_node)
	assert_not_null(ctx.settings)
	ctx.game_node.queue_free()
