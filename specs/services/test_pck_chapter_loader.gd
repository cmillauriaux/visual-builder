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


func test_parse_pck_entry_string_format():
	# Ancien format : juste un nom de fichier
	var result = PckChapterLoader._parse_pck_entry("chapter_abc_part1.pck")
	assert_eq(result["file"], "chapter_abc_part1.pck")
	assert_eq(result["size"], 0)


func test_parse_pck_entry_dict_format():
	# Nouveau format : dictionnaire avec file et size
	var result = PckChapterLoader._parse_pck_entry({"file": "chapter_abc_part1.pck", "size": 15234567})
	assert_eq(result["file"], "chapter_abc_part1.pck")
	assert_eq(result["size"], 15234567)


func test_parse_pck_entry_dict_missing_size():
	# Dictionnaire sans size
	var result = PckChapterLoader._parse_pck_entry({"file": "chapter_abc_part1.pck"})
	assert_eq(result["file"], "chapter_abc_part1.pck")
	assert_eq(result["size"], 0)


func test_parse_pck_entry_invalid():
	var result = PckChapterLoader._parse_pck_entry(42)
	assert_eq(result["file"], "")
	assert_eq(result["size"], 0)


func test_signals_exist():
	var loader = PckChapterLoaderScript.new()
	assert_true(loader.has_signal("chapter_load_started"))
	assert_true(loader.has_signal("chapter_download_progress"))
	assert_true(loader.has_signal("chapter_mounting_started"))
	assert_true(loader.has_signal("chapter_loaded"))


func test_ensure_chapter_loaded_with_new_manifest_format():
	var loader = PckChapterLoaderScript.new()
	var manifest = {
		"chapters": {
			"uuid1": {
				"name": "Chap 1",
				"pcks": [
					{"file": "chapter_uuid1_part1.pck", "size": 15000000},
					{"file": "chapter_uuid1_part2.pck", "size": 12000000}
				]
			}
		}
	}
	loader._manifest = manifest
	assert_true(loader.has_manifest())
	# Mark as already loaded to avoid actual PCK loading
	loader._loaded_chapters["uuid1"] = true
	assert_true(loader.ensure_chapter_loaded("uuid1"))


func test_ensure_chapter_loaded_with_old_manifest_format():
	var loader = PckChapterLoaderScript.new()
	var manifest = {
		"chapters": {
			"uuid1": {
				"name": "Chap 1",
				"pcks": ["chapter_uuid1_part1.pck", "chapter_uuid1_part2.pck"]
			}
		}
	}
	loader._manifest = manifest
	assert_true(loader.has_manifest())
	loader._loaded_chapters["uuid1"] = true
	assert_true(loader.ensure_chapter_loaded("uuid1"))
