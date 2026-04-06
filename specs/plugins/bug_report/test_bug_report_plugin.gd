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
	ctx.current_sequence = _FakeSequence.new("Dialogue initial")
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


# ── Tests génération body ────────────────────────────────────────────────────

func test_mail_body_contains_comment():
	var ctx = _create_context()
	var body = _plugin._build_mail_body(ctx, "Le jeu plante quand je clique")
	assert_string_contains(body, "Commentaire du joueur :")
	assert_string_contains(body, "Le jeu plante quand je clique")
	_free_context(ctx)


func test_mail_body_contains_system_info():
	var ctx = _create_context()
	var body = _plugin._build_mail_body(ctx, "Bug")
	assert_string_contains(body, "--- Informations système ---")
	assert_string_contains(body, "OS : ")
	_free_context(ctx)


# ── Tests génération mailto URL ──────────────────────────────────────────────

func test_mailto_url_starts_with_mailto():
	var ctx = _create_context("bugs@test.com")
	_plugin.on_game_ready(ctx)
	var url = _plugin._build_mailto_url(ctx, "Test bug")
	assert_true(url.begins_with("mailto:"))
	_free_context(ctx)


func test_mailto_url_contains_email():
	var ctx = _create_context("bugs@test.com")
	_plugin.on_game_ready(ctx)
	var url = _plugin._build_mailto_url(ctx, "Test bug")
	assert_string_contains(url, "bugs%40test.com")
	_free_context(ctx)


func test_mailto_url_contains_subject():
	var ctx = _create_context("bugs@test.com")
	_plugin.on_game_ready(ctx)
	var url = _plugin._build_mailto_url(ctx, "Test")
	assert_string_contains(url, "subject=")
	assert_string_contains(url, "Bug%20Report")
	_free_context(ctx)


func test_mailto_url_contains_body():
	var ctx = _create_context("bugs@test.com")
	_plugin.on_game_ready(ctx)
	var url = _plugin._build_mailto_url(ctx, "Mon commentaire")
	assert_string_contains(url, "body=")
	_free_context(ctx)


# ── Tests subject ────────────────────────────────────────────────────────────

func test_mail_subject_contains_story_info():
	var ctx = _create_context()
	var subject = _plugin._build_mail_subject(ctx)
	assert_string_contains(subject, "[Bug Report]")
	assert_string_contains(subject, "Test Story")
	assert_string_contains(subject, "v1.2.3")
	_free_context(ctx)


func test_mail_subject_with_no_story():
	var ctx = GamePluginContextScript.new()
	ctx.story = null
	var subject = _plugin._build_mail_subject(ctx)
	assert_string_contains(subject, "[Bug Report]")


# ── Tests URI encode ─────────────────────────────────────────────────────────

func test_uri_encode_spaces():
	var result = BugReportPlugin._uri_encode("hello world")
	assert_eq(result, "hello%20world")


func test_uri_encode_special_chars():
	var result = BugReportPlugin._uri_encode("test@email.com")
	assert_string_contains(result, "%40")


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

	func _init(p_title: String = "") -> void:
		title = p_title
