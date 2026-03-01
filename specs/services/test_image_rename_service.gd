extends GutTest

const ImageRenameService = preload("res://src/services/image_rename_service.gd")
const ImageCategoryService = preload("res://src/services/image_category_service.gd")
const StoryScript = preload("res://src/models/story.gd")
const ChapterScript = preload("res://src/models/chapter.gd")
const SceneDataScript = preload("res://src/models/scene_data.gd")
const SequenceScript = preload("res://src/models/sequence.gd")
const ForegroundScript = preload("res://src/models/foreground.gd")
const DialogueScript = preload("res://src/models/dialogue.gd")

var _test_dir: String = ""


func before_each():
	_test_dir = "user://test_rename_svc_" + str(randi())
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


func _create_image(path: String) -> void:
	var img = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	img.save_png(path)


# --- validate_name_format ---

func test_validate_empty_name_returns_error():
	assert_ne(ImageRenameService.validate_name_format(""), "")


func test_validate_whitespace_only_returns_error():
	assert_ne(ImageRenameService.validate_name_format("   "), "")


func test_validate_valid_simple_name_returns_empty():
	assert_eq(ImageRenameService.validate_name_format("my_image"), "")


func test_validate_name_with_dash_is_valid():
	assert_eq(ImageRenameService.validate_name_format("my-image"), "")


func test_validate_name_with_digits_is_valid():
	assert_eq(ImageRenameService.validate_name_format("image01"), "")


func test_validate_name_with_dot_is_valid():
	assert_eq(ImageRenameService.validate_name_format("my.image"), "")


func test_validate_name_with_space_is_invalid():
	assert_ne(ImageRenameService.validate_name_format("my image"), "")


func test_validate_name_with_slash_is_invalid():
	assert_ne(ImageRenameService.validate_name_format("my/image"), "")


func test_validate_name_with_special_chars_is_invalid():
	assert_ne(ImageRenameService.validate_name_format("my@image!"), "")


# --- rename ---

func test_rename_empty_name_fails():
	_create_image(_test_dir + "/test.png")
	var result = ImageRenameService.rename(_test_dir + "/test.png", "")
	assert_false(result["ok"])
	assert_ne(result["error"], "")


func test_rename_invalid_chars_fails():
	_create_image(_test_dir + "/test.png")
	var result = ImageRenameService.rename(_test_dir + "/test.png", "my image")
	assert_false(result["ok"])
	assert_ne(result["error"], "")


func test_rename_same_name_returns_ok_with_same_flag():
	_create_image(_test_dir + "/forest.png")
	var result = ImageRenameService.rename(_test_dir + "/forest.png", "forest")
	assert_true(result["ok"])
	assert_true(result["same_name"])
	assert_eq(result["new_path"], _test_dir + "/forest.png")


func test_rename_conflict_fails():
	_create_image(_test_dir + "/forest.png")
	_create_image(_test_dir + "/ocean.png")
	var result = ImageRenameService.rename(_test_dir + "/forest.png", "ocean")
	assert_false(result["ok"])
	assert_ne(result["error"], "")


func test_rename_valid_renames_file_on_disk():
	_create_image(_test_dir + "/forest.png")
	var result = ImageRenameService.rename(_test_dir + "/forest.png", "jungle")
	assert_true(result["ok"])
	assert_false(FileAccess.file_exists(_test_dir + "/forest.png"))
	assert_true(FileAccess.file_exists(_test_dir + "/jungle.png"))


func test_rename_valid_returns_new_path():
	_create_image(_test_dir + "/forest.png")
	var result = ImageRenameService.rename(_test_dir + "/forest.png", "jungle")
	assert_eq(result["new_path"], _test_dir + "/jungle.png")


func test_rename_preserves_extension():
	_create_image(_test_dir + "/image.png")
	var result = ImageRenameService.rename(_test_dir + "/image.png", "renamed")
	assert_eq(result["new_path"].get_extension(), "png")


func test_rename_same_name_is_not_same_name():
	_create_image(_test_dir + "/forest.png")
	var result = ImageRenameService.rename(_test_dir + "/forest.png", "jungle")
	assert_false(result["same_name"])


func test_rename_transfers_categories():
	DirAccess.make_dir_recursive_absolute(_test_dir + "/assets/backgrounds")
	_create_image(_test_dir + "/assets/backgrounds/forest.png")
	var cat_service = ImageCategoryService.new()
	cat_service.assign_image_to_category("backgrounds/forest.png", "Base")
	var result = ImageRenameService.rename(
		_test_dir + "/assets/backgrounds/forest.png", "jungle", cat_service
	)
	assert_true(result["ok"])
	assert_true(cat_service.is_image_in_category("backgrounds/jungle.png", "Base"))
	assert_false(cat_service.is_image_in_category("backgrounds/forest.png", "Base"))


func test_rename_without_category_service_does_not_crash():
	_create_image(_test_dir + "/test.png")
	var result = ImageRenameService.rename(_test_dir + "/test.png", "renamed")
	assert_true(result["ok"])


# --- update_story_references ---

func test_update_story_menu_background():
	var story = StoryScript.new()
	story.menu_background = "/path/to/bg.png"
	var count = ImageRenameService.update_story_references(
		story, "/path/to/bg.png", "/path/to/new_bg.png"
	)
	assert_eq(story.menu_background, "/path/to/new_bg.png")
	assert_eq(count, 1)


func test_update_story_sequence_background():
	var story = StoryScript.new()
	var seq = SequenceScript.new()
	seq.background = "/path/to/bg.png"
	var scene = SceneDataScript.new()
	scene.sequences = [seq]
	var chapter = ChapterScript.new()
	chapter.scenes = [scene]
	story.chapters = [chapter]
	var count = ImageRenameService.update_story_references(
		story, "/path/to/bg.png", "/path/to/new.png"
	)
	assert_eq(seq.background, "/path/to/new.png")
	assert_eq(count, 1)


func test_update_story_sequence_foreground():
	var story = StoryScript.new()
	var fg = ForegroundScript.new()
	fg.image = "/path/to/hero.png"
	var seq = SequenceScript.new()
	seq.foregrounds = [fg]
	var scene = SceneDataScript.new()
	scene.sequences = [seq]
	var chapter = ChapterScript.new()
	chapter.scenes = [scene]
	story.chapters = [chapter]
	var count = ImageRenameService.update_story_references(
		story, "/path/to/hero.png", "/path/to/new.png"
	)
	assert_eq(fg.image, "/path/to/new.png")
	assert_eq(count, 1)


func test_update_story_dialogue_foreground():
	var story = StoryScript.new()
	var fg = ForegroundScript.new()
	fg.image = "/path/to/char.png"
	var dlg = DialogueScript.new()
	dlg.foregrounds = [fg]
	var seq = SequenceScript.new()
	seq.dialogues = [dlg]
	var scene = SceneDataScript.new()
	scene.sequences = [seq]
	var chapter = ChapterScript.new()
	chapter.scenes = [scene]
	story.chapters = [chapter]
	var count = ImageRenameService.update_story_references(
		story, "/path/to/char.png", "/path/to/new.png"
	)
	assert_eq(fg.image, "/path/to/new.png")
	assert_eq(count, 1)


func test_update_does_not_touch_unrelated_paths():
	var story = StoryScript.new()
	story.menu_background = "/path/to/other.png"
	ImageRenameService.update_story_references(story, "/path/to/bg.png", "/path/to/new.png")
	assert_eq(story.menu_background, "/path/to/other.png")


func test_update_null_story_returns_zero():
	var count = ImageRenameService.update_story_references(null, "/old.png", "/new.png")
	assert_eq(count, 0)


func test_update_counts_all_references():
	var story = StoryScript.new()
	story.menu_background = "/path/to/bg.png"
	var fg1 = ForegroundScript.new()
	fg1.image = "/path/to/bg.png"
	var seq = SequenceScript.new()
	seq.background = "/path/to/bg.png"
	seq.foregrounds = [fg1]
	var scene = SceneDataScript.new()
	scene.sequences = [seq]
	var chapter = ChapterScript.new()
	chapter.scenes = [scene]
	story.chapters = [chapter]
	var count = ImageRenameService.update_story_references(
		story, "/path/to/bg.png", "/path/to/new.png"
	)
	assert_eq(count, 3)
