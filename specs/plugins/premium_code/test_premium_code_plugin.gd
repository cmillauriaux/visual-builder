extends GutTest

const PremiumCodePluginScript = preload("res://plugins/premium_code/game_plugin.gd")
const GamePluginContextScript = preload("res://src/plugins/game_plugin_context.gd")
const StoryScript = preload("res://src/models/story.gd")
const ChapterScript = preload("res://src/models/chapter.gd")

var _plugin: RefCounted
var _codes_path: String = "user://codes.json"


func before_each():
	_plugin = PremiumCodePluginScript.new()
	# Nettoyer le fichier de codes avant chaque test
	if FileAccess.file_exists(_codes_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_codes_path))


func after_all():
	if FileAccess.file_exists(_codes_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_codes_path))


func _create_story_with_chapters(count: int = 5) -> RefCounted:
	var story = StoryScript.new()
	story.title = "Test Story"
	story.itchio_url = "https://example.itch.io/game"
	story.patreon_url = "https://patreon.com/example"
	for i in range(count):
		var ch = ChapterScript.new()
		ch.uuid = "ch_%d" % i
		ch.chapter_name = "Chapitre %d" % (i + 1)
		story.chapters.append(ch)
	story.entry_point_uuid = "ch_0"
	return story


func _create_context_with_story(story: RefCounted, chapter_uuid: String = "ch_0") -> RefCounted:
	var ctx = GamePluginContextScript.new()
	ctx.story = story
	ctx.story_base_path = "/tmp/test_story"
	for ch in story.chapters:
		if ch.uuid == chapter_uuid:
			ctx.current_chapter = ch
			break
	ctx.game_node = Control.new()
	add_child(ctx.game_node)
	return ctx


func _setup_plugin_settings(story: RefCounted, codes: Array = [], message: String = "", url: String = "") -> void:
	var settings: Dictionary = {}
	settings["codes"] = codes
	if message != "":
		settings["purchase_message"] = message
	if url != "":
		settings["purchase_url"] = url
	story.plugin_settings["premium_code"] = settings


# --- Identity ---

func test_plugin_name():
	assert_eq(_plugin.get_plugin_name(), "premium_code")


func test_plugin_description_not_empty():
	assert_ne(_plugin.get_plugin_description(), "")


func test_not_configurable():
	assert_false(_plugin.is_configurable())


func test_plugin_folder():
	assert_eq(_plugin.get_plugin_folder(), "premium_code")


# --- Code validation ---

func test_valid_code_is_recognized():
	var story = _create_story_with_chapters()
	_setup_plugin_settings(story, [
		{"code": "SECRET123", "from_chapter_uuid": "ch_1", "to_chapter_uuid": "ch_3"}
	])
	var ctx = _create_context_with_story(story)
	_plugin.on_game_ready(ctx)
	assert_true(_plugin._is_code_valid("SECRET123"))
	ctx.game_node.queue_free()


func test_invalid_code_is_rejected():
	var story = _create_story_with_chapters()
	_setup_plugin_settings(story, [
		{"code": "SECRET123", "from_chapter_uuid": "ch_1", "to_chapter_uuid": "ch_3"}
	])
	var ctx = _create_context_with_story(story)
	_plugin.on_game_ready(ctx)
	assert_false(_plugin._is_code_valid("WRONG_CODE"))
	ctx.game_node.queue_free()


# --- Chapter protection detection ---

func test_chapter_in_range_is_protected():
	var story = _create_story_with_chapters()
	_setup_plugin_settings(story, [
		{"code": "CODE1", "from_chapter_uuid": "ch_1", "to_chapter_uuid": "ch_3"}
	])
	var ctx = _create_context_with_story(story)
	_plugin.on_game_ready(ctx)
	var required = _plugin._get_required_codes_for_chapter("ch_2", story)
	assert_eq(required.size(), 1)
	assert_eq(required[0]["code"], "CODE1")
	ctx.game_node.queue_free()


func test_chapter_at_range_start_is_protected():
	var story = _create_story_with_chapters()
	_setup_plugin_settings(story, [
		{"code": "CODE1", "from_chapter_uuid": "ch_1", "to_chapter_uuid": "ch_3"}
	])
	var ctx = _create_context_with_story(story)
	_plugin.on_game_ready(ctx)
	var required = _plugin._get_required_codes_for_chapter("ch_1", story)
	assert_eq(required.size(), 1)
	ctx.game_node.queue_free()


func test_chapter_at_range_end_is_protected():
	var story = _create_story_with_chapters()
	_setup_plugin_settings(story, [
		{"code": "CODE1", "from_chapter_uuid": "ch_1", "to_chapter_uuid": "ch_3"}
	])
	var ctx = _create_context_with_story(story)
	_plugin.on_game_ready(ctx)
	var required = _plugin._get_required_codes_for_chapter("ch_3", story)
	assert_eq(required.size(), 1)
	ctx.game_node.queue_free()


func test_chapter_outside_range_is_free():
	var story = _create_story_with_chapters()
	_setup_plugin_settings(story, [
		{"code": "CODE1", "from_chapter_uuid": "ch_1", "to_chapter_uuid": "ch_3"}
	])
	var ctx = _create_context_with_story(story)
	_plugin.on_game_ready(ctx)
	var required = _plugin._get_required_codes_for_chapter("ch_0", story)
	assert_eq(required.size(), 0)
	ctx.game_node.queue_free()


func test_chapter_after_range_is_free():
	var story = _create_story_with_chapters()
	_setup_plugin_settings(story, [
		{"code": "CODE1", "from_chapter_uuid": "ch_1", "to_chapter_uuid": "ch_3"}
	])
	var ctx = _create_context_with_story(story)
	_plugin.on_game_ready(ctx)
	var required = _plugin._get_required_codes_for_chapter("ch_4", story)
	assert_eq(required.size(), 0)
	ctx.game_node.queue_free()


func test_no_codes_configured_means_all_free():
	var story = _create_story_with_chapters()
	_setup_plugin_settings(story, [])
	var ctx = _create_context_with_story(story)
	_plugin.on_game_ready(ctx)
	var required = _plugin._get_required_codes_for_chapter("ch_2", story)
	assert_eq(required.size(), 0)
	ctx.game_node.queue_free()


func test_multiple_codes_covering_same_chapter():
	var story = _create_story_with_chapters()
	_setup_plugin_settings(story, [
		{"code": "CODE_A", "from_chapter_uuid": "ch_1", "to_chapter_uuid": "ch_2"},
		{"code": "CODE_B", "from_chapter_uuid": "ch_2", "to_chapter_uuid": "ch_4"},
	])
	var ctx = _create_context_with_story(story)
	_plugin.on_game_ready(ctx)
	var required = _plugin._get_required_codes_for_chapter("ch_2", story)
	assert_eq(required.size(), 2)
	ctx.game_node.queue_free()


# --- Code persistence ---

func test_save_and_load_validated_codes():
	_plugin._validated_codes = []
	_plugin._add_validated_code("TEST_CODE")
	assert_true(FileAccess.file_exists(_codes_path))

	# Créer une nouvelle instance pour vérifier le chargement
	var plugin2 = PremiumCodePluginScript.new()
	plugin2._load_validated_codes()
	assert_true(plugin2._validated_codes.has("TEST_CODE"))


func test_duplicate_code_not_added_twice():
	_plugin._validated_codes = []
	_plugin._add_validated_code("CODE1")
	_plugin._add_validated_code("CODE1")
	assert_eq(_plugin._validated_codes.size(), 1)


func test_remove_validated_code():
	_plugin._validated_codes = []
	_plugin._add_validated_code("CODE1")
	_plugin._add_validated_code("CODE2")
	_plugin._remove_validated_code("CODE1")
	assert_false(_plugin._validated_codes.has("CODE1"))
	assert_true(_plugin._validated_codes.has("CODE2"))


func test_load_with_no_file_returns_empty():
	_plugin._load_validated_codes()
	assert_eq(_plugin._validated_codes.size(), 0)


# --- on_before_chapter behavior ---

func test_free_chapter_does_not_show_popup():
	var story = _create_story_with_chapters()
	_setup_plugin_settings(story, [
		{"code": "CODE1", "from_chapter_uuid": "ch_2", "to_chapter_uuid": "ch_3"}
	])
	var ctx = _create_context_with_story(story, "ch_0")
	_plugin.on_game_ready(ctx)
	_plugin.on_before_chapter(ctx)
	# Le popup ne devrait pas être affiché
	assert_null(_plugin._popup)
	ctx.game_node.queue_free()


func test_protected_chapter_without_code_shows_popup():
	var story = _create_story_with_chapters()
	_setup_plugin_settings(story, [
		{"code": "CODE1", "from_chapter_uuid": "ch_1", "to_chapter_uuid": "ch_3"}
	])
	var ctx = _create_context_with_story(story, "ch_2")
	_plugin.on_game_ready(ctx)
	_plugin.on_before_chapter(ctx)
	assert_not_null(_plugin._popup)
	_plugin._popup.queue_free()
	ctx.game_node.queue_free()


func test_protected_chapter_with_valid_code_does_not_show_popup():
	var story = _create_story_with_chapters()
	_setup_plugin_settings(story, [
		{"code": "CODE1", "from_chapter_uuid": "ch_1", "to_chapter_uuid": "ch_3"}
	])
	var ctx = _create_context_with_story(story, "ch_2")
	_plugin.on_game_ready(ctx)
	_plugin._add_validated_code("CODE1")
	_plugin.on_before_chapter(ctx)
	assert_null(_plugin._popup)
	ctx.game_node.queue_free()


# --- Purchase URL resolution ---

func test_purchase_url_from_plugin_settings():
	var story = _create_story_with_chapters()
	_setup_plugin_settings(story, [], "", "https://custom.shop/buy")
	var ctx = _create_context_with_story(story)
	_plugin.on_game_ready(ctx)
	assert_eq(_plugin._get_purchase_url(), "https://custom.shop/buy")
	ctx.game_node.queue_free()


func test_purchase_url_falls_back_to_itchio():
	var story = _create_story_with_chapters()
	_setup_plugin_settings(story, [])
	var ctx = _create_context_with_story(story)
	_plugin.on_game_ready(ctx)
	assert_eq(_plugin._get_purchase_url(), "https://example.itch.io/game")
	ctx.game_node.queue_free()


func test_purchase_url_falls_back_to_patreon():
	var story = _create_story_with_chapters()
	story.itchio_url = ""
	_setup_plugin_settings(story, [])
	var ctx = _create_context_with_story(story)
	_plugin.on_game_ready(ctx)
	assert_eq(_plugin._get_purchase_url(), "https://patreon.com/example")
	ctx.game_node.queue_free()


# --- Export options ---

func test_get_export_options_returns_one_option():
	var options = _plugin.get_export_options()
	assert_eq(options.size(), 1)
	assert_eq(options[0].key, "premium_code_enabled")
	assert_true(options[0].default_value)


# --- Editor config ---

func test_get_editor_config_controls_returns_one():
	var defs = _plugin.get_editor_config_controls()
	assert_eq(defs.size(), 1)


func test_read_editor_config_from_empty():
	var ctrl = _plugin._create_editor_config({})
	add_child(ctrl)
	var config = _plugin.read_editor_config(ctrl)
	assert_true(config.has("codes"))
	assert_true(config.has("purchase_message"))
	assert_true(config.has("purchase_url"))
	assert_eq(config["codes"].size(), 0)
	ctrl.queue_free()


# --- Options in-game ---

func test_get_options_controls_returns_one():
	var defs = _plugin.get_options_controls()
	assert_eq(defs.size(), 1)
