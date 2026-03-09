extends GutTest

var PckChapterLoaderScript

func before_each():
	PckChapterLoaderScript = load("res://src/services/pck_chapter_loader.gd")

func test_setup_no_manifest():
	var loader = PckChapterLoaderScript.new()
	loader.setup("res://nonexistent/", get_tree())
	assert_false(loader.has_manifest())

func test_is_chapter_loaded_default():
	var loader = PckChapterLoaderScript.new()
	assert_false(loader.is_chapter_loaded("uuid"))

func test_ensure_chapter_loaded_no_manifest():
	var loader = PckChapterLoaderScript.new()
	# Without manifest, it should always return true (core assets or single PCK)
	var success = loader.ensure_chapter_loaded("uuid")
	assert_true(success)

func test_setup_with_manifest_data():
	var loader = PckChapterLoaderScript.new()
	var manifest = {
		"chapters": {
			"uuid1": {"name": "Chap 1", "pck": "chap1.pck"}
		}
	}
	loader._manifest = manifest
	assert_true(loader.has_manifest())
	assert_true(loader.ensure_chapter_loaded("unknown_uuid")) # Still true for unknown
	
	# Mark as already loaded
	loader._loaded_chapters["uuid1"] = true
	assert_true(loader.ensure_chapter_loaded("uuid1"))
