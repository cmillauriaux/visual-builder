extends GutTest

const PluginContext = preload("res://src/plugins/plugin_context.gd")


func test_has_story_field() -> void:
	var ctx := PluginContext.new()
	assert_null(ctx.story)


func test_has_story_base_path_field() -> void:
	var ctx := PluginContext.new()
	assert_eq(ctx.story_base_path, "")


func test_has_current_chapter_field() -> void:
	var ctx := PluginContext.new()
	assert_null(ctx.current_chapter)


func test_has_current_scene_field() -> void:
	var ctx := PluginContext.new()
	assert_null(ctx.current_scene)


func test_has_current_sequence_field() -> void:
	var ctx := PluginContext.new()
	assert_null(ctx.current_sequence)


func test_has_main_node_field() -> void:
	var ctx := PluginContext.new()
	assert_null(ctx.main_node)


func test_fields_can_be_set() -> void:
	var ctx := PluginContext.new()
	var node := Control.new()
	ctx.main_node = node
	ctx.story_base_path = "/some/path"
	assert_eq(ctx.main_node, node)
	assert_eq(ctx.story_base_path, "/some/path")
	node.queue_free()
