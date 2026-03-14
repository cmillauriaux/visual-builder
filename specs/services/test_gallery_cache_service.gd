extends "res://addons/gut/test.gd"

const GalleryCacheServiceScript = preload("res://src/services/gallery_cache_service.gd")

var _test_dir: String


func before_each():
	GalleryCacheServiceScript.clear_all()
	_test_dir = OS.get_user_data_dir() + "/test_gallery_cache"
	DirAccess.make_dir_recursive_absolute(_test_dir)


func after_each():
	GalleryCacheServiceScript.clear_all()
	# Nettoyer les fichiers de test
	var dir = DirAccess.open(_test_dir)
	if dir:
		dir.list_dir_begin()
		var fname = dir.get_next()
		while fname != "":
			if not dir.current_is_dir():
				dir.remove(fname)
			fname = dir.get_next()
		dir.list_dir_end()
	DirAccess.remove_absolute(_test_dir)


func _create_test_image(filename: String) -> String:
	var path = _test_dir + "/" + filename
	var img = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.RED)
	img.save_png(path)
	return path


func test_get_texture_returns_null_for_missing_file():
	var tex = GalleryCacheServiceScript.get_texture("/nonexistent/path.png")
	assert_null(tex, "Should return null for missing file")


func test_get_texture_loads_image():
	var path = _create_test_image("test.png")

	var tex = GalleryCacheServiceScript.get_texture(path)

	assert_not_null(tex, "Should return a texture")
	assert_true(tex is ImageTexture, "Should be an ImageTexture")


func test_get_texture_caches_result():
	var path = _create_test_image("cached.png")

	var tex1 = GalleryCacheServiceScript.get_texture(path)
	var tex2 = GalleryCacheServiceScript.get_texture(path)

	assert_same(tex1, tex2, "Should return the same cached instance")


func test_get_file_list_empty_dir():
	var result = GalleryCacheServiceScript.get_file_list(_test_dir, ["png"])

	assert_eq(result.size(), 0, "Empty dir should return empty list")


func test_get_file_list_filters_by_extension():
	_create_test_image("a.png")
	_create_test_image("b.png")
	# Créer un fichier non-image
	var f = FileAccess.open(_test_dir + "/c.txt", FileAccess.WRITE)
	f.store_string("not an image")
	f.close()

	var result = GalleryCacheServiceScript.get_file_list(_test_dir, ["png"])

	assert_eq(result.size(), 2, "Should find 2 png files")
	assert_true(result[0].ends_with("a.png"))
	assert_true(result[1].ends_with("b.png"))


func test_get_file_list_caches_result():
	_create_test_image("x.png")

	var r1 = GalleryCacheServiceScript.get_file_list(_test_dir, ["png"])
	var r2 = GalleryCacheServiceScript.get_file_list(_test_dir, ["png"])

	assert_same(r1, r2, "Should return the same cached array")


func test_get_file_list_invalid_dir():
	var result = GalleryCacheServiceScript.get_file_list("/nonexistent/dir", ["png"])

	assert_eq(result.size(), 0, "Invalid dir should return empty list")


func test_clear_all():
	var path = _create_test_image("clear.png")
	GalleryCacheServiceScript.get_texture(path)
	GalleryCacheServiceScript.get_file_list(_test_dir, ["png"])

	GalleryCacheServiceScript.clear_all()

	# After clear, a new call should not return the same cached instance
	var tex = GalleryCacheServiceScript.get_texture(path)
	assert_not_null(tex, "Should still load after clear")


func test_clear_path():
	var path = _create_test_image("specific.png")
	GalleryCacheServiceScript.get_texture(path)
	GalleryCacheServiceScript.get_file_list(_test_dir, ["png"])

	GalleryCacheServiceScript.clear_path(path)

	# Le cache du dossier parent doit aussi être vidé
	# (un nouvel appel recalcule la liste)
	_create_test_image("extra.png")
	var result = GalleryCacheServiceScript.get_file_list(_test_dir, ["png"])
	assert_eq(result.size(), 2, "Should re-scan after clear_path")


func test_clear_dir():
	_create_test_image("dir1.png")
	GalleryCacheServiceScript.get_file_list(_test_dir, ["png"])

	GalleryCacheServiceScript.clear_dir(_test_dir)

	_create_test_image("dir2.png")
	var result = GalleryCacheServiceScript.get_file_list(_test_dir, ["png"])
	assert_eq(result.size(), 2, "Should re-scan after clear_dir")


func test_get_file_list_sorted():
	_create_test_image("c.png")
	_create_test_image("a.png")
	_create_test_image("b.png")

	var result = GalleryCacheServiceScript.get_file_list(_test_dir, ["png"])

	assert_true(result[0].ends_with("a.png"))
	assert_true(result[1].ends_with("b.png"))
	assert_true(result[2].ends_with("c.png"))
