extends GutTest

const GalleryDialogScript = preload("res://src/ui/dialogs/gallery_dialog.gd")
const StoryScript = preload("res://src/models/story.gd")
const ChapterScript = preload("res://src/models/chapter.gd")
const SceneDataScript = preload("res://src/models/scene_data.gd")
const SequenceScript = preload("res://src/models/sequence.gd")
const ForegroundScript = preload("res://src/models/foreground.gd")
const DialogueScript = preload("res://src/models/dialogue.gd")
const ImageCategoryService = preload("res://src/services/image_category_service.gd")

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


# --- Category filter ---

func test_has_category_filter():
	assert_not_null(_dialog._category_filter)
	assert_is(_dialog._category_filter, OptionButton)


func test_category_filter_has_toutes_option():
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	assert_eq(_dialog._category_filter.get_item_text(0), "Toutes")


func test_category_filter_has_default_categories():
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	# "Toutes" + 3 default categories = 4
	assert_eq(_dialog._category_filter.item_count, 4)


func test_category_filter_initially_on_toutes():
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	assert_eq(_dialog._category_filter.selected, 0)


func test_category_service_loaded_on_setup():
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	assert_not_null(_dialog._category_service)


func test_filter_by_category_shows_only_assigned():
	_create_test_image(_test_dir + "/assets/backgrounds/bg1.png")
	_create_test_image(_test_dir + "/assets/backgrounds/bg2.png")
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	_dialog._category_service.assign_image_to_category("backgrounds/bg1.png", "Base")
	# Select "Base" filter
	_dialog._category_filter.select(1)
	_dialog._on_category_filter_changed(1)
	assert_eq(_dialog._bg_grid.get_child_count(), 1)


func test_filter_toutes_shows_all():
	_create_test_image(_test_dir + "/assets/backgrounds/bg1.png")
	_create_test_image(_test_dir + "/assets/backgrounds/bg2.png")
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	_dialog._category_service.assign_image_to_category("backgrounds/bg1.png", "Base")
	# Select "Toutes"
	_dialog._category_filter.select(0)
	_dialog._on_category_filter_changed(0)
	assert_eq(_dialog._bg_grid.get_child_count(), 2)


# --- Context menu ---

func test_context_menu_initially_null():
	assert_null(_dialog._context_menu)


func test_show_context_menu_creates_popup():
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	_dialog._show_context_menu(_test_dir + "/assets/backgrounds/test.png", Vector2(100, 100))
	assert_not_null(_dialog._context_menu)
	assert_is(_dialog._context_menu, PopupMenu)


func test_context_menu_has_category_items():
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	_dialog._show_context_menu(_test_dir + "/assets/backgrounds/test.png", Vector2(100, 100))
	# 3 categories + separator + "Gérer les catégories..." = 5 items
	assert_eq(_dialog._context_menu.item_count, 5)


func test_context_menu_has_manage_option():
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	_dialog._show_context_menu(_test_dir + "/assets/backgrounds/test.png", Vector2(100, 100))
	var last_idx = _dialog._context_menu.item_count - 1
	assert_eq(_dialog._context_menu.get_item_text(last_idx), "Gérer les catégories...")
