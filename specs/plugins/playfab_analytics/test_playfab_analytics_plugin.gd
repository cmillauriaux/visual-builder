extends GutTest

const PlayFabPluginScript = preload("res://plugins/playfab_analytics/game_plugin.gd")
const GamePluginContextScript = preload("res://src/plugins/game_plugin_context.gd")


var _plugin: RefCounted


func before_each():
	_plugin = PlayFabPluginScript.new()


func _create_context(story: RefCounted = null) -> RefCounted:
	var ctx = GamePluginContextScript.new()
	ctx.game_node = Control.new()
	add_child(ctx.game_node)
	ctx.story = story
	return ctx


class _StoryStub extends RefCounted:
	var title: String = "Test Story"
	var version: String = "1.0"
	var plugin_settings: Dictionary = {}


# --- Identity ---

func test_plugin_name():
	assert_eq(_plugin.get_plugin_name(), "playfab_analytics")


func test_plugin_description_not_empty():
	assert_ne(_plugin.get_plugin_description(), "")


func test_not_configurable():
	assert_false(_plugin.is_configurable())


# --- on_game_ready ---

func test_no_service_when_no_story():
	var ctx = _create_context()
	_plugin.on_game_ready(ctx)
	assert_null(_plugin.get_service())
	ctx.game_node.queue_free()


func test_no_service_when_playfab_disabled():
	var story = _StoryStub.new()
	story.plugin_settings = {"playfab_analytics": {"title_id": "ABC123", "enabled": false}}
	var ctx = _create_context(story)
	_plugin.on_game_ready(ctx)
	assert_null(_plugin.get_service())
	ctx.game_node.queue_free()


func test_no_service_when_title_id_empty():
	var story = _StoryStub.new()
	story.plugin_settings = {"playfab_analytics": {"title_id": "", "enabled": true}}
	var ctx = _create_context(story)
	_plugin.on_game_ready(ctx)
	assert_null(_plugin.get_service())
	ctx.game_node.queue_free()


func test_no_service_when_no_plugin_settings():
	var story = _StoryStub.new()
	var ctx = _create_context(story)
	_plugin.on_game_ready(ctx)
	assert_null(_plugin.get_service())
	ctx.game_node.queue_free()


func test_service_created_when_configured():
	var story = _StoryStub.new()
	story.plugin_settings = {"playfab_analytics": {"title_id": "TESTTITLE", "enabled": true}}
	var ctx = _create_context(story)
	_plugin.on_game_ready(ctx)
	assert_not_null(_plugin.get_service())
	assert_true(_plugin.get_service() is Node)
	ctx.game_node.queue_free()


func test_service_is_child_of_game_node():
	var story = _StoryStub.new()
	story.plugin_settings = {"playfab_analytics": {"title_id": "TESTTITLE", "enabled": true}}
	var ctx = _create_context(story)
	_plugin.on_game_ready(ctx)
	var service = _plugin.get_service()
	assert_eq(service.get_parent(), ctx.game_node)
	ctx.game_node.queue_free()


# --- on_game_cleanup ---

func test_cleanup_nullifies_service():
	var story = _StoryStub.new()
	story.plugin_settings = {"playfab_analytics": {"title_id": "TESTTITLE", "enabled": true}}
	var ctx = _create_context(story)
	_plugin.on_game_ready(ctx)
	assert_not_null(_plugin.get_service())
	_plugin.on_game_cleanup(ctx)
	assert_null(_plugin.get_service())
	ctx.game_node.queue_free()


func test_cleanup_safe_when_no_service():
	var ctx = _create_context()
	_plugin.on_game_cleanup(ctx)
	assert_null(_plugin.get_service())
	ctx.game_node.queue_free()


# --- Hooks without service ---

func test_on_before_chapter_safe_without_service():
	var ctx = _create_context()
	_plugin.on_before_chapter(ctx)
	assert_null(_plugin.get_service())
	ctx.game_node.queue_free()


func test_on_before_scene_safe_without_service():
	var ctx = _create_context()
	_plugin.on_before_scene(ctx)
	assert_null(_plugin.get_service())
	ctx.game_node.queue_free()


func test_on_before_sequence_safe_without_service():
	var ctx = _create_context()
	_plugin.on_before_sequence(ctx)
	assert_null(_plugin.get_service())
	ctx.game_node.queue_free()


func test_on_after_choice_safe_without_service():
	var ctx = _create_context()
	_plugin.on_after_choice(ctx, 0, "test")
	assert_null(_plugin.get_service())
	ctx.game_node.queue_free()


func test_on_story_started_safe_without_service():
	var ctx = _create_context()
	_plugin.on_story_started(ctx, "My Story", "1.0")
	assert_null(_plugin.get_service())
	ctx.game_node.queue_free()


func test_on_story_finished_safe_without_service():
	var ctx = _create_context()
	_plugin.on_story_finished(ctx, "completed")
	assert_null(_plugin.get_service())
	ctx.game_node.queue_free()


func test_on_story_saved_safe_without_service():
	var ctx = _create_context()
	_plugin.on_story_saved(ctx, "My Story", 0, "ch1", "sc1", "seq1")
	assert_null(_plugin.get_service())
	ctx.game_node.queue_free()


func test_on_story_loaded_safe_without_service():
	var ctx = _create_context()
	_plugin.on_story_loaded(ctx, "My Story", 0)
	assert_null(_plugin.get_service())
	ctx.game_node.queue_free()


func test_on_game_quit_safe_without_service():
	var ctx = _create_context()
	_plugin.on_game_quit(ctx, "ch1", "sc1", "seq1")
	assert_null(_plugin.get_service())
	ctx.game_node.queue_free()


func test_on_quicksave_safe_without_service():
	var ctx = _create_context()
	_plugin.on_quicksave(ctx, "My Story", "ch1")
	assert_null(_plugin.get_service())
	ctx.game_node.queue_free()


func test_on_quickload_safe_without_service():
	var ctx = _create_context()
	_plugin.on_quickload(ctx, "My Story")
	assert_null(_plugin.get_service())
	ctx.game_node.queue_free()


# --- Options controls ---

func test_options_controls_has_entry():
	var ctrls = _plugin.get_options_controls()
	assert_eq(ctrls.size(), 1)


func test_options_creates_control():
	var ctrls = _plugin.get_options_controls()
	var ctrl = ctrls[0].create_control.call(null)
	assert_not_null(ctrl)
	assert_true(ctrl is HBoxContainer)
	ctrl.queue_free()


func test_options_shows_inactive_when_no_service():
	var ctrls = _plugin.get_options_controls()
	var ctrl = ctrls[0].create_control.call(null)
	var status_label = ctrl.get_child(1) as Label
	assert_eq(status_label.text, "Inactif")
	ctrl.queue_free()


# --- Editor config controls ---

func test_editor_config_controls_has_entry():
	var defs = _plugin.get_editor_config_controls()
	assert_eq(defs.size(), 1)


func test_editor_config_creates_control():
	var defs = _plugin.get_editor_config_controls()
	var ps = {"title_id": "TEST", "enabled": true}
	var ctrl = defs[0].create_control.call(ps)
	assert_not_null(ctrl)
	assert_true(ctrl is VBoxContainer)
	ctrl.queue_free()


func test_editor_config_reads_values():
	var defs = _plugin.get_editor_config_controls()
	var ps = {"title_id": "MY_TITLE", "enabled": true}
	var ctrl = defs[0].create_control.call(ps)
	var values = PlayFabPluginScript.read_editor_config(ctrl)
	assert_eq(values["title_id"], "MY_TITLE")
	assert_eq(values["enabled"], true)
	ctrl.queue_free()


func test_editor_config_empty_by_default():
	var defs = _plugin.get_editor_config_controls()
	var ctrl = defs[0].create_control.call({})
	var values = PlayFabPluginScript.read_editor_config(ctrl)
	assert_eq(values["title_id"], "")
	assert_eq(values["enabled"], false)
	ctrl.queue_free()


# --- Base class interface ---

func test_dialogue_passthrough():
	var ctx = _create_context()
	var result = _plugin.on_before_dialogue(ctx, "Alice", "Bonjour")
	assert_eq(result["character"], "Alice")
	assert_eq(result["text"], "Bonjour")
	ctx.game_node.queue_free()


func test_choice_passthrough():
	var ctx = _create_context()
	var choices = ["A", "B", "C"]
	var result = _plugin.on_before_choice(ctx, choices)
	assert_eq(result, ["A", "B", "C"])
	ctx.game_node.queue_free()
