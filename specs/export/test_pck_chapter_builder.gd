extends GutTest

const PckChapterBuilder = preload("res://src/export/pck_chapter_builder.gd")


func test_script_loads():
	assert_not_null(PckChapterBuilder)


func test_normalize_path_strips_res_story_prefix():
	assert_eq(PckChapterBuilder._normalize_path("res://story/assets/bg.png"), "assets/bg.png")


func test_normalize_path_keeps_relative_path():
	assert_eq(PckChapterBuilder._normalize_path("assets/bg.png"), "assets/bg.png")


func test_normalize_path_empty_string():
	assert_eq(PckChapterBuilder._normalize_path(""), "")
