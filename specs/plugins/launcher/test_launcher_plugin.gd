extends GutTest

const LauncherPluginScript = preload("res://plugins/launcher/game_plugin.gd")
const GamePluginContextScript = preload("res://src/plugins/game_plugin_context.gd")

var _plugin: RefCounted


func before_each():
	_plugin = LauncherPluginScript.new()


func _create_context(config: Dictionary = {}) -> RefCounted:
	var ctx = GamePluginContextScript.new()
	ctx.game_node = Control.new()
	add_child(ctx.game_node)
	# Créer une story fictive avec plugin_settings
	var story = RefCounted.new()
	story.set_meta("plugin_settings", config)
	# On utilise un objet qui expose plugin_settings via property
	ctx.story = _FakeStory.new(config)
	ctx.story_base_path = "res://test"
	return ctx


# --- Identity ---

func test_plugin_name():
	assert_eq(_plugin.get_plugin_name(), "launcher")


func test_plugin_description_not_empty():
	assert_ne(_plugin.get_plugin_description(), "")


func test_is_configurable():
	assert_true(_plugin.is_configurable())


func test_plugin_folder():
	assert_eq(_plugin.get_plugin_folder(), "launcher")


# --- Default config ---

func test_default_config_only_engine_logo_enabled():
	var defaults = LauncherPluginScript._get_default_config()
	assert_false(defaults["studio_logo_enabled"])
	assert_true(defaults["engine_logo_enabled"])
	assert_false(defaults["disclaimer_enabled"])
	assert_false(defaults["free_text_enabled"])


func test_default_config_durations():
	var defaults = LauncherPluginScript._get_default_config()
	assert_eq(defaults["studio_logo_duration"], 2.0)
	assert_eq(defaults["engine_logo_duration"], 2.0)
	assert_eq(defaults["disclaimer_duration"], 3.0)
	assert_eq(defaults["free_text_duration"], 3.0)


# --- Build steps ---

func test_build_steps_default_config_has_engine_logo():
	var ctx = _create_context()
	var defaults = LauncherPluginScript._get_default_config()
	var steps = _plugin._build_steps(defaults, ctx)
	assert_eq(steps.size(), 1)
	assert_eq(steps[0]["type"], "engine_logo")
	ctx.game_node.queue_free()


func test_build_steps_all_disabled():
	var ctx = _create_context()
	var config := {
		"studio_logo_enabled": false,
		"engine_logo_enabled": false,
		"disclaimer_enabled": false,
		"free_text_enabled": false,
	}
	var steps = _plugin._build_steps(config, ctx)
	assert_eq(steps.size(), 0)
	ctx.game_node.queue_free()


func test_build_steps_all_enabled():
	var ctx = _create_context()
	var config := {
		"studio_logo_enabled": true,
		"studio_logo_path": "res://icon.svg",
		"studio_logo_duration": 2.0,
		"engine_logo_enabled": true,
		"engine_logo_duration": 2.0,
		"disclaimer_enabled": true,
		"disclaimer_text": "TEST DISCLAIMER",
		"disclaimer_duration": 3.0,
		"free_text_enabled": true,
		"free_text_content": "Hello World",
		"free_text_duration": 3.0,
	}
	var steps = _plugin._build_steps(config, ctx)
	assert_eq(steps.size(), 4)
	assert_eq(steps[0]["type"], "studio_logo")
	assert_eq(steps[1]["type"], "engine_logo")
	assert_eq(steps[2]["type"], "disclaimer")
	assert_eq(steps[2]["text"], "TEST DISCLAIMER")
	assert_eq(steps[3]["type"], "free_text")
	assert_eq(steps[3]["text"], "Hello World")
	ctx.game_node.queue_free()


func test_build_steps_free_text_empty_excluded():
	var ctx = _create_context()
	var config := {
		"studio_logo_enabled": false,
		"engine_logo_enabled": false,
		"disclaimer_enabled": false,
		"free_text_enabled": true,
		"free_text_content": "",
	}
	var steps = _plugin._build_steps(config, ctx)
	assert_eq(steps.size(), 0, "Free text with empty content should not create a step")
	ctx.game_node.queue_free()


func test_build_steps_studio_logo_without_path():
	var ctx = _create_context()
	var config := {
		"studio_logo_enabled": true,
		"studio_logo_path": "",
		"engine_logo_enabled": false,
		"disclaimer_enabled": false,
		"free_text_enabled": false,
	}
	var steps = _plugin._build_steps(config, ctx)
	assert_eq(steps.size(), 1)
	assert_eq(steps[0]["type"], "studio_logo")
	assert_eq(steps[0]["path"], "")
	ctx.game_node.queue_free()


func test_build_steps_order():
	var ctx = _create_context()
	var config := {
		"studio_logo_enabled": true,
		"studio_logo_path": "logo.png",
		"engine_logo_enabled": true,
		"disclaimer_enabled": true,
		"disclaimer_text": "D",
		"free_text_enabled": true,
		"free_text_content": "T",
	}
	var steps = _plugin._build_steps(config, ctx)
	assert_eq(steps[0]["type"], "studio_logo")
	assert_eq(steps[1]["type"], "engine_logo")
	assert_eq(steps[2]["type"], "disclaimer")
	assert_eq(steps[3]["type"], "free_text")
	ctx.game_node.queue_free()


# --- Step content creation ---

func test_create_engine_logo_content():
	var content = _plugin._create_engine_logo_content()
	assert_not_null(content)
	assert_true(content is CenterContainer)
	# Should have a VBoxContainer child
	assert_eq(content.get_child_count(), 1)
	var vbox = content.get_child(0)
	assert_true(vbox is VBoxContainer)
	# VBox should have at least the label
	var has_label := false
	for child in vbox.get_children():
		if child is Label and child.text == "Made with Godot Engine":
			has_label = true
	assert_true(has_label, "Should contain 'Made with Godot Engine' label")
	content.queue_free()


func test_create_disclaimer_content():
	var step := {"text": "MY DISCLAIMER"}
	var content = _plugin._create_disclaimer_content(step)
	assert_not_null(content)
	assert_true(content is CenterContainer)
	var label = content.get_child(0)
	assert_true(label is Label)
	assert_eq(label.text, "MY DISCLAIMER")
	# Vérifier la couleur rouge
	var font_color = label.get_theme_color("font_color")
	assert_eq(font_color, Color(1, 0, 0))
	content.queue_free()


func test_create_disclaimer_default_text():
	var step := {}
	var content = _plugin._create_disclaimer_content(step)
	var label = content.get_child(0)
	assert_eq(label.text, "DISCLAIMER")
	content.queue_free()


func test_create_free_text_content():
	var step := {"text": "Mon texte libre"}
	var content = _plugin._create_free_text_content(step)
	assert_not_null(content)
	assert_true(content is CenterContainer)
	var label = content.get_child(0)
	assert_true(label is Label)
	assert_eq(label.text, "Mon texte libre")
	# Vérifier la couleur blanche
	var font_color = label.get_theme_color("font_color")
	assert_eq(font_color, Color.WHITE)
	content.queue_free()


func test_create_studio_logo_no_image():
	var step := {"path": ""}
	var content = _plugin._create_studio_logo_content(step)
	assert_not_null(content)
	assert_true(content is CenterContainer)
	# Fallback: affiche "Studio"
	var label = content.get_child(0)
	assert_true(label is Label)
	assert_eq(label.text, "Studio")
	content.queue_free()


func test_create_step_content_unknown_type():
	var step := {"type": "unknown"}
	var content = _plugin._create_step_content(step)
	assert_null(content)


# --- Overlay ---

func test_create_overlay():
	var ctx = _create_context()
	_plugin._game_node = ctx.game_node
	_plugin._create_overlay()
	assert_not_null(_plugin._overlay)
	assert_true(_plugin._overlay is ColorRect)
	assert_eq(_plugin._overlay.color, Color.BLACK)
	assert_eq(_plugin._overlay.z_index, 100)
	_plugin._cleanup_overlay()
	ctx.game_node.queue_free()


func test_cleanup_overlay():
	var ctx = _create_context()
	_plugin._game_node = ctx.game_node
	_plugin._create_overlay()
	var overlay_ref = _plugin._overlay
	_plugin._cleanup_overlay()
	assert_null(_plugin._overlay)
	assert_false(_plugin._is_playing)
	ctx.game_node.queue_free()


func test_create_overlay_replaces_existing():
	var ctx = _create_context()
	_plugin._game_node = ctx.game_node
	_plugin._create_overlay()
	var first_overlay = _plugin._overlay
	_plugin._create_overlay()
	assert_ne(_plugin._overlay, first_overlay)
	_plugin._cleanup_overlay()
	ctx.game_node.queue_free()


# --- Editor config controls ---

func test_editor_config_controls_has_entry():
	var ctrls = _plugin.get_editor_config_controls()
	assert_eq(ctrls.size(), 1)


func test_editor_config_creates_control():
	var ctrls = _plugin.get_editor_config_controls()
	var ctrl = ctrls[0].create_control.call({})
	assert_not_null(ctrl)
	assert_true(ctrl is VBoxContainer)
	ctrl.queue_free()


func test_editor_config_default_values():
	var ctrls = _plugin.get_editor_config_controls()
	var ctrl = ctrls[0].create_control.call({})
	var values = LauncherPluginScript.read_editor_config(ctrl)
	assert_false(values["studio_logo_enabled"])
	assert_true(values["engine_logo_enabled"])
	assert_false(values["disclaimer_enabled"])
	assert_false(values["free_text_enabled"])
	ctrl.queue_free()


func test_editor_config_reads_existing_values():
	var existing := {
		"studio_logo_enabled": true,
		"studio_logo_path": "logo.png",
		"engine_logo_enabled": false,
		"disclaimer_enabled": true,
		"disclaimer_text": "Mon disclaimer",
		"free_text_enabled": true,
		"free_text_content": "Mon texte",
	}
	var ctrls = _plugin.get_editor_config_controls()
	var ctrl = ctrls[0].create_control.call(existing)
	var values = LauncherPluginScript.read_editor_config(ctrl)
	assert_true(values["studio_logo_enabled"])
	assert_eq(values["studio_logo_path"], "logo.png")
	assert_false(values["engine_logo_enabled"])
	assert_true(values["disclaimer_enabled"])
	assert_eq(values["disclaimer_text"], "Mon disclaimer")
	assert_true(values["free_text_enabled"])
	assert_eq(values["free_text_content"], "Mon texte")
	ctrl.queue_free()


func test_read_editor_config_null_returns_empty():
	var values = LauncherPluginScript.read_editor_config(null)
	assert_eq(values, {})


# --- Export options ---

func test_export_options():
	var opts = _plugin.get_export_options()
	assert_eq(opts.size(), 1)
	assert_eq(opts[0].key, "launcher")
	assert_eq(opts[0].default_value, true)


# --- Config reading from story ---

func test_get_config_with_story_settings():
	var launcher_cfg := {"engine_logo_enabled": false, "disclaimer_enabled": true}
	var ctx = _create_context({"launcher": launcher_cfg})
	var config = _plugin._get_config(ctx)
	assert_false(config["engine_logo_enabled"])
	assert_true(config["disclaimer_enabled"])
	ctx.game_node.queue_free()


func test_get_config_without_story_returns_defaults():
	var ctx = GamePluginContextScript.new()
	ctx.game_node = Control.new()
	add_child(ctx.game_node)
	ctx.story = null
	var config = _plugin._get_config(ctx)
	assert_true(config["engine_logo_enabled"])
	assert_false(config["studio_logo_enabled"])
	ctx.game_node.queue_free()


# --- Helper class ---

class _FakeStory extends RefCounted:
	var title: String = "Test Story"
	var version: String = "1.0"
	var plugin_settings: Dictionary = {}

	func _init(launcher_config: Dictionary = {}):
		plugin_settings = launcher_config
