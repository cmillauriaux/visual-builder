extends GutTest

const ImageNormalizerService = preload("res://src/services/image_normalizer_service.gd")

var _test_dir: String = ""


func before_each():
	_test_dir = "user://test_normalizer_svc_" + str(randi())
	DirAccess.make_dir_recursive_absolute(_test_dir)


func after_each():
	_remove_dir_recursive(_test_dir)


func _remove_dir_recursive(path: String) -> void:
	var dir = DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if dir.current_is_dir():
			_remove_dir_recursive(path + "/" + fname)
		else:
			dir.remove(fname)
		fname = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)


func _create_colored_image(path: String, color: Color) -> void:
	var img = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(color)
	img.save_png(path)


func _create_two_tone_image(path: String, color_a: Color, color_b: Color) -> void:
	var img = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	for x in range(4):
		for y in range(4):
			if (x + y) % 2 == 0:
				img.set_pixel(x, y, color_a)
			else:
				img.set_pixel(x, y, color_b)
	img.save_png(path)


# --- analyze_image ---

func test_analyze_white_image_has_luminance_1():
	_create_colored_image(_test_dir + "/white.png", Color.WHITE)
	var stats = ImageNormalizerService.analyze_image(_test_dir + "/white.png")
	assert_almost_eq(stats["mean_luminance"], 1.0, 0.01)


func test_analyze_black_image_has_luminance_0():
	_create_colored_image(_test_dir + "/black.png", Color.BLACK)
	var stats = ImageNormalizerService.analyze_image(_test_dir + "/black.png")
	assert_almost_eq(stats["mean_luminance"], 0.0, 0.01)


func test_analyze_red_image_has_correct_channel_means():
	_create_colored_image(_test_dir + "/red.png", Color.RED)
	var stats = ImageNormalizerService.analyze_image(_test_dir + "/red.png")
	assert_almost_eq(stats["mean_r"], 1.0, 0.01)
	assert_almost_eq(stats["mean_g"], 0.0, 0.01)
	assert_almost_eq(stats["mean_b"], 0.0, 0.01)


func test_analyze_uniform_image_has_zero_std():
	_create_colored_image(_test_dir + "/gray.png", Color(0.5, 0.5, 0.5))
	var stats = ImageNormalizerService.analyze_image(_test_dir + "/gray.png")
	assert_almost_eq(stats["std_luminance"], 0.0, 0.01)


func test_analyze_two_tone_image_has_nonzero_std():
	_create_two_tone_image(_test_dir + "/mixed.png", Color.BLACK, Color.WHITE)
	var stats = ImageNormalizerService.analyze_image(_test_dir + "/mixed.png")
	assert_gt(stats["std_luminance"], 0.0)


func test_analyze_returns_correct_pixel_count():
	_create_colored_image(_test_dir + "/small.png", Color.WHITE)
	var stats = ImageNormalizerService.analyze_image(_test_dir + "/small.png")
	assert_eq(stats["pixel_count"], 16)


func test_analyze_returns_path():
	_create_colored_image(_test_dir + "/test.png", Color.WHITE)
	var stats = ImageNormalizerService.analyze_image(_test_dir + "/test.png")
	assert_eq(stats["path"], _test_dir + "/test.png")


func test_analyze_nonexistent_file_returns_empty():
	var stats = ImageNormalizerService.analyze_image(_test_dir + "/nonexistent.png")
	assert_eq(stats, {})


func test_analyze_green_image_has_correct_luminance():
	_create_colored_image(_test_dir + "/green.png", Color.GREEN)
	var stats = ImageNormalizerService.analyze_image(_test_dir + "/green.png")
	# Green luminance = 0.299*0 + 0.587*1 + 0.114*0 = 0.587
	assert_almost_eq(stats["mean_luminance"], 0.587, 0.02)


# --- normalize_image ---

func test_normalize_creates_output_file():
	_create_colored_image(_test_dir + "/source.png", Color(0.3, 0.3, 0.3))
	var img_stats = ImageNormalizerService.analyze_image(_test_dir + "/source.png")
	_create_colored_image(_test_dir + "/ref.png", Color(0.7, 0.7, 0.7))
	var ref_stats = ImageNormalizerService.analyze_image(_test_dir + "/ref.png")

	var output = _test_dir + "/output.png"
	var result = ImageNormalizerService.normalize_image(_test_dir + "/source.png", img_stats, ref_stats, output)
	assert_true(result)
	assert_true(FileAccess.file_exists(output))


func test_normalize_preserves_image_dimensions():
	_create_colored_image(_test_dir + "/source.png", Color(0.3, 0.3, 0.3))
	var img_stats = ImageNormalizerService.analyze_image(_test_dir + "/source.png")
	var ref_stats = img_stats.duplicate()

	var output = _test_dir + "/output.png"
	ImageNormalizerService.normalize_image(_test_dir + "/source.png", img_stats, ref_stats, output)
	var result_img = Image.new()
	result_img.load(output)
	assert_eq(result_img.get_width(), 4)
	assert_eq(result_img.get_height(), 4)


func test_normalize_returns_true_on_success():
	_create_colored_image(_test_dir + "/source.png", Color(0.5, 0.5, 0.5))
	var stats = ImageNormalizerService.analyze_image(_test_dir + "/source.png")
	var result = ImageNormalizerService.normalize_image(
		_test_dir + "/source.png", stats, stats, _test_dir + "/out.png"
	)
	assert_true(result)


func test_normalize_returns_false_on_bad_path():
	var stats = {"mean_r": 0.5, "mean_g": 0.5, "mean_b": 0.5, "std_luminance": 0.1}
	var result = ImageNormalizerService.normalize_image(
		_test_dir + "/nonexistent.png", stats, stats, _test_dir + "/out.png"
	)
	assert_false(result)


func test_normalize_handles_zero_std():
	_create_colored_image(_test_dir + "/uniform.png", Color(0.5, 0.5, 0.5))
	var img_stats = ImageNormalizerService.analyze_image(_test_dir + "/uniform.png")
	# std_luminance sera 0.0 pour une image uniforme
	var ref_stats = img_stats.duplicate()
	ref_stats["std_luminance"] = 0.1
	var result = ImageNormalizerService.normalize_image(
		_test_dir + "/uniform.png", img_stats, ref_stats, _test_dir + "/out.png"
	)
	assert_true(result)


func test_normalize_handles_zero_mean_channel():
	_create_colored_image(_test_dir + "/black.png", Color.BLACK)
	var img_stats = ImageNormalizerService.analyze_image(_test_dir + "/black.png")
	var ref_stats = {"mean_r": 0.5, "mean_g": 0.5, "mean_b": 0.5, "mean_luminance": 0.5, "std_luminance": 0.1}
	var result = ImageNormalizerService.normalize_image(
		_test_dir + "/black.png", img_stats, ref_stats, _test_dir + "/out.png"
	)
	assert_true(result)


func test_normalize_clamps_to_valid_range():
	_create_colored_image(_test_dir + "/bright.png", Color(0.9, 0.9, 0.9))
	var img_stats = ImageNormalizerService.analyze_image(_test_dir + "/bright.png")
	var ref_stats = img_stats.duplicate()
	ref_stats["mean_r"] = 1.0
	ref_stats["mean_g"] = 1.0
	ref_stats["mean_b"] = 1.0
	ref_stats["std_luminance"] = 0.5

	ImageNormalizerService.normalize_image(
		_test_dir + "/bright.png", img_stats, ref_stats, _test_dir + "/out.png"
	)
	var result_img = Image.new()
	result_img.load(_test_dir + "/out.png")
	result_img.convert(Image.FORMAT_RGBA8)
	for x in range(result_img.get_width()):
		for y in range(result_img.get_height()):
			var pixel = result_img.get_pixel(x, y)
			assert_true(pixel.r >= 0.0 and pixel.r <= 1.0)
			assert_true(pixel.g >= 0.0 and pixel.g <= 1.0)
			assert_true(pixel.b >= 0.0 and pixel.b <= 1.0)


func test_normalize_preserves_alpha():
	var img = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.5, 0.5, 0.5, 0.3))
	img.save_png(_test_dir + "/alpha.png")

	var img_stats = ImageNormalizerService.analyze_image(_test_dir + "/alpha.png")
	var ref_stats = img_stats.duplicate()
	ref_stats["mean_r"] = 0.8
	ref_stats["mean_g"] = 0.8
	ref_stats["mean_b"] = 0.8

	ImageNormalizerService.normalize_image(
		_test_dir + "/alpha.png", img_stats, ref_stats, _test_dir + "/out.png"
	)
	var result_img = Image.new()
	result_img.load(_test_dir + "/out.png")
	result_img.convert(Image.FORMAT_RGBA8)
	var pixel = result_img.get_pixel(0, 0)
	assert_almost_eq(pixel.a, 0.3, 0.02)


func test_normalize_adjusts_brightness():
	_create_colored_image(_test_dir + "/dark.png", Color(0.2, 0.2, 0.2))
	var dark_stats = ImageNormalizerService.analyze_image(_test_dir + "/dark.png")

	_create_colored_image(_test_dir + "/bright.png", Color(0.8, 0.8, 0.8))
	var bright_stats = ImageNormalizerService.analyze_image(_test_dir + "/bright.png")

	ImageNormalizerService.normalize_image(
		_test_dir + "/dark.png", dark_stats, bright_stats, _test_dir + "/out.png"
	)
	var out_stats = ImageNormalizerService.analyze_image(_test_dir + "/out.png")
	# La luminosité de la sortie devrait être plus proche de la référence
	assert_gt(out_stats["mean_luminance"], dark_stats["mean_luminance"])


# --- cleanup_temp_dir ---

func test_cleanup_removes_files():
	var temp_dir = _test_dir + "/temp"
	DirAccess.make_dir_recursive_absolute(temp_dir)
	_create_colored_image(temp_dir + "/a.png", Color.WHITE)
	_create_colored_image(temp_dir + "/b.png", Color.BLACK)
	ImageNormalizerService.cleanup_temp_dir(temp_dir)
	assert_false(FileAccess.file_exists(temp_dir + "/a.png"))
	assert_false(FileAccess.file_exists(temp_dir + "/b.png"))


func test_cleanup_removes_directory():
	var temp_dir = _test_dir + "/temp"
	DirAccess.make_dir_recursive_absolute(temp_dir)
	_create_colored_image(temp_dir + "/a.png", Color.WHITE)
	ImageNormalizerService.cleanup_temp_dir(temp_dir)
	assert_null(DirAccess.open(temp_dir))


func test_cleanup_nonexistent_dir_no_crash():
	ImageNormalizerService.cleanup_temp_dir(_test_dir + "/nonexistent")
	assert_true(true, "Should not crash")


# --- apply_normalized_images ---

func test_apply_replaces_originals():
	_create_colored_image(_test_dir + "/original.png", Color.WHITE)
	var temp_dir = _test_dir + "/temp"
	DirAccess.make_dir_recursive_absolute(temp_dir)
	_create_colored_image(temp_dir + "/original.png", Color.RED)

	var mappings = [{"original": _test_dir + "/original.png", "temp": temp_dir + "/original.png"}]
	ImageNormalizerService.apply_normalized_images(mappings)

	var result_img = Image.new()
	result_img.load(_test_dir + "/original.png")
	result_img.convert(Image.FORMAT_RGBA8)
	var pixel = result_img.get_pixel(0, 0)
	assert_almost_eq(pixel.r, 1.0, 0.02)
	assert_almost_eq(pixel.g, 0.0, 0.02)


func test_apply_returns_count():
	_create_colored_image(_test_dir + "/a.png", Color.WHITE)
	_create_colored_image(_test_dir + "/b.png", Color.WHITE)
	var temp_dir = _test_dir + "/temp"
	DirAccess.make_dir_recursive_absolute(temp_dir)
	_create_colored_image(temp_dir + "/a.png", Color.RED)
	_create_colored_image(temp_dir + "/b.png", Color.GREEN)

	var mappings = [
		{"original": _test_dir + "/a.png", "temp": temp_dir + "/a.png"},
		{"original": _test_dir + "/b.png", "temp": temp_dir + "/b.png"}
	]
	var count = ImageNormalizerService.apply_normalized_images(mappings)
	assert_eq(count, 2)


func test_apply_missing_temp_file_skipped():
	_create_colored_image(_test_dir + "/a.png", Color.WHITE)
	var mappings = [{"original": _test_dir + "/a.png", "temp": _test_dir + "/nonexistent.png"}]
	var count = ImageNormalizerService.apply_normalized_images(mappings)
	assert_eq(count, 0)


# --- get_temp_path ---

func test_temp_path_uses_original_filename():
	var result = ImageNormalizerService.get_temp_path("/path/to/forest.png", "/tmp/dir", "bg_")
	assert_eq(result, "/tmp/dir/bg_forest.png")


func test_temp_path_with_fg_prefix():
	var result = ImageNormalizerService.get_temp_path("/path/to/hero.png", "/tmp/dir", "fg_")
	assert_eq(result, "/tmp/dir/fg_hero.png")
