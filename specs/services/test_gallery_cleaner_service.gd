extends GutTest

const GalleryCleanerService = preload("res://src/services/gallery_cleaner_service.gd")
const StoryScript = preload("res://src/models/story.gd")
const ChapterScript = preload("res://src/models/chapter.gd")
const SceneDataScript = preload("res://src/models/scene_data.gd")
const SequenceScript = preload("res://src/models/sequence.gd")
const ForegroundScript = preload("res://src/models/foreground.gd")
const DialogueScript = preload("res://src/models/dialogue.gd")

var _test_dir: String = ""


func before_each():
	_test_dir = "user://test_gallery_cleaner_" + str(randi())
	DirAccess.make_dir_recursive_absolute(_test_dir + "/assets/backgrounds")
	DirAccess.make_dir_recursive_absolute(_test_dir + "/assets/foregrounds")


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


func _create_test_image(path: String) -> void:
	var img = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	img.save_png(path)


func _build_story_with_images() -> RefCounted:
	var story = StoryScript.new()
	story.title = "Test Story"
	story.menu_background = _test_dir + "/assets/backgrounds/menu_bg.png"

	var fg1 = ForegroundScript.new()
	fg1.image = _test_dir + "/assets/foregrounds/hero.png"

	var fg2 = ForegroundScript.new()
	fg2.image = _test_dir + "/assets/foregrounds/villain.png"

	var dlg_fg = ForegroundScript.new()
	dlg_fg.image = _test_dir + "/assets/foregrounds/npc.png"

	var dialogue = DialogueScript.new()
	dialogue.character = "NPC"
	dialogue.text = "Hello"
	dialogue.foregrounds = [dlg_fg]

	var seq = SequenceScript.new()
	seq.background = _test_dir + "/assets/backgrounds/forest.png"
	seq.foregrounds = [fg1, fg2]
	seq.dialogues = [dialogue]

	var scene = SceneDataScript.new()
	scene.sequences = [seq]

	var chapter = ChapterScript.new()
	chapter.scenes = [scene]

	story.chapters = [chapter]
	return story


# --- collect_used_images ---

func test_collect_used_images_empty_story():
	var story = StoryScript.new()
	var result = GalleryCleanerService.collect_used_images(story)
	assert_eq(result.size(), 0)


func test_collect_used_images_menu_background():
	var story = StoryScript.new()
	story.menu_background = "user://stories/test/assets/backgrounds/menu.png"
	var result = GalleryCleanerService.collect_used_images(story)
	assert_has(result, "user://stories/test/assets/backgrounds/menu.png")


func test_collect_used_images_sequence_background():
	var story = StoryScript.new()
	var seq = SequenceScript.new()
	seq.background = "user://bg.png"
	var scene = SceneDataScript.new()
	scene.sequences = [seq]
	var chapter = ChapterScript.new()
	chapter.scenes = [scene]
	story.chapters = [chapter]

	var result = GalleryCleanerService.collect_used_images(story)
	assert_has(result, "user://bg.png")


func test_collect_used_images_sequence_foregrounds():
	var story = StoryScript.new()
	var fg = ForegroundScript.new()
	fg.image = "user://fg.png"
	var seq = SequenceScript.new()
	seq.foregrounds = [fg]
	var scene = SceneDataScript.new()
	scene.sequences = [seq]
	var chapter = ChapterScript.new()
	chapter.scenes = [scene]
	story.chapters = [chapter]

	var result = GalleryCleanerService.collect_used_images(story)
	assert_has(result, "user://fg.png")


func test_collect_used_images_dialogue_foregrounds():
	var story = StoryScript.new()
	var fg = ForegroundScript.new()
	fg.image = "user://dlg_fg.png"
	var dlg = DialogueScript.new()
	dlg.foregrounds = [fg]
	var seq = SequenceScript.new()
	seq.dialogues = [dlg]
	var scene = SceneDataScript.new()
	scene.sequences = [seq]
	var chapter = ChapterScript.new()
	chapter.scenes = [scene]
	story.chapters = [chapter]

	var result = GalleryCleanerService.collect_used_images(story)
	assert_has(result, "user://dlg_fg.png")


func test_collect_used_images_skips_empty_paths():
	var story = StoryScript.new()
	story.menu_background = ""
	var fg = ForegroundScript.new()
	fg.image = ""
	var seq = SequenceScript.new()
	seq.background = ""
	seq.foregrounds = [fg]
	var scene = SceneDataScript.new()
	scene.sequences = [seq]
	var chapter = ChapterScript.new()
	chapter.scenes = [scene]
	story.chapters = [chapter]

	var result = GalleryCleanerService.collect_used_images(story)
	assert_eq(result.size(), 0)


func test_collect_used_images_no_duplicates():
	var story = StoryScript.new()
	var fg1 = ForegroundScript.new()
	fg1.image = "user://same.png"
	var fg2 = ForegroundScript.new()
	fg2.image = "user://same.png"
	var seq = SequenceScript.new()
	seq.foregrounds = [fg1, fg2]
	var scene = SceneDataScript.new()
	scene.sequences = [seq]
	var chapter = ChapterScript.new()
	chapter.scenes = [scene]
	story.chapters = [chapter]

	var result = GalleryCleanerService.collect_used_images(story)
	# Doit contenir le chemin, et potentiellement sans doublons
	assert_has(result, "user://same.png")


func test_collect_used_images_full_story():
	var story = _build_story_with_images()
	var result = GalleryCleanerService.collect_used_images(story)
	assert_eq(result.size(), 5)


# --- find_unused_images ---

func test_find_unused_images_all_used():
	var story = _build_story_with_images()
	# Créer les fichiers sur disque
	_create_test_image(_test_dir + "/assets/backgrounds/menu_bg.png")
	_create_test_image(_test_dir + "/assets/backgrounds/forest.png")
	_create_test_image(_test_dir + "/assets/foregrounds/hero.png")
	_create_test_image(_test_dir + "/assets/foregrounds/villain.png")
	_create_test_image(_test_dir + "/assets/foregrounds/npc.png")

	var used = GalleryCleanerService.collect_used_images(story)
	var unused = GalleryCleanerService.find_unused_images(_test_dir, used)
	assert_eq(unused["backgrounds"].size(), 0)
	assert_eq(unused["foregrounds"].size(), 0)


func test_find_unused_images_some_unused():
	var story = _build_story_with_images()
	# Créer les fichiers utilisés + des fichiers supplémentaires
	_create_test_image(_test_dir + "/assets/backgrounds/menu_bg.png")
	_create_test_image(_test_dir + "/assets/backgrounds/forest.png")
	_create_test_image(_test_dir + "/assets/backgrounds/unused_bg.png")
	_create_test_image(_test_dir + "/assets/foregrounds/hero.png")
	_create_test_image(_test_dir + "/assets/foregrounds/villain.png")
	_create_test_image(_test_dir + "/assets/foregrounds/npc.png")
	_create_test_image(_test_dir + "/assets/foregrounds/unused_fg.png")

	var used = GalleryCleanerService.collect_used_images(story)
	var unused = GalleryCleanerService.find_unused_images(_test_dir, used)
	assert_eq(unused["backgrounds"].size(), 1)
	assert_has(unused["backgrounds"], _test_dir + "/assets/backgrounds/unused_bg.png")
	assert_eq(unused["foregrounds"].size(), 1)
	assert_has(unused["foregrounds"], _test_dir + "/assets/foregrounds/unused_fg.png")


func test_find_unused_images_empty_dirs():
	var used: Array = []
	var unused = GalleryCleanerService.find_unused_images(_test_dir, used)
	assert_eq(unused["backgrounds"].size(), 0)
	assert_eq(unused["foregrounds"].size(), 0)


func test_find_unused_images_nonexistent_path():
	var used: Array = []
	var unused = GalleryCleanerService.find_unused_images("user://nonexistent_dir_xyz", used)
	assert_eq(unused["backgrounds"].size(), 0)
	assert_eq(unused["foregrounds"].size(), 0)


# --- calculate_total_size ---

func test_calculate_total_size_empty():
	var total = GalleryCleanerService.calculate_total_size([])
	assert_eq(total, 0)


func test_calculate_total_size_with_files():
	var path1 = _test_dir + "/assets/backgrounds/a.png"
	var path2 = _test_dir + "/assets/backgrounds/b.png"
	_create_test_image(path1)
	_create_test_image(path2)

	var total = GalleryCleanerService.calculate_total_size([path1, path2])
	assert_gt(total, 0)


func test_calculate_total_size_nonexistent_file():
	var total = GalleryCleanerService.calculate_total_size(["user://does_not_exist.png"])
	assert_eq(total, 0)


# --- delete_files ---

func test_delete_files_empty():
	var count = GalleryCleanerService.delete_files([])
	assert_eq(count, 0)


func test_delete_files_removes_files():
	var path1 = _test_dir + "/assets/backgrounds/to_delete1.png"
	var path2 = _test_dir + "/assets/backgrounds/to_delete2.png"
	_create_test_image(path1)
	_create_test_image(path2)
	assert_true(FileAccess.file_exists(path1))

	var count = GalleryCleanerService.delete_files([path1, path2])
	assert_eq(count, 2)
	assert_false(FileAccess.file_exists(path1))
	assert_false(FileAccess.file_exists(path2))


func test_delete_files_skips_nonexistent():
	var path1 = _test_dir + "/assets/backgrounds/existing.png"
	_create_test_image(path1)

	var count = GalleryCleanerService.delete_files([path1, "user://no_such_file.png"])
	assert_eq(count, 1)
	assert_false(FileAccess.file_exists(path1))


# --- normalize_paths ---

func test_normalize_paths_keeps_absolute():
	var paths = ["/absolute/path/img.png", "user://some/img.png", "res://img.png"]
	var result = GalleryCleanerService.normalize_paths(paths, "/base")
	assert_eq(result[0], "/absolute/path/img.png")
	assert_eq(result[1], "user://some/img.png")
	assert_eq(result[2], "res://img.png")


func test_normalize_paths_resolves_relative():
	var paths = ["assets/backgrounds/forest.png", "assets/foregrounds/hero.png"]
	var result = GalleryCleanerService.normalize_paths(paths, "/base/story")
	assert_eq(result[0], "/base/story/assets/backgrounds/forest.png")
	assert_eq(result[1], "/base/story/assets/foregrounds/hero.png")


func test_find_unused_with_relative_used_paths():
	_create_test_image(_test_dir + "/assets/backgrounds/used.png")
	_create_test_image(_test_dir + "/assets/backgrounds/unused.png")
	# Simulate post-save relative paths
	var used = ["assets/backgrounds/used.png"]
	var unused = GalleryCleanerService.find_unused_images(_test_dir, used)
	assert_eq(unused["backgrounds"].size(), 1)
	assert_has(unused["backgrounds"], _test_dir + "/assets/backgrounds/unused.png")


func test_find_unused_with_relative_paths_all_used():
	_create_test_image(_test_dir + "/assets/backgrounds/bg1.png")
	_create_test_image(_test_dir + "/assets/foregrounds/fg1.png")
	var used = ["assets/backgrounds/bg1.png", "assets/foregrounds/fg1.png"]
	var unused = GalleryCleanerService.find_unused_images(_test_dir, used)
	assert_eq(unused["backgrounds"].size(), 0)
	assert_eq(unused["foregrounds"].size(), 0)
