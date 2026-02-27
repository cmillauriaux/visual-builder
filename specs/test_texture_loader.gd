extends GutTest

const TextureLoaderScript = preload("res://src/ui/texture_loader.gd")


func test_empty_path_returns_null():
	var result = TextureLoaderScript.load_texture("")
	assert_null(result)

func test_nonexistent_path_returns_null():
	var result = TextureLoaderScript.load_texture("/nonexistent/path/image.png")
	assert_null(result)

func test_invalid_resource_path_returns_null():
	var result = TextureLoaderScript.load_texture("res://nonexistent_resource.png")
	assert_null(result)

func test_valid_godot_resource():
	# icon.svg is the default Godot icon included in every project
	var result = TextureLoaderScript.load_texture("res://icon.svg")
	assert_not_null(result)

func test_returns_texture_type_for_resource():
	var result = TextureLoaderScript.load_texture("res://icon.svg")
	assert_true(result is Texture2D)
