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

func test_update_story_references_null_story():
	var svc = ImageRenameServiceScript
	var count = svc.update_story_references(null, "old.png", "new.png")
	assert_eq(count, 0)


# --- _paths_match ---

func test_paths_match_exact_match():
	var svc = ImageRenameServiceScript
	assert_true(svc._paths_match("assets/bg/img.png", "assets/bg/img.png", "assets/bg/img.png"))

func test_paths_match_via_assets_relative():
	var svc = ImageRenameServiceScript
	assert_true(svc._paths_match("assets/bg/img.png", "C:/path/assets/bg/img.png", "assets/bg/img.png"))

func test_paths_match_empty_stored_path():
	var svc = ImageRenameServiceScript
	assert_false(svc._paths_match("", "old.png", "old.png"))

func test_paths_match_no_match():
	var svc = ImageRenameServiceScript
	assert_false(svc._paths_match("assets/bg/other.png", "assets/bg/img.png", "assets/bg/img.png"))


# --- rename ---

func test_rename_invalid_name_returns_error():
	var svc = ImageRenameServiceScript
	var result = svc.rename("some/path/img.png", "invalid name!")
	assert_false(result["ok"])
	assert_ne(result["error"], "")
	assert_false(result["same_name"])

func test_rename_same_name_returns_same_name():
	var svc = ImageRenameServiceScript
	# old_path has basename "img" → trimmed "img" == "img" → same_name
	var result = svc.rename("some/path/img.png", "img")
	assert_true(result["ok"])
	assert_true(result["same_name"])
	assert_eq(result["new_path"], "some/path/img.png")

func test_rename_conflict_returns_error():
	var svc = ImageRenameServiceScript
	# Create two files so the target already exists
	var user_dir = OS.get_user_data_dir()
	var old_abs = user_dir.path_join("test_rename_old.png")
	var new_abs = user_dir.path_join("test_rename_new.png")
	var f1 = FileAccess.open("user://test_rename_old.png", FileAccess.WRITE)
	if f1: f1.store_string("a"); f1.close()
	var f2 = FileAccess.open("user://test_rename_new.png", FileAccess.WRITE)
	if f2: f2.store_string("b"); f2.close()

	var result = svc.rename(old_abs, "test_rename_new")
	assert_false(result["ok"])
	assert_eq(result["error"], "Ce nom est déjà utilisé.")

	DirAccess.remove_absolute(old_abs)
	DirAccess.remove_absolute(new_abs)

func test_rename_success():
	var svc = ImageRenameServiceScript
	var user_dir = OS.get_user_data_dir()
	var old_abs = user_dir.path_join("test_rename_src.png")
	var new_abs = user_dir.path_join("test_rename_dst.png")

	var f = FileAccess.open("user://test_rename_src.png", FileAccess.WRITE)
	if f: f.store_string("data"); f.close()

	# Ensure destination doesn't exist
	if FileAccess.file_exists("user://test_rename_dst.png"):
		DirAccess.remove_absolute(new_abs)

	var result = svc.rename(old_abs, "test_rename_dst")
	assert_true(result["ok"])
	assert_false(result["same_name"])
	assert_eq(result["new_path"], new_abs)
	assert_false(FileAccess.file_exists("user://test_rename_src.png"))
	assert_true(FileAccess.file_exists("user://test_rename_dst.png"))

	DirAccess.remove_absolute(new_abs)
