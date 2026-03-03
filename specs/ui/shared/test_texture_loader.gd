extends GutTest

func test_empty_path_returns_null():
	var result = TextureLoader.load_texture("")
	assert_null(result)

func test_nonexistent_path_returns_null():
	var result = TextureLoader.load_texture("/nonexistent/path/image.png")
	assert_null(result)

func test_invalid_resource_path_returns_null():
	var result = TextureLoader.load_texture("res://nonexistent_resource.png")
	assert_null(result)

func test_valid_godot_resource():
	# icon.svg is the default Godot icon included in every project
	var result = TextureLoader.load_texture("res://icon.svg")
	assert_not_null(result)

func test_returns_texture_type_for_resource():
	var result = TextureLoader.load_texture("res://icon.svg")
	assert_true(result is Texture2D)

func test_relative_path_resolution():
	var base = OS.get_user_data_dir() + "/test_assets_relative"
	DirAccess.make_dir_recursive_absolute(base + "/assets/backgrounds")
	var img_path = base + "/assets/backgrounds/bg.png"
	var img = Image.create(1, 1, false, Image.FORMAT_RGB8)
	img.save_png(img_path)
	
	TextureLoader.base_dir = base
	var result = TextureLoader.load_texture("assets/backgrounds/bg.png")
	assert_not_null(result, "Devrait charger l'image via le chemin relatif + base_dir")
	
	# Cleanup
	DirAccess.remove_absolute(img_path)
	DirAccess.remove_absolute(base + "/assets/backgrounds")
	DirAccess.remove_absolute(base + "/assets")
	DirAccess.remove_absolute(base)
	TextureLoader.base_dir = ""

func test_migration_fallback_loading():
	var base = OS.get_user_data_dir() + "/test_assets_fallback"
	DirAccess.make_dir_recursive_absolute(base + "/assets/backgrounds")
	var img_path = base + "/assets/backgrounds/bg.png"
	var img = Image.create(1, 1, false, Image.FORMAT_RGB8)
	img.save_png(img_path)
	
	TextureLoader.base_dir = base
	# Simuler un chemin absolu d'une autre machine
	var other_machine_path = "/Users/claude/stories/MyStory/assets/backgrounds/bg.png"
	var result = TextureLoader.load_texture(other_machine_path)
	assert_not_null(result, "Devrait charger l'image via le fallback 'assets/'")
	
	# Cleanup
	DirAccess.remove_absolute(img_path)
	DirAccess.remove_absolute(base + "/assets/backgrounds")
	DirAccess.remove_absolute(base + "/assets")
	DirAccess.remove_absolute(base)
	TextureLoader.base_dir = ""
