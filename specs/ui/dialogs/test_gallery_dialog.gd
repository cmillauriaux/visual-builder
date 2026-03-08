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


func test_used_image_with_relative_path_has_full_opacity():
	_create_test_image(_test_dir + "/assets/backgrounds/bg_rel.png")
	var story = StoryScript.new()
	story.title = "Test"
	story.menu_background = "assets/backgrounds/bg_rel.png"
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

func test_has_category_filter_container():
	assert_not_null(_dialog._category_filter_container)
	assert_is(_dialog._category_filter_container, HBoxContainer)


func test_category_filter_has_default_categories():
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	assert_eq(_dialog._category_checkboxes.size(), 3)


func test_category_checkboxes_initially_unchecked():
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	for cb in _dialog._category_checkboxes:
		assert_false(cb.button_pressed)


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
	for cb in _dialog._category_checkboxes:
		if cb.text == "Base":
			cb.button_pressed = true
	_dialog._refresh()
	assert_eq(_dialog._bg_grid.get_child_count(), 1)


func test_filter_no_checkboxes_shows_all():
	_create_test_image(_test_dir + "/assets/backgrounds/bg1.png")
	_create_test_image(_test_dir + "/assets/backgrounds/bg2.png")
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	_dialog._category_service.assign_image_to_category("backgrounds/bg1.png", "Base")
	# No checkboxes checked = show all
	_dialog._refresh()
	assert_eq(_dialog._bg_grid.get_child_count(), 2)


func test_filter_multiple_categories_shows_union():
	_create_test_image(_test_dir + "/assets/backgrounds/bg1.png")
	_create_test_image(_test_dir + "/assets/backgrounds/bg2.png")
	_create_test_image(_test_dir + "/assets/backgrounds/bg3.png")
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	_dialog._category_service.assign_image_to_category("backgrounds/bg1.png", "Base")
	_dialog._category_service.assign_image_to_category("backgrounds/bg2.png", "NPC")
	for cb in _dialog._category_checkboxes:
		if cb.text == "Base" or cb.text == "NPC":
			cb.button_pressed = true
	_dialog._refresh()
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
	# Renommer + Remplacer + sep + 3 categories + separator + "Gérer les catégories..." = 8 items
	assert_eq(_dialog._context_menu.item_count, 8)


func test_context_menu_has_manage_option():
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	_dialog._show_context_menu(_test_dir + "/assets/backgrounds/test.png", Vector2(100, 100))
	var last_idx = _dialog._context_menu.item_count - 1
	assert_eq(_dialog._context_menu.get_item_text(last_idx), "Gérer les catégories...")


func test_context_menu_rename_is_first_item():
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	_dialog._show_context_menu(_test_dir + "/assets/backgrounds/test.png", Vector2(100, 100))
	assert_eq(_dialog._context_menu.get_item_text(0), "Renommer")


func test_context_menu_rename_id_is_8000():
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	_dialog._show_context_menu(_test_dir + "/assets/backgrounds/test.png", Vector2(100, 100))
	assert_eq(_dialog._context_menu.get_item_id(0), 8000)


func test_rename_dialog_is_added_on_show():
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	var before_count = _dialog.get_child_count()
	_dialog._show_rename_dialog(_test_dir + "/assets/backgrounds/forest.png")
	assert_gt(_dialog.get_child_count(), before_count)


func test_rename_dialog_has_correct_title():
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	_dialog._show_rename_dialog(_test_dir + "/assets/backgrounds/forest.png")
	var rename_dlg: ConfirmationDialog = null
	for child in _dialog.get_children():
		if child is ConfirmationDialog:
			rename_dlg = child
			break
	assert_not_null(rename_dlg)
	assert_eq(rename_dlg.title, "Renommer l'image")


# --- Normalize button ---

func test_normalize_button_exists():
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	assert_not_null(_dialog._normalize_button)
	assert_eq(_dialog._normalize_button.text, "Normaliser les images")


func test_normalize_button_disabled_when_less_than_2_images():
	_create_test_image(_test_dir + "/assets/backgrounds/img.png")
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	assert_true(_dialog._normalize_button.disabled)


func test_normalize_button_enabled_when_2_or_more_images():
	_create_test_image(_test_dir + "/assets/backgrounds/bg1.png")
	_create_test_image(_test_dir + "/assets/backgrounds/bg2.png")
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	assert_false(_dialog._normalize_button.disabled)


func test_normalize_button_disabled_when_gallery_empty():
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	assert_true(_dialog._normalize_button.disabled)


func test_rename_dialog_line_edit_prefilled_without_extension():
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	_dialog._show_rename_dialog(_test_dir + "/assets/backgrounds/forest.png")
	var rename_dlg: ConfirmationDialog = null
	for child in _dialog.get_children():
		if child is ConfirmationDialog:
			rename_dlg = child
			break
	assert_not_null(rename_dlg)
	var line_edit: LineEdit = null
	for child in rename_dlg.get_children():
		if child is VBoxContainer:
			for sub in child.get_children():
				if sub is LineEdit:
					line_edit = sub
	assert_not_null(line_edit)
	assert_eq(line_edit.text, "forest")


# --- Replace context menu item ---

func test_context_menu_replace_is_second_item():
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	_dialog._show_context_menu(_test_dir + "/assets/backgrounds/test.png", Vector2(100, 100))
	assert_eq(_dialog._context_menu.get_item_text(1), "Remplacer")


func test_context_menu_replace_id_is_8001():
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	_dialog._show_context_menu(_test_dir + "/assets/backgrounds/test.png", Vector2(100, 100))
	assert_eq(_dialog._context_menu.get_item_id(1), 8001)


func test_replace_disabled_when_single_background():
	_create_test_image(_test_dir + "/assets/backgrounds/only.png")
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	_dialog._show_context_menu(_test_dir + "/assets/backgrounds/only.png", Vector2(100, 100))
	var replace_idx = _dialog._context_menu.get_item_index(8001)
	assert_true(_dialog._context_menu.is_item_disabled(replace_idx))


func test_replace_enabled_when_multiple_backgrounds():
	_create_test_image(_test_dir + "/assets/backgrounds/bg1.png")
	_create_test_image(_test_dir + "/assets/backgrounds/bg2.png")
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	_dialog._show_context_menu(_test_dir + "/assets/backgrounds/bg1.png", Vector2(100, 100))
	var replace_idx = _dialog._context_menu.get_item_index(8001)
	assert_false(_dialog._context_menu.is_item_disabled(replace_idx))


func test_replace_disabled_when_single_foreground():
	_create_test_image(_test_dir + "/assets/foregrounds/only.png")
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	_dialog._show_context_menu(_test_dir + "/assets/foregrounds/only.png", Vector2(100, 100))
	var replace_idx = _dialog._context_menu.get_item_index(8001)
	assert_true(_dialog._context_menu.is_item_disabled(replace_idx))


# --- Replace dialog ---

func test_show_replace_dialog_adds_child():
	_create_test_image(_test_dir + "/assets/backgrounds/bg1.png")
	_create_test_image(_test_dir + "/assets/backgrounds/bg2.png")
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	_dialog._show_replace_dialog(_test_dir + "/assets/backgrounds/bg1.png")
	var found := false
	for child in _dialog.get_children():
		if child is Window and child != _dialog._image_preview and child.title == "Remplacer l'image":
			found = true
			break
	assert_true(found)


func test_replace_dialog_has_correct_title():
	_create_test_image(_test_dir + "/assets/backgrounds/bg1.png")
	_create_test_image(_test_dir + "/assets/backgrounds/bg2.png")
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	_dialog._show_replace_dialog(_test_dir + "/assets/backgrounds/bg1.png")
	var replace_dlg: Window = null
	for child in _dialog.get_children():
		if child is Window and child != _dialog._image_preview and child.title == "Remplacer l'image":
			replace_dlg = child
			break
	assert_not_null(replace_dlg)


func test_replace_dialog_excludes_source_image():
	_create_test_image(_test_dir + "/assets/backgrounds/bg1.png")
	_create_test_image(_test_dir + "/assets/backgrounds/bg2.png")
	_create_test_image(_test_dir + "/assets/backgrounds/bg3.png")
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	_dialog._show_replace_dialog(_test_dir + "/assets/backgrounds/bg1.png")
	var replace_dlg: Window = null
	for child in _dialog.get_children():
		if child is Window and child != _dialog._image_preview and child.title == "Remplacer l'image":
			replace_dlg = child
			break
	assert_not_null(replace_dlg)
	# Grid should show 2 images (bg2, bg3), not bg1
	var grid: GridContainer = replace_dlg.get_meta("grid")
	assert_eq(grid.get_child_count(), 2)


func test_replace_dialog_shows_same_type_images():
	_create_test_image(_test_dir + "/assets/backgrounds/bg1.png")
	_create_test_image(_test_dir + "/assets/backgrounds/bg2.png")
	_create_test_image(_test_dir + "/assets/foregrounds/fg1.png")
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	_dialog._show_replace_dialog(_test_dir + "/assets/backgrounds/bg1.png")
	var replace_dlg: Window = null
	for child in _dialog.get_children():
		if child is Window and child != _dialog._image_preview and child.title == "Remplacer l'image":
			replace_dlg = child
			break
	assert_not_null(replace_dlg)
	# Only bg2 should be shown (same type, excluding source)
	assert_eq(replace_dlg.get_meta("grid").get_child_count(), 1)


# --- Replace execution ---

func test_replace_updates_story_references():
	_create_test_image(_test_dir + "/assets/backgrounds/old.png")
	_create_test_image(_test_dir + "/assets/backgrounds/new.png")
	var story = StoryScript.new()
	story.title = "Test"
	story.menu_background = _test_dir + "/assets/backgrounds/old.png"
	_dialog.setup(story, _test_dir)
	_dialog._execute_replace(
		_test_dir + "/assets/backgrounds/old.png",
		_test_dir + "/assets/backgrounds/new.png"
	)
	assert_eq(story.menu_background, "assets/backgrounds/new.png")


func test_replace_updates_sequence_background():
	_create_test_image(_test_dir + "/assets/backgrounds/old.png")
	_create_test_image(_test_dir + "/assets/backgrounds/new.png")
	var seq = SequenceScript.new()
	seq.background = _test_dir + "/assets/backgrounds/old.png"
	var scene = SceneDataScript.new()
	scene.sequences = [seq]
	var chapter = ChapterScript.new()
	chapter.scenes = [scene]
	var story = StoryScript.new()
	story.title = "Test"
	story.chapters = [chapter]
	_dialog.setup(story, _test_dir)
	_dialog._execute_replace(
		_test_dir + "/assets/backgrounds/old.png",
		_test_dir + "/assets/backgrounds/new.png"
	)
	assert_eq(seq.background, "assets/backgrounds/new.png")


func test_replace_updates_foreground_image():
	_create_test_image(_test_dir + "/assets/foregrounds/old.png")
	_create_test_image(_test_dir + "/assets/foregrounds/new.png")
	var fg = ForegroundScript.new()
	fg.image = _test_dir + "/assets/foregrounds/old.png"
	var seq = SequenceScript.new()
	seq.foregrounds = [fg]
	var scene = SceneDataScript.new()
	scene.sequences = [seq]
	var chapter = ChapterScript.new()
	chapter.scenes = [scene]
	var story = StoryScript.new()
	story.title = "Test"
	story.chapters = [chapter]
	_dialog.setup(story, _test_dir)
	_dialog._execute_replace(
		_test_dir + "/assets/foregrounds/old.png",
		_test_dir + "/assets/foregrounds/new.png"
	)
	assert_eq(fg.image, "assets/foregrounds/new.png")


func test_replace_updates_dialogue_foreground_image():
	_create_test_image(_test_dir + "/assets/foregrounds/old.png")
	_create_test_image(_test_dir + "/assets/foregrounds/new.png")
	var fg = ForegroundScript.new()
	fg.image = _test_dir + "/assets/foregrounds/old.png"
	var dlg = DialogueScript.new()
	dlg.foregrounds = [fg]
	var seq = SequenceScript.new()
	seq.dialogues = [dlg]
	var scene = SceneDataScript.new()
	scene.sequences = [seq]
	var chapter = ChapterScript.new()
	chapter.scenes = [scene]
	var story = StoryScript.new()
	story.title = "Test"
	story.chapters = [chapter]
	_dialog.setup(story, _test_dir)
	_dialog._execute_replace(
		_test_dir + "/assets/foregrounds/old.png",
		_test_dir + "/assets/foregrounds/new.png"
	)
	assert_eq(fg.image, "assets/foregrounds/new.png")


func test_replace_deletes_old_image():
	_create_test_image(_test_dir + "/assets/backgrounds/old.png")
	_create_test_image(_test_dir + "/assets/backgrounds/new.png")
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	_dialog._execute_replace(
		_test_dir + "/assets/backgrounds/old.png",
		_test_dir + "/assets/backgrounds/new.png"
	)
	assert_false(FileAccess.file_exists(_test_dir + "/assets/backgrounds/old.png"))


func test_replace_transfers_categories():
	_create_test_image(_test_dir + "/assets/backgrounds/old.png")
	_create_test_image(_test_dir + "/assets/backgrounds/new.png")
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	_dialog._category_service.assign_image_to_category("backgrounds/old.png", "Base")
	_dialog._execute_replace(
		_test_dir + "/assets/backgrounds/old.png",
		_test_dir + "/assets/backgrounds/new.png"
	)
	assert_true(_dialog._category_service.is_image_in_category("backgrounds/new.png", "Base"))
	assert_false(_dialog._category_service.is_image_in_category("backgrounds/old.png", "Base"))


func test_replace_preserves_existing_categories_on_target():
	_create_test_image(_test_dir + "/assets/backgrounds/old.png")
	_create_test_image(_test_dir + "/assets/backgrounds/new.png")
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	_dialog._category_service.assign_image_to_category("backgrounds/old.png", "Base")
	_dialog._category_service.assign_image_to_category("backgrounds/new.png", "NPC")
	_dialog._execute_replace(
		_test_dir + "/assets/backgrounds/old.png",
		_test_dir + "/assets/backgrounds/new.png"
	)
	assert_true(_dialog._category_service.is_image_in_category("backgrounds/new.png", "Base"))
	assert_true(_dialog._category_service.is_image_in_category("backgrounds/new.png", "NPC"))


func test_replace_marks_story_as_modified():
	_create_test_image(_test_dir + "/assets/backgrounds/old.png")
	_create_test_image(_test_dir + "/assets/backgrounds/new.png")
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	story.updated_at = "2000-01-01T00:00:00Z"
	_dialog._execute_replace(
		_test_dir + "/assets/backgrounds/old.png",
		_test_dir + "/assets/backgrounds/new.png"
	)
	assert_ne(story.updated_at, "2000-01-01T00:00:00Z")


func test_replace_unused_image_deletes_without_error():
	_create_test_image(_test_dir + "/assets/backgrounds/unused.png")
	_create_test_image(_test_dir + "/assets/backgrounds/other.png")
	var story = StoryScript.new()
	story.title = "Test"
	# unused.png is not referenced anywhere
	_dialog.setup(story, _test_dir)
	_dialog._execute_replace(
		_test_dir + "/assets/backgrounds/unused.png",
		_test_dir + "/assets/backgrounds/other.png"
	)
	assert_false(FileAccess.file_exists(_test_dir + "/assets/backgrounds/unused.png"))


# --- _format_size ---

func test_format_size_bytes():
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	assert_eq(_dialog._format_size(0), "0 o")
	assert_eq(_dialog._format_size(512), "512 o")
	assert_eq(_dialog._format_size(1023), "1023 o")


func test_format_size_kilobytes():
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	assert_eq(_dialog._format_size(1024), "1.0 Ko")
	assert_eq(_dialog._format_size(1536), "1.5 Ko")


func test_format_size_megabytes():
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	assert_eq(_dialog._format_size(1048576), "1.0 Mo")
	assert_eq(_dialog._format_size(2621440), "2.5 Mo")


# --- _on_close ---

func test_on_close_hides_dialog():
	_dialog.visible = true
	_dialog._on_close()
	assert_false(_dialog.visible)


# --- _list_images ---

func test_list_images_returns_empty_for_nonexistent_dir():
	var result = _dialog._list_images(_test_dir + "/nonexistent")
	assert_eq(result, [])


func test_list_images_filters_non_image_files():
	_create_test_image(_test_dir + "/assets/backgrounds/img.png")
	# Create a non-image file
	var f = FileAccess.open(_test_dir + "/assets/backgrounds/notes.txt", FileAccess.WRITE)
	f.store_string("hello")
	f.close()
	var result = _dialog._list_images(_test_dir + "/assets/backgrounds")
	assert_eq(result.size(), 1)
	assert_string_contains(result[0], "img.png")


func test_list_images_accepts_jpg_jpeg_webp():
	# Create files with various image extensions
	for ext in ["jpg", "jpeg", "webp"]:
		var f = FileAccess.open(_test_dir + "/assets/backgrounds/img." + ext, FileAccess.WRITE)
		f.store_string("fake")
		f.close()
	var result = _dialog._list_images(_test_dir + "/assets/backgrounds")
	assert_eq(result.size(), 3)


# --- _show_image_preview ---

func test_show_image_preview_empty_path_does_nothing():
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	# Should not crash
	_dialog._show_image_preview("")
	assert_true(true, "No crash on empty path")


# --- Grid visibility ---

func test_bg_grid_visible_when_has_images():
	_create_test_image(_test_dir + "/assets/backgrounds/bg1.png")
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	assert_true(_dialog._bg_grid.visible)


func test_bg_grid_hidden_when_empty():
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	assert_false(_dialog._bg_grid.visible)


func test_fg_grid_visible_when_has_images():
	_create_test_image(_test_dir + "/assets/foregrounds/fg1.png")
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	assert_true(_dialog._fg_grid.visible)


func test_fg_grid_hidden_when_empty():
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	assert_false(_dialog._fg_grid.visible)


# --- Gallery item label ---

func test_gallery_item_displays_filename():
	_create_test_image(_test_dir + "/assets/backgrounds/my_image.png")
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	var item = _dialog._bg_grid.get_child(0)
	var vbox = item.get_child(0) as VBoxContainer
	var name_label = vbox.get_child(1) as Label
	assert_eq(name_label.text, "my_image.png")


# --- _get_selected_categories ---

func test_get_selected_categories_returns_empty_when_none_checked():
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	assert_eq(_dialog._get_selected_categories(), [])


func test_get_selected_categories_returns_checked():
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	for cb in _dialog._category_checkboxes:
		if cb.text == "Base":
			cb.button_pressed = true
	var selected = _dialog._get_selected_categories()
	assert_eq(selected.size(), 1)
	assert_eq(selected[0], "Base")


# --- Context menu category checked state ---

func test_context_menu_category_checked_when_assigned():
	_create_test_image(_test_dir + "/assets/backgrounds/bg1.png")
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	_dialog._category_service.assign_image_to_category("backgrounds/bg1.png", "Base")
	_dialog._show_context_menu(_test_dir + "/assets/backgrounds/bg1.png", Vector2(100, 100))
	# Category items start after Renommer + Remplacer + separator = index 3
	var base_idx = _dialog._context_menu.get_item_index(0) # id 0 = first category
	assert_true(_dialog._context_menu.is_item_checked(base_idx))


func test_context_menu_category_unchecked_when_not_assigned():
	_create_test_image(_test_dir + "/assets/backgrounds/bg1.png")
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	_dialog._show_context_menu(_test_dir + "/assets/backgrounds/bg1.png", Vector2(100, 100))
	var base_idx = _dialog._context_menu.get_item_index(0)
	assert_false(_dialog._context_menu.is_item_checked(base_idx))


# --- Context menu replaces old one ---

func test_context_menu_replaces_previous():
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	_dialog._show_context_menu(_test_dir + "/assets/backgrounds/a.png", Vector2(10, 10))
	var first_menu = _dialog._context_menu
	_dialog._show_context_menu(_test_dir + "/assets/backgrounds/b.png", Vector2(20, 20))
	assert_ne(_dialog._context_menu, first_menu)


# --- _show_replace_dialog with no candidates ---

func test_replace_dialog_not_shown_when_no_candidates():
	_create_test_image(_test_dir + "/assets/backgrounds/only.png")
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	var before_count = _dialog.get_child_count()
	_dialog._show_replace_dialog(_test_dir + "/assets/backgrounds/only.png")
	assert_eq(_dialog.get_child_count(), before_count)


# --- _show_replace_confirmation ---

func test_show_replace_confirmation_creates_dialog():
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	var before_count = _dialog.get_child_count()
	_dialog._show_replace_confirmation("/tmp/old.png", "/tmp/new.png")
	assert_gt(_dialog.get_child_count(), before_count)


func test_show_replace_confirmation_dialog_text():
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	_dialog._show_replace_confirmation("/tmp/old.png", "/tmp/new.png")
	var confirm: ConfirmationDialog = null
	for child in _dialog.get_children():
		if child is ConfirmationDialog:
			confirm = child
	assert_not_null(confirm)
	assert_string_contains(confirm.dialog_text, "old.png")
	assert_string_contains(confirm.dialog_text, "new.png")


# --- _on_clean_pressed ---

func test_clean_pressed_shows_info_when_all_used():
	_create_test_image(_test_dir + "/assets/backgrounds/used.png")
	var story = StoryScript.new()
	story.title = "Test"
	story.menu_background = _test_dir + "/assets/backgrounds/used.png"
	_dialog.setup(story, _test_dir)
	var before_count = _dialog.get_child_count()
	_dialog._on_clean_pressed()
	# Should add an AcceptDialog
	assert_gt(_dialog.get_child_count(), before_count)
	var info: AcceptDialog = null
	for child in _dialog.get_children():
		if child is AcceptDialog and not child is ConfirmationDialog:
			info = child
	assert_not_null(info)
	assert_string_contains(info.dialog_text, "utilisées")


func test_clean_pressed_shows_confirm_when_unused_exist():
	_create_test_image(_test_dir + "/assets/backgrounds/unused.png")
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	var before_count = _dialog.get_child_count()
	_dialog._on_clean_pressed()
	# Should add a ConfirmationDialog
	assert_gt(_dialog.get_child_count(), before_count)
	var confirm: ConfirmationDialog = null
	for child in _dialog.get_children():
		if child is ConfirmationDialog:
			confirm = child
	assert_not_null(confirm)
	assert_string_contains(confirm.dialog_text, "fichier(s)")


# --- _execute_replace without story ---

func test_execute_replace_without_story_does_not_crash():
	_create_test_image(_test_dir + "/assets/backgrounds/old.png")
	_create_test_image(_test_dir + "/assets/backgrounds/new.png")
	_dialog._story = null
	_dialog._story_base_path = _test_dir
	_dialog._category_service = ImageCategoryService.new()
	_dialog._used_images = []
	# Need grids initialized for _refresh
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	_dialog._story = null
	_dialog._execute_replace(
		_test_dir + "/assets/backgrounds/old.png",
		_test_dir + "/assets/backgrounds/new.png"
	)
	assert_false(FileAccess.file_exists(_test_dir + "/assets/backgrounds/old.png"))


# --- _open_category_manager ---

func test_open_category_manager_adds_window():
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	var before_count = _dialog.get_child_count()
	_dialog._open_category_manager()
	assert_gt(_dialog.get_child_count(), before_count)


# --- _on_normalize_pressed ---

func test_on_normalize_pressed_adds_window():
	var story = StoryScript.new()
	story.title = "Test"
	_dialog.setup(story, _test_dir)
	var before_count = _dialog.get_child_count()
	_dialog._on_normalize_pressed()
	assert_gt(_dialog.get_child_count(), before_count)


# --- Setup with empty base path ---

func test_setup_with_empty_base_path():
	var story = StoryScript.new()
	story.title = "Empty Path"
	_dialog.setup(story, "")
	assert_eq(_dialog.title, "Galerie — Empty Path")
	assert_not_null(_dialog._category_service)


# --- image_renamed signal ---

func test_image_renamed_signal_exists():
	assert_has_signal(_dialog, "image_renamed")
