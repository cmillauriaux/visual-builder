extends GutTest

const ExportServiceScript = preload("res://src/services/export_service.gd")
var _service: RefCounted
var _temp_dir: String


func before_each():
	_service = ExportServiceScript.new()
	_temp_dir = "user://test_icon_gen_" + str(Time.get_ticks_msec())
	DirAccess.make_dir_recursive_absolute(_temp_dir)
	DirAccess.make_dir_recursive_absolute(_temp_dir + "/assets/icons")


func after_each():
	_remove_dir_recursive(_temp_dir)


func _create_test_icon(width: int, height: int) -> String:
	var img = Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(Color.RED)
	var path = _temp_dir + "/source_icon.png"
	img.save_png(path)
	return path


func _remove_dir_recursive(path: String) -> void:
	var dir = DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname != "." and fname != "..":
			var full = path + "/" + fname
			if dir.current_is_dir():
				_remove_dir_recursive(full)
			else:
				DirAccess.remove_absolute(full)
		fname = dir.get_next()
	DirAccess.remove_absolute(path)


# --- Tests ---

func test_generate_app_icons_creates_pwa_icons():
	var icon_src = _create_test_icon(1024, 1024)
	var log_path = _temp_dir + "/test.log"
	var f = FileAccess.open(log_path, FileAccess.WRITE)
	f.close()

	_service._generate_app_icons(icon_src, _temp_dir, log_path)

	assert_true(FileAccess.file_exists(_temp_dir + "/assets/icons/icon_144x144.png"))
	assert_true(FileAccess.file_exists(_temp_dir + "/assets/icons/icon_180x180.png"))
	assert_true(FileAccess.file_exists(_temp_dir + "/assets/icons/icon_512x512.png"))


func test_generate_app_icons_correct_sizes():
	var icon_src = _create_test_icon(1024, 1024)
	var log_path = _temp_dir + "/test.log"
	var f = FileAccess.open(log_path, FileAccess.WRITE)
	f.close()

	_service._generate_app_icons(icon_src, _temp_dir, log_path)

	var img_144 = Image.new()
	img_144.load(_temp_dir + "/assets/icons/icon_144x144.png")
	assert_eq(img_144.get_width(), 144)
	assert_eq(img_144.get_height(), 144)

	var img_180 = Image.new()
	img_180.load(_temp_dir + "/assets/icons/icon_180x180.png")
	assert_eq(img_180.get_width(), 180)
	assert_eq(img_180.get_height(), 180)

	var img_512 = Image.new()
	img_512.load(_temp_dir + "/assets/icons/icon_512x512.png")
	assert_eq(img_512.get_width(), 512)
	assert_eq(img_512.get_height(), 512)


func test_generate_app_icons_creates_project_icon():
	var icon_src = _create_test_icon(1024, 1024)
	var log_path = _temp_dir + "/test.log"
	var f = FileAccess.open(log_path, FileAccess.WRITE)
	f.close()

	_service._generate_app_icons(icon_src, _temp_dir, log_path)

	assert_true(FileAccess.file_exists(_temp_dir + "/app_icon.png"))
	var img = Image.new()
	img.load(_temp_dir + "/app_icon.png")
	assert_eq(img.get_width(), 512)
	assert_eq(img.get_height(), 512)


func test_generate_app_icons_with_small_source():
	var icon_src = _create_test_icon(64, 64)
	var log_path = _temp_dir + "/test.log"
	var f = FileAccess.open(log_path, FileAccess.WRITE)
	f.close()

	_service._generate_app_icons(icon_src, _temp_dir, log_path)

	# Doit quand même fonctionner (upscale)
	assert_true(FileAccess.file_exists(_temp_dir + "/assets/icons/icon_512x512.png"))


func test_generate_app_icons_invalid_source():
	var log_path = _temp_dir + "/test.log"
	var f = FileAccess.open(log_path, FileAccess.WRITE)
	f.close()

	# Ne doit pas crasher avec un fichier inexistant
	_service._generate_app_icons(_temp_dir + "/nonexistent.png", _temp_dir, log_path)

	assert_false(FileAccess.file_exists(_temp_dir + "/assets/icons/icon_144x144.png"))
