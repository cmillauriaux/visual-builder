extends GutTest

const GalleryDialogScript = preload("res://src/ui/dialogs/gallery_dialog.gd")
const StoryScript = preload("res://src/models/story.gd")
const ChapterScript = preload("res://src/models/chapter.gd")
const SceneDataScript = preload("res://src/models/scene_data.gd")
const SequenceScript = preload("res://src/models/sequence.gd")
const ForegroundScript = preload("res://src/models/foreground.gd")
const DialogueScript = preload("res://src/models/dialogue.gd")

var _dialog: Window
var _test_dir: String = ""


func before_each():
	_test_dir = "user://test_gallery_dialog_" + str(randi())
	DirAccess.make_dir_recursive_absolute(_test_dir + "/assets/backgrounds")
	DirAccess.make_dir_recursive_absolute(_test_dir + "/assets/foregrounds")
	_dialog = Window.new()
	_dialog.set_script(GalleryDialogScript)
	add_child(_dialog)


func after_each():
	_dialog.queue_free()
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


func _build_story() -> RefCounted:
	var story = StoryScript.new()
	story.title = "Mon Histoire"
	story.menu_background = _test_dir + "/assets/backgrounds/menu.png"
	var seq = SequenceScript.new()
	seq.background = _test_dir + "/assets/backgrounds/forest.png"
	var fg = ForegroundScript.new()
	fg.image = _test_dir + "/assets/foregrounds/hero.png"
	seq.foregrounds = [fg]
	var scene = SceneDataScript.new()
	scene.sequences = [seq]
	var chapter = ChapterScript.new()
	chapter.scenes = [scene]
	story.chapters = [chapter]
	return story


# --- Setup tests ---

func test_dialog_title_includes_story_name():
	var story = _build_story()
	_dialog.setup(story, _test_dir)
	assert_eq(_dialog.title, "Galerie — Mon Histoire")


func test_dialog_size():
	assert_eq(_dialog.size, Vector2i(900, 600))


func test_dialog_is_exclusive():
	assert_true(_dialog.exclusive)


# --- Sections tests ---

func test_has_backgrounds_section():
	var story = _build_story()
	_dialog.setup(story, _test_dir)
	assert_not_null(_dialog._bg_section_label)
	assert_eq(_dialog._bg_section_label.text, "Backgrounds")


func test_has_foregrounds_section():
	var story = _build_story()
	_dialog.setup(story, _test_dir)
	assert_not_null(_dialog._fg_section_label)
	assert_eq(_dialog._fg_section_label.text, "Foregrounds")


func test_bg_grid_has_4_columns():
	var story = _build_story()
	_dialog.setup(story, _test_dir)
	assert_eq(_dialog._bg_grid.columns, 4)


func test_fg_grid_has_4_columns():
	var story = _build_story()
	_dialog.setup(story, _test_dir)
	assert_eq(_dialog._fg_grid.columns, 4)


# --- Gallery content ---

func test_displays_background_images():
	_create_test_image(_test_dir + "/assets/backgrounds/bg1.png")
	_create_test_image(_test_dir + "/assets/backgrounds/bg2.png")
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	assert_eq(_dialog._bg_grid.get_child_count(), 2)


func test_displays_foreground_images():
	_create_test_image(_test_dir + "/assets/foregrounds/fg1.png")
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	assert_eq(_dialog._fg_grid.get_child_count(), 1)


func test_empty_backgrounds_shows_message():
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	assert_true(_dialog._bg_empty_label.visible)
	assert_string_contains(_dialog._bg_empty_label.text, "Aucun background")


func test_empty_foregrounds_shows_message():
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	assert_true(_dialog._fg_empty_label.visible)
	assert_string_contains(_dialog._fg_empty_label.text, "Aucun foreground")


# --- Opacity for unused images ---

func test_unused_image_has_reduced_opacity():
	_create_test_image(_test_dir + "/assets/backgrounds/unused.png")
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	var item = _dialog._bg_grid.get_child(0)
	assert_eq(item.modulate.a, 0.5)


func test_used_image_has_full_opacity():
	_create_test_image(_test_dir + "/assets/backgrounds/used.png")
	var story = StoryScript.new()
	story.title = "Test"
	story.menu_background = _test_dir + "/assets/backgrounds/used.png"
	_dialog.setup(story, _test_dir)
	var item = _dialog._bg_grid.get_child(0)
	assert_eq(item.modulate.a, 1.0)


# --- Clean button ---

func test_clean_button_exists():
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	assert_not_null(_dialog._clean_button)
	assert_eq(_dialog._clean_button.text, "Nettoyer la galerie")


func test_clean_button_disabled_when_gallery_empty():
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	assert_true(_dialog._clean_button.disabled)


func test_clean_button_enabled_when_gallery_has_images():
	_create_test_image(_test_dir + "/assets/backgrounds/img.png")
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	assert_false(_dialog._clean_button.disabled)


# --- Close button ---

func test_close_button_exists():
	assert_not_null(_dialog._close_button)
	assert_eq(_dialog._close_button.text, "Fermer")
