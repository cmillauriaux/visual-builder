extends GutTest

## Tests pour BlinkManifestService — gestion du manifeste de clignements d'yeux.

const BlinkManifestService = preload("res://src/services/blink_manifest_service.gd")

var _test_dir: String = ""


func before_each():
	_test_dir = "user://test_blink_manifest_%d" % randi()
	DirAccess.make_dir_recursive_absolute(_test_dir + "/assets/foregrounds")


func after_each():
	_remove_dir_recursive(_test_dir)


# --- load_manifest ---

func test_load_manifest_returns_empty_dict_when_file_missing():
	var manifest = BlinkManifestService.load_manifest(_test_dir)
	assert_eq(manifest, {})


func test_load_manifest_returns_empty_dict_for_nonexistent_dir():
	var manifest = BlinkManifestService.load_manifest(_test_dir + "/nonexistent")
	assert_eq(manifest, {})


func test_load_manifest_parses_single_entry():
	_write_manifest("blinks:\n  hero_smile.png: hero_smile_blink.png\n")
	var manifest = BlinkManifestService.load_manifest(_test_dir)
	assert_eq(manifest.size(), 1)
	assert_eq(manifest["hero_smile.png"], "hero_smile_blink.png")


func test_load_manifest_parses_multiple_entries():
	_write_manifest("blinks:\n  hero_smile.png: hero_smile_blink.png\n  hero_sad.png: hero_sad_blink.png\n")
	var manifest = BlinkManifestService.load_manifest(_test_dir)
	assert_eq(manifest.size(), 2)
	assert_eq(manifest["hero_smile.png"], "hero_smile_blink.png")
	assert_eq(manifest["hero_sad.png"], "hero_sad_blink.png")


func test_load_manifest_ignores_comments():
	_write_manifest("# comment\nblinks:\n  # another comment\n  hero.png: hero_blink.png\n")
	var manifest = BlinkManifestService.load_manifest(_test_dir)
	assert_eq(manifest.size(), 1)
	assert_eq(manifest["hero.png"], "hero_blink.png")


func test_load_manifest_handles_empty_blinks_section():
	_write_manifest("blinks:\n")
	var manifest = BlinkManifestService.load_manifest(_test_dir)
	assert_eq(manifest, {})


# --- save_manifest ---

func test_save_manifest_creates_file():
	BlinkManifestService.save_manifest(_test_dir, {})
	assert_true(FileAccess.file_exists(_test_dir + "/assets/foregrounds/blink_manifest.yaml"))


func test_save_manifest_creates_directory_if_missing():
	_remove_dir_recursive(_test_dir)
	BlinkManifestService.save_manifest(_test_dir, {"hero.png": "hero_blink.png"})
	assert_true(FileAccess.file_exists(_test_dir + "/assets/foregrounds/blink_manifest.yaml"))


func test_save_manifest_writes_blinks_header():
	BlinkManifestService.save_manifest(_test_dir, {})
	var content = _read_manifest()
	assert_string_contains(content, "blinks:")


func test_save_manifest_writes_entries():
	BlinkManifestService.save_manifest(_test_dir, {"hero_smile.png": "hero_smile_blink.png"})
	var content = _read_manifest()
	assert_string_contains(content, "hero_smile.png: hero_smile_blink.png")


func test_save_manifest_writes_multiple_entries():
	BlinkManifestService.save_manifest(_test_dir, {
		"hero_smile.png": "hero_smile_blink.png",
		"hero_sad.png": "hero_sad_blink.png"
	})
	var content = _read_manifest()
	assert_string_contains(content, "hero_smile.png: hero_smile_blink.png")
	assert_string_contains(content, "hero_sad.png: hero_sad_blink.png")


func test_save_manifest_sorts_keys():
	BlinkManifestService.save_manifest(_test_dir, {
		"z_last.png": "z_last_blink.png",
		"a_first.png": "a_first_blink.png"
	})
	var content = _read_manifest()
	var pos_a = content.find("a_first.png")
	var pos_z = content.find("z_last.png")
	assert_true(pos_a < pos_z, "Keys should be sorted alphabetically")


# --- get_blink_for ---

func test_get_blink_for_returns_empty_string_when_not_found():
	var result = BlinkManifestService.get_blink_for(_test_dir, "unknown.png")
	assert_eq(result, "")


func test_get_blink_for_returns_empty_string_when_file_missing():
	var result = BlinkManifestService.get_blink_for(_test_dir, "hero.png")
	assert_eq(result, "")


func test_get_blink_for_returns_blink_filename():
	BlinkManifestService.save_manifest(_test_dir, {"hero_smile.png": "hero_smile_blink.png"})
	var result = BlinkManifestService.get_blink_for(_test_dir, "hero_smile.png")
	assert_eq(result, "hero_smile_blink.png")


func test_get_blink_for_returns_empty_string_for_unregistered_image():
	BlinkManifestService.save_manifest(_test_dir, {"hero_smile.png": "hero_smile_blink.png"})
	var result = BlinkManifestService.get_blink_for(_test_dir, "other.png")
	assert_eq(result, "")


# --- set_blink ---

func test_set_blink_creates_manifest_file():
	BlinkManifestService.set_blink(_test_dir, "hero.png", "hero_blink.png")
	assert_true(FileAccess.file_exists(_test_dir + "/assets/foregrounds/blink_manifest.yaml"))


func test_set_blink_stores_entry():
	BlinkManifestService.set_blink(_test_dir, "hero.png", "hero_blink.png")
	var result = BlinkManifestService.get_blink_for(_test_dir, "hero.png")
	assert_eq(result, "hero_blink.png")


func test_set_blink_preserves_existing_entries():
	BlinkManifestService.set_blink(_test_dir, "hero_smile.png", "hero_smile_blink.png")
	BlinkManifestService.set_blink(_test_dir, "hero_sad.png", "hero_sad_blink.png")
	assert_eq(BlinkManifestService.get_blink_for(_test_dir, "hero_smile.png"), "hero_smile_blink.png")
	assert_eq(BlinkManifestService.get_blink_for(_test_dir, "hero_sad.png"), "hero_sad_blink.png")


func test_set_blink_overwrites_existing_entry():
	BlinkManifestService.set_blink(_test_dir, "hero.png", "hero_blink_v1.png")
	BlinkManifestService.set_blink(_test_dir, "hero.png", "hero_blink_v2.png")
	var result = BlinkManifestService.get_blink_for(_test_dir, "hero.png")
	assert_eq(result, "hero_blink_v2.png")


# --- Roundtrip ---

func test_save_load_roundtrip_empty():
	BlinkManifestService.save_manifest(_test_dir, {})
	var loaded = BlinkManifestService.load_manifest(_test_dir)
	assert_eq(loaded, {})


func test_save_load_roundtrip_single_entry():
	var original = {"hero_smile.png": "hero_smile_blink.png"}
	BlinkManifestService.save_manifest(_test_dir, original)
	var loaded = BlinkManifestService.load_manifest(_test_dir)
	assert_eq(loaded, original)


func test_save_load_roundtrip_multiple_entries():
	var original = {
		"hero_smile.png": "hero_smile_blink.png",
		"hero_sad.png": "hero_sad_blink.png",
		"hero_angry.png": "hero_angry_blink.png",
	}
	BlinkManifestService.save_manifest(_test_dir, original)
	var loaded = BlinkManifestService.load_manifest(_test_dir)
	assert_eq(loaded, original)


# --- Helpers ---

func _write_manifest(content: String) -> void:
	var file_path = _test_dir + "/assets/foregrounds/blink_manifest.yaml"
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(content)
		file.close()


func _read_manifest() -> String:
	var file_path = _test_dir + "/assets/foregrounds/blink_manifest.yaml"
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return ""
	var content = file.get_as_text()
	file.close()
	return content


func _remove_dir_recursive(path: String) -> void:
	var dir = DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname == "." or fname == "..":
			fname = dir.get_next()
			continue
		var full = path + "/" + fname
		if dir.current_is_dir():
			_remove_dir_recursive(full)
		else:
			DirAccess.remove_absolute(full)
		fname = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)
