extends GutTest

var ImageRenameServiceScript
var StoryModelScript

func before_each():
	ImageRenameServiceScript = load("res://src/services/image_rename_service.gd")
	StoryModelScript = load("res://src/models/story.gd")

func test_validate_name_format_valid():
	var svc = ImageRenameServiceScript
	assert_eq(svc.validate_name_format("image_123"), "")
	assert_eq(svc.validate_name_format("hero-sprite.new"), "")

func test_validate_name_format_invalid():
	var svc = ImageRenameServiceScript
	assert_ne(svc.validate_name_format(""), "")
	assert_ne(svc.validate_name_format("image space"), "")
	assert_ne(svc.validate_name_format("image!"), "")

func test_to_assets_relative():
	var svc = ImageRenameServiceScript
	assert_eq(svc._to_assets_relative("C:/Games/Story/assets/bg/img.png"), "assets/bg/img.png")
	assert_eq(svc._to_assets_relative("/home/user/assets/fg/char.png"), "assets/fg/char.png")
	assert_eq(svc._to_assets_relative("assets/bg/img.png"), "assets/bg/img.png")
	assert_eq(svc._to_assets_relative("other/path.png"), "")

func test_update_story_references():
	var svc = ImageRenameServiceScript
	var story = StoryModelScript.new()
	story.menu_background = "assets/backgrounds/old.png"
	
	var count = svc.update_story_references(story, "C:/Path/assets/backgrounds/old.png", "assets/backgrounds/new.png")
	
	assert_eq(count, 1)
	assert_eq(story.menu_background, "assets/backgrounds/new.png")
