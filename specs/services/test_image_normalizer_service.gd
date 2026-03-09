extends GutTest

var ImageNormalizerServiceScript

func before_each():
	ImageNormalizerServiceScript = load("res://src/services/image_normalizer_service.gd")

func test_get_temp_path():
	var service = ImageNormalizerServiceScript
	var path = service.get_temp_path("res://assets/bg.png", "user://temp", "norm_")
	assert_eq(path, "user://temp/norm_bg.png")

func test_analyze_nonexistent_image():
	var service = ImageNormalizerServiceScript
	var stats = service.analyze_image("res://nonexistent.png")
	assert_eq(stats, {})

func test_save_image_png():
	var service = ImageNormalizerServiceScript
	var img = Image.create(10, 10, false, Image.FORMAT_RGBA8)
	var path = "user://test_save.png"
	var success = service._save_image(img, path, "png")
	assert_true(success)
	assert_true(FileAccess.file_exists(path))
	DirAccess.remove_absolute(path)

func test_analyze_image_basic():
	var service = ImageNormalizerServiceScript
	var img = Image.create(10, 10, false, Image.FORMAT_RGBA8)
	img.fill(Color.RED)
	var path = "user://test_analyze.png"
	img.save_png(path)
	
	var stats = service.analyze_image(path)
	assert_not_null(stats)
	assert_eq(stats["path"], path)
	assert_almost_eq(stats["mean_r"], 1.0, 0.01)
	assert_almost_eq(stats["mean_g"], 0.0, 0.01)
	assert_almost_eq(stats["mean_b"], 0.0, 0.01)
	
	DirAccess.remove_absolute(path)
