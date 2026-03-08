extends GutTest


func test_has_manifest_false_by_default():
	var loader = PckChapterLoader.new()
	assert_false(loader.has_manifest())


func test_is_chapter_loaded_false_by_default():
	var loader = PckChapterLoader.new()
	assert_false(loader.is_chapter_loaded("some-uuid"))


func test_has_chapter_load_started_signal():
	var loader = PckChapterLoader.new()
	assert_has_signal(loader, "chapter_load_started")


func test_has_chapter_loaded_signal():
	var loader = PckChapterLoader.new()
	assert_has_signal(loader, "chapter_loaded")


func test_has_chapter_load_progress_signal():
	var loader = PckChapterLoader.new()
	assert_has_signal(loader, "chapter_load_progress")


func test_ensure_chapter_loaded_returns_true_without_manifest():
	var loader = PckChapterLoader.new()
	# Without manifest, should always return true
	var result = await loader.ensure_chapter_loaded("any-uuid")
	assert_true(result)
