extends GutTest

var PckChapterBuilderScript

func before_each():
	PckChapterBuilderScript = load("res://src/export/pck_chapter_builder.gd")

func test_script_loads():
	assert_not_null(PckChapterBuilderScript)

func test_normalize_path():
	var builder = PckChapterBuilderScript.new()
	assert_eq(builder._normalize_path("res://story/assets/img.png"), "assets/img.png")
	assert_eq(builder._normalize_path("assets/img.png"), "assets/img.png")
	assert_eq(builder._normalize_path(""), "")
	builder.free()

func test_split_groups_into_chunks_single_small():
	var builder = PckChapterBuilderScript.new()
	var groups = [{"total_size": 1000}]
	var chunks = builder._split_groups_into_chunks(groups)
	assert_eq(chunks.size(), 1)
	assert_eq(chunks[0].size(), 1)
	builder.free()

func test_split_groups_into_chunks_multiple_small():
	var builder = PckChapterBuilderScript.new()
	var groups = [
		{"total_size": 10 * 1024 * 1024},
		{"total_size": 10 * 1024 * 1024}
	]
	# MAX_PCK_SIZE is 19MB, so two 10MB groups should be in two chunks
	var chunks = builder._split_groups_into_chunks(groups)
	assert_eq(chunks.size(), 2)
	builder.free()

func test_collect_menu_assets():
	var builder = PckChapterBuilderScript.new()
	var story = {
		"menu_background": "res://story/bg.png",
		"menu_music": "music.mp3",
		"app_icon": ""
	}
	var assets = builder._collect_menu_assets(story)
	assert_true(assets.has("bg.png"))
	assert_true(assets.has("music.mp3"))
	assert_eq(assets.size(), 2)
	builder.free()
