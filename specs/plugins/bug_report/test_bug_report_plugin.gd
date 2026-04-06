extends GutTest

const BugReportPlugin = preload("res://plugins/bug_report/game_plugin.gd")
const GamePluginContextScript = preload("res://src/plugins/game_plugin_context.gd")

var _plugin: RefCounted


func before_each() -> void:
	_plugin = BugReportPlugin.new()


# ── Helpers ──────────────────────────────────────────────────────────────────

func _create_context(email: String = "bugs@test.com") -> RefCounted:
	var ctx = GamePluginContextScript.new()
	ctx.game_node = Control.new()
	add_child(ctx.game_node)

	var ps: Dictionary = {}
	if email != "":
		ps = {"bug_report": {"email": email}}
	ctx.story = _FakeStory.new("Test Story", "1.2.3", ps)
	return ctx


func _create_context_with_navigation(email: String = "bugs@test.com") -> RefCounted:
	var ctx = _create_context(email)
	ctx.current_chapter = _FakeChapter.new("Chapitre 1")
	ctx.current_scene = _FakeScene.new("Scène intro")
	ctx.current_sequence = _FakeSequence.new("Dialogue initial", "seq_intro")
	return ctx


func _free_context(ctx: RefCounted) -> void:
	if ctx.game_node != null and is_instance_valid(ctx.game_node):
		ctx.game_node.queue_free()


# ── Tests identité du plugin ─────────────────────────────────────────────────

func test_plugin_name():
	assert_eq(_plugin.get_plugin_name(), "bug_report")


func test_plugin_description_not_empty():
	assert_ne(_plugin.get_plugin_description(), "")


func test_not_configurable():
	assert_false(_plugin.is_configurable())


func test_plugin_folder():
	assert_eq(_plugin.get_plugin_folder(), "bug_report")


# ── Tests chargement config ──────────────────────────────────────────────────

func test_load_email_from_settings():
	var ctx = _create_context("contact@game.com")
	_plugin.on_game_ready(ctx)
	assert_eq(_plugin._email, "contact@game.com")
	_free_context(ctx)


func test_load_empty_email_when_no_settings():
	var ctx = _create_context("")
	_plugin.on_game_ready(ctx)
	assert_eq(_plugin._email, "")
	_free_context(ctx)


func test_load_empty_email_when_no_story():
	var ctx = GamePluginContextScript.new()
	ctx.story = null
	_plugin.on_game_ready(ctx)
	assert_eq(_plugin._email, "")


# ── Tests toolbar button ─────────────────────────────────────────────────────

func test_toolbar_button_shown_when_email_set():
	var ctx = _create_context("bugs@test.com")
	_plugin.on_game_ready(ctx)
	var buttons = _plugin.get_toolbar_buttons()
	assert_eq(buttons.size(), 1)
	assert_eq(buttons[0].label, "Bug ?")
	_free_context(ctx)


func test_toolbar_button_hidden_when_no_email():
	var ctx = _create_context("")
	_plugin.on_game_ready(ctx)
	var buttons = _plugin.get_toolbar_buttons()
	assert_eq(buttons.size(), 0)
	_free_context(ctx)


# ── Tests info système ───────────────────────────────────────────────────────

func test_system_info_contains_os():
	var ctx = _create_context()
	var info = _plugin._build_system_info(ctx)
	assert_string_contains(info, "OS : ")
	assert_string_contains(info, OS.get_name())
	_free_context(ctx)


func test_system_info_contains_engine_version():
	var ctx = _create_context()
	var info = _plugin._build_system_info(ctx)
	assert_string_contains(info, "Version du moteur : ")
	assert_string_contains(info, Engine.get_version_info().string)
	_free_context(ctx)


func test_system_info_no_chapter():
	var ctx = _create_context()
	var info = _plugin._build_system_info(ctx)
	assert_string_contains(info, "Chapitre : Aucun")
	_free_context(ctx)


func test_system_info_with_chapter():
	var ctx = _create_context_with_navigation()
	var info = _plugin._build_system_info(ctx)
	assert_string_contains(info, "Chapitre : Chapitre 1")
	assert_string_contains(info, "Scène : Scène intro")
	assert_string_contains(info, "Séquence : Dialogue initial")
	_free_context(ctx)


# ── Tests endpoint URL ──────────────────────────────────────────────────────

func test_endpoint_url_contains_base():
	var ctx = _create_context("bugs@test.com")
	_plugin.on_game_ready(ctx)
	var url = _plugin._build_endpoint_url()
	assert_true(url.begins_with("https://formsubmit.co/ajax/"))
	_free_context(ctx)


func test_endpoint_url_contains_email():
	var ctx = _create_context("bugs@test.com")
	_plugin.on_game_ready(ctx)
	var url = _plugin._build_endpoint_url()
	assert_eq(url, "https://formsubmit.co/ajax/bugs@test.com")
	_free_context(ctx)


# ── Tests génération JSON body ──────────────────────────────────────────────

func test_json_body_contains_comment():
	var ctx = _create_context()
	var json_str = _plugin._build_json_body(ctx, "Le jeu plante quand je clique")
	var data: Dictionary = JSON.parse_string(json_str)
	assert_eq(data["Commentaire"], "Le jeu plante quand je clique")
	_free_context(ctx)


func test_json_body_contains_system_info():
	var ctx = _create_context()
	var json_str = _plugin._build_json_body(ctx, "Bug")
	var data: Dictionary = JSON.parse_string(json_str)
	assert_eq(data["OS"], OS.get_name())
	assert_eq(data["Version du moteur"], Engine.get_version_info().string)
	_free_context(ctx)


func test_json_body_contains_subject():
	var ctx = _create_context()
	var json_str = _plugin._build_json_body(ctx, "Test")
	var data: Dictionary = JSON.parse_string(json_str)
	assert_string_contains(data["_subject"], "[Bug Report]")
	assert_string_contains(data["_subject"], "Test Story")
	assert_string_contains(data["_subject"], "v1.2.3")
	_free_context(ctx)


func test_json_body_contains_captcha_false():
	var ctx = _create_context()
	var json_str = _plugin._build_json_body(ctx, "Test")
	var data: Dictionary = JSON.parse_string(json_str)
	assert_eq(data["_captcha"], "false")
	_free_context(ctx)


func test_json_body_contains_template():
	var ctx = _create_context()
	var json_str = _plugin._build_json_body(ctx, "Test")
	var data: Dictionary = JSON.parse_string(json_str)
	assert_eq(data["_template"], "box")
	_free_context(ctx)


func test_json_body_contains_navigation_info():
	var ctx = _create_context_with_navigation()
	var json_str = _plugin._build_json_body(ctx, "Test")
	var data: Dictionary = JSON.parse_string(json_str)
	assert_eq(data["Chapitre"], "Chapitre 1")
	assert_eq(data["Scène"], "Scène intro")
	assert_eq(data["Séquence"], "Dialogue initial")
	_free_context(ctx)


func test_json_body_default_navigation():
	var ctx = _create_context()
	var json_str = _plugin._build_json_body(ctx, "Test")
	var data: Dictionary = JSON.parse_string(json_str)
	assert_eq(data["Chapitre"], "Aucun")
	assert_eq(data["Scène"], "Aucune")
	assert_eq(data["Séquence"], "Aucune")
	_free_context(ctx)


func test_json_body_with_no_story():
	var ctx = GamePluginContextScript.new()
	ctx.story = null
	var json_str = _plugin._build_json_body(ctx, "Test")
	var data: Dictionary = JSON.parse_string(json_str)
	assert_string_contains(data["_subject"], "[Bug Report]")
	assert_eq(data["Commentaire"], "Test")


# ── Tests sequence fallback ──────────────────────────────────────────────────

func test_sequence_title_used_when_present():
	var ctx = _create_context_with_navigation()
	var info = _plugin._build_system_info(ctx)
	assert_string_contains(info, "Séquence : Dialogue initial")
	_free_context(ctx)


func test_sequence_falls_back_to_seq_name():
	var ctx = _create_context()
	ctx.current_sequence = _FakeSequence.new("", "intro_scene")
	var info = _plugin._build_system_info(ctx)
	assert_string_contains(info, "Séquence : intro_scene")
	_free_context(ctx)


func test_sequence_falls_back_to_uuid():
	var ctx = _create_context()
	ctx.current_sequence = _FakeSequence.new("", "")
	var info = _plugin._build_system_info(ctx)
	assert_string_contains(info, "Séquence : fake-uuid-1234")
	_free_context(ctx)


# ── Tests game version from story ────────────────────────────────────────────

func test_game_version_from_story():
	var ctx = _create_context()
	var version = _plugin._get_game_version(ctx)
	assert_eq(version, "1.2.3")
	_free_context(ctx)


func test_game_version_fallback_when_no_story():
	var ctx = GamePluginContextScript.new()
	ctx.story = null
	var version = _plugin._get_game_version(ctx)
	# Falls back to ProjectSettings or "inconnue"
	assert_true(version is String)


# ── Tests fresh ctx ──────────────────────────────────────────────────────────

func test_get_fresh_ctx_returns_ctx_when_no_method():
	var ctx = _create_context()
	var result = _plugin._get_fresh_ctx(ctx)
	assert_eq(result, ctx)
	_free_context(ctx)


# ── Tests editor config ─────────────────────────────────────────────────────

func test_editor_config_controls_returned():
	var controls = _plugin.get_editor_config_controls()
	assert_eq(controls.size(), 1)


func test_editor_config_creates_control():
	var controls = _plugin.get_editor_config_controls()
	var ctrl = controls[0].create_control.call({"email": "test@game.com"})
	assert_not_null(ctrl)
	assert_true(ctrl is VBoxContainer)
	add_child(ctrl)
	ctrl.queue_free()


func test_editor_config_read_config():
	var controls = _plugin.get_editor_config_controls()
	var ctrl = controls[0].create_control.call({"email": "test@game.com"})
	add_child(ctrl)
	var config = _plugin.read_editor_config(ctrl)
	assert_eq(config["email"], "test@game.com")
	ctrl.queue_free()


# ── Tests export options ─────────────────────────────────────────────────────

func test_export_options_returned():
	var options = _plugin.get_export_options()
	assert_eq(options.size(), 1)
	assert_eq(options[0].key, "bug_report_enabled")
	assert_true(options[0].default_value)


# ── Tests cleanup ────────────────────────────────────────────────────────────

func test_cleanup_clears_ctx():
	var ctx = _create_context()
	_plugin.on_game_ready(ctx)
	assert_not_null(_plugin._ctx)
	_plugin.on_game_cleanup(ctx)
	assert_null(_plugin._ctx)
	_free_context(ctx)


# ── Helper classes ───────────────────────────────────────────────────────────

class _FakeStory extends RefCounted:
	var title: String = ""
	var version: String = ""
	var plugin_settings: Dictionary = {}

	func _init(p_title: String = "Test Story", p_version: String = "1.0", p_settings: Dictionary = {}) -> void:
		title = p_title
		version = p_version
		plugin_settings = p_settings


class _FakeChapter extends RefCounted:
	var chapter_name: String = ""

	func _init(p_name: String = "") -> void:
		chapter_name = p_name


class _FakeScene extends RefCounted:
	var scene_name: String = ""

	func _init(p_name: String = "") -> void:
		scene_name = p_name


class _FakeSequence extends RefCounted:
	var title: String = ""
	var seq_name: String = ""
	var uuid: String = "fake-uuid-1234"

	func _init(p_title: String = "", p_seq_name: String = "") -> void:
		title = p_title
		seq_name = p_seq_name
