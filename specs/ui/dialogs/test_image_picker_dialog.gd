extends GutTest

## Tests pour ImagePickerDialog — dialog unifié de sélection d'images
## (onglet Fichier + onglet Galerie + onglet IA)

var ImagePickerDialog = load("res://src/ui/dialogs/image_picker_dialog.gd")
var ImageCategoryService = load("res://src/services/image_category_service.gd")
const Contributions = preload("res://src/plugins/contributions.gd")

var _dialog: Window
var _test_dir: String = ""

func before_each():
	_dialog = Window.new()
	_dialog.set_script(ImagePickerDialog)
	add_child_autofree(_dialog)
	_test_dir = "user://test_picker_%d" % randi()

func after_each():
	_remove_dir_recursive(_test_dir)

# --- Structure UI ---

func test_is_window():
	assert_is(_dialog, Window)

func test_has_title():
	assert_ne(_dialog.title, "")

func test_has_tab_container():
	assert_not_null(_dialog._tab_container)
	assert_is(_dialog._tab_container, TabContainer)

func test_has_two_tabs_by_default():
	assert_eq(_dialog._tab_container.get_tab_count(), 2)

func test_tab_fichier_exists():
	assert_eq(_dialog._tab_container.get_tab_title(0), tr("Fichier"))

func test_tab_galerie_exists():
	assert_eq(_dialog._tab_container.get_tab_title(1), tr("Galerie"))


func test_has_validate_button():
	assert_not_null(_dialog._validate_btn)
	assert_is(_dialog._validate_btn, Button)
	assert_eq(_dialog._validate_btn.text, tr("Valider"))

func test_has_file_path_label():
	assert_not_null(_dialog._file_path_label)
	assert_is(_dialog._file_path_label, Label)

func test_has_gallery_grid():
	assert_not_null(_dialog._gallery_grid)
	assert_is(_dialog._gallery_grid, GridContainer)

func test_has_empty_label():
	assert_not_null(_dialog._empty_label)
	assert_is(_dialog._empty_label, Label)

func test_has_no_story_label():
	assert_not_null(_dialog._no_story_label)
	assert_is(_dialog._no_story_label, Label)

func test_has_image_selected_signal():
	assert_true(_dialog.has_signal("image_selected"))

# --- État initial ---

func test_validate_button_initially_disabled():
	assert_true(_dialog._validate_btn.disabled)

func test_initial_selected_path_empty():
	assert_eq(_dialog._selected_path, "")

func test_empty_label_initially_hidden():
	assert_false(_dialog._empty_label.visible)

func test_no_story_label_initially_hidden():
	assert_false(_dialog._no_story_label.visible)

# --- Mode setup ---

func test_setup_background_sets_title():
	_dialog.setup(ImagePickerDialog.Mode.BACKGROUND, _test_dir)
	assert_string_contains(_dialog.title.to_lower(), "background")

func test_setup_foreground_sets_title():
	_dialog.setup(ImagePickerDialog.Mode.FOREGROUND, _test_dir)
	assert_string_contains(_dialog.title.to_lower(), "foreground")

func test_setup_resets_selected_path():
	_dialog._selected_path = "some/path.png"
	_dialog.setup(ImagePickerDialog.Mode.FOREGROUND, _test_dir)
	assert_eq(_dialog._selected_path, "")

func test_setup_disables_validate_button():
	_dialog._validate_btn.disabled = false
	_dialog.setup(ImagePickerDialog.Mode.FOREGROUND, _test_dir)
	assert_true(_dialog._validate_btn.disabled)

func test_setup_resets_file_path_label():
	_dialog._file_path_label.text = "ancien_fichier.png"
	_dialog.setup(ImagePickerDialog.Mode.FOREGROUND, _test_dir)
	assert_eq(_dialog._file_path_label.text, tr("Aucun fichier sélectionné"))

func test_setup_stores_mode_background():
	_dialog.setup(ImagePickerDialog.Mode.BACKGROUND, _test_dir)
	assert_eq(_dialog._mode, ImagePickerDialog.Mode.BACKGROUND)

func test_setup_stores_mode_foreground():
	_dialog.setup(ImagePickerDialog.Mode.FOREGROUND, _test_dir)
	assert_eq(_dialog._mode, ImagePickerDialog.Mode.FOREGROUND)

func test_setup_stores_story_base_path():
	_dialog.setup(ImagePickerDialog.Mode.FOREGROUND, _test_dir)
	assert_eq(_dialog._story_base_path, _test_dir)

# --- Avertissement histoire manquante ---

func test_no_story_label_visible_when_empty_story_base_path():
	_dialog.setup(ImagePickerDialog.Mode.FOREGROUND, "")
	assert_true(_dialog._no_story_label.visible)

func test_no_story_label_hidden_when_story_base_path_set():
	_dialog.setup(ImagePickerDialog.Mode.FOREGROUND, _test_dir)
	assert_false(_dialog._no_story_label.visible)

# --- Répertoire assets ---

func test_get_assets_dir_background():
	_dialog.setup(ImagePickerDialog.Mode.BACKGROUND, _test_dir)
	assert_eq(_dialog._get_assets_dir(), _test_dir + "/assets/backgrounds")

func test_get_assets_dir_foreground():
	_dialog.setup(ImagePickerDialog.Mode.FOREGROUND, _test_dir)
	assert_eq(_dialog._get_assets_dir(), _test_dir + "/assets/foregrounds")

# --- Résolution de chemin unique (_resolve_unique_path) ---

func test_resolve_unique_path_no_conflict():
	DirAccess.make_dir_recursive_absolute(_test_dir)
	var result = ImagePickerDialog._resolve_unique_path(_test_dir, "image.png")
	assert_eq(result, _test_dir + "/image.png")

func test_resolve_unique_path_with_one_conflict():
	DirAccess.make_dir_recursive_absolute(_test_dir)
	_create_file(_test_dir + "/image.png")
	var result = ImagePickerDialog._resolve_unique_path(_test_dir, "image.png")
	assert_eq(result, _test_dir + "/image_1.png")

func test_resolve_unique_path_with_multiple_conflicts():
	DirAccess.make_dir_recursive_absolute(_test_dir)
	_create_file(_test_dir + "/image.png")
	_create_file(_test_dir + "/image_1.png")
	_create_file(_test_dir + "/image_2.png")
	var result = ImagePickerDialog._resolve_unique_path(_test_dir, "image.png")
	assert_eq(result, _test_dir + "/image_3.png")

func test_resolve_unique_path_preserves_extension():
	DirAccess.make_dir_recursive_absolute(_test_dir)
	_create_file(_test_dir + "/bg.jpg")
	var result = ImagePickerDialog._resolve_unique_path(_test_dir, "bg.jpg")
	assert_eq(result, _test_dir + "/bg_1.jpg")

# --- Listage des images de la galerie ---

func test_list_gallery_images_nonexistent_dir():
	_dialog.setup(ImagePickerDialog.Mode.FOREGROUND, _test_dir + "/nonexistent")
	var images = _dialog._list_gallery_images()
	assert_eq(images.size(), 0)

func test_list_gallery_images_empty_dir():
	var dir = _test_dir + "/assets/foregrounds"
	DirAccess.make_dir_recursive_absolute(dir)
	_dialog.setup(ImagePickerDialog.Mode.FOREGROUND, _test_dir)
	var images = _dialog._list_gallery_images()
	assert_eq(images.size(), 0)

func test_list_gallery_images_with_png_files():
	var dir = _test_dir + "/assets/foregrounds"
	DirAccess.make_dir_recursive_absolute(dir)
	_create_file(dir + "/char1.png")
	_create_file(dir + "/char2.png")
	_dialog.setup(ImagePickerDialog.Mode.FOREGROUND, _test_dir)
	var images = _dialog._list_gallery_images()
	assert_eq(images.size(), 2)

func test_list_gallery_images_filters_non_image_files():
	var dir = _test_dir + "/assets/foregrounds"
	DirAccess.make_dir_recursive_absolute(dir)
	_create_file(dir + "/char1.png")
	_create_file(dir + "/readme.txt")
	_create_file(dir + "/data.yaml")
	_dialog.setup(ImagePickerDialog.Mode.FOREGROUND, _test_dir)
	var images = _dialog._list_gallery_images()
	assert_eq(images.size(), 1)

func test_list_gallery_images_includes_jpg_jpeg_webp():
	var dir = _test_dir + "/assets/backgrounds"
	DirAccess.make_dir_recursive_absolute(dir)
	_create_file(dir + "/bg1.jpg")
	_create_file(dir + "/bg2.jpeg")
	_create_file(dir + "/bg3.webp")
	_dialog.setup(ImagePickerDialog.Mode.BACKGROUND, _test_dir)
	var images = _dialog._list_gallery_images()
	assert_eq(images.size(), 3)

func test_list_gallery_images_returns_full_paths():
	var dir = _test_dir + "/assets/foregrounds"
	DirAccess.make_dir_recursive_absolute(dir)
	_create_file(dir + "/char.png")
	_dialog.setup(ImagePickerDialog.Mode.FOREGROUND, _test_dir)
	var images = _dialog._list_gallery_images()
	assert_eq(images.size(), 1)
	assert_string_contains(images[0], "char.png")

# --- Copie vers assets ---

func test_copy_to_assets_returns_empty_when_no_story():
	_dialog.setup(ImagePickerDialog.Mode.FOREGROUND, "")
	var result = _dialog._copy_to_assets("/some/path.png")
	assert_eq(result, "")

func test_copy_to_assets_creates_file_in_assets_dir():
	var src_dir = _test_dir + "/src"
	DirAccess.make_dir_recursive_absolute(src_dir)
	var src_path = src_dir + "/test_img.png"
	_create_minimal_png(src_path)
	_dialog.setup(ImagePickerDialog.Mode.FOREGROUND, _test_dir)
	var dest = _dialog._copy_to_assets(src_path)
	assert_ne(dest, "")
	assert_true(dest.contains("assets/foregrounds"))
	assert_true(dest.contains("test_img.png"))
	assert_true(FileAccess.file_exists(dest))

func test_copy_to_assets_uses_unique_name_on_conflict():
	var src_dir = _test_dir + "/src"
	DirAccess.make_dir_recursive_absolute(src_dir)
	var src_path = src_dir + "/image.png"
	_create_minimal_png(src_path)
	_dialog.setup(ImagePickerDialog.Mode.FOREGROUND, _test_dir)
	var dest1 = _dialog._copy_to_assets(src_path)
	var dest2 = _dialog._copy_to_assets(src_path)
	assert_ne(dest1, dest2)
	assert_true(FileAccess.file_exists(dest1))
	assert_true(FileAccess.file_exists(dest2))

func test_copy_to_assets_background_goes_to_backgrounds_dir():
	var src_dir = _test_dir + "/src"
	DirAccess.make_dir_recursive_absolute(src_dir)
	var src_path = src_dir + "/bg.png"
	_create_minimal_png(src_path)
	_dialog.setup(ImagePickerDialog.Mode.BACKGROUND, _test_dir)
	var dest = _dialog._copy_to_assets(src_path)
	assert_true(dest.contains("assets/backgrounds"))

# --- Signal image_selected ---

func test_validate_emits_signal_when_path_set():
	_dialog._selected_path = _test_dir + "/assets/foregrounds/img.png"
	_dialog._validate_btn.disabled = false
	watch_signals(_dialog)
	_dialog._on_validate()
	assert_signal_emitted(_dialog, "image_selected")

func test_validate_emits_correct_path():
	var expected = _test_dir + "/assets/foregrounds/img.png"
	_dialog._selected_path = expected
	_dialog._validate_btn.disabled = false
	watch_signals(_dialog)
	_dialog._on_validate()
	assert_signal_emitted_with_parameters(_dialog, "image_selected", [expected])

func test_validate_does_not_emit_when_no_path():
	_dialog._selected_path = ""
	watch_signals(_dialog)
	_dialog._on_validate()
	assert_signal_not_emitted(_dialog, "image_selected")

# --- Annuler ---

func test_cancel_does_not_emit_signal():
	watch_signals(_dialog)
	_dialog._on_cancel()
	assert_signal_not_emitted(_dialog, "image_selected")

# --- Galerie : affichage ---

func test_refresh_gallery_shows_empty_message_when_no_story():
	_dialog.setup(ImagePickerDialog.Mode.FOREGROUND, "")
	_dialog._refresh_gallery()
	assert_true(_dialog._empty_label.visible)

func test_refresh_gallery_shows_empty_message_when_no_images():
	DirAccess.make_dir_recursive_absolute(_test_dir + "/assets/foregrounds")
	_dialog.setup(ImagePickerDialog.Mode.FOREGROUND, _test_dir)
	_dialog._refresh_gallery()
	assert_true(_dialog._empty_label.visible)

func test_refresh_gallery_empty_message_contains_correct_text():
	DirAccess.make_dir_recursive_absolute(_test_dir + "/assets/foregrounds")
	_dialog.setup(ImagePickerDialog.Mode.FOREGROUND, _test_dir)
	_dialog._refresh_gallery()
	assert_eq(_dialog._empty_label.text, tr("Aucune image disponible. Importez d'abord une image via l'onglet Fichier."))

func test_refresh_gallery_adds_items_for_each_image():
	var dir = _test_dir + "/assets/foregrounds"
	DirAccess.make_dir_recursive_absolute(dir)
	_create_minimal_png(dir + "/img1.png")
	_create_minimal_png(dir + "/img2.png")
	_dialog.setup(ImagePickerDialog.Mode.FOREGROUND, _test_dir)
	_dialog._refresh_gallery()
	await get_tree().process_frame
	assert_eq(_dialog._gallery_grid.get_child_count(), 2)

func test_refresh_gallery_hides_empty_label_when_images_exist():
	var dir = _test_dir + "/assets/foregrounds"
	DirAccess.make_dir_recursive_absolute(dir)
	_create_minimal_png(dir + "/img.png")
	_dialog.setup(ImagePickerDialog.Mode.FOREGROUND, _test_dir)
	_dialog._refresh_gallery()
	assert_false(_dialog._empty_label.visible)

# --- Sélection dans la galerie ---

func test_on_gallery_item_selected_sets_path():
	var item = Panel.new()
	add_child_autofree(item)
	_dialog._on_gallery_item_selected(item, _test_dir + "/img.png")
	assert_eq(_dialog._selected_path, _test_dir + "/img.png")

func test_on_gallery_item_selected_enables_validate():
	var item = Panel.new()
	add_child_autofree(item)
	_dialog._on_gallery_item_selected(item, _test_dir + "/img.png")
	assert_false(_dialog._validate_btn.disabled)

func test_on_gallery_item_selected_highlights_item():
	var item = Panel.new()
	add_child_autofree(item)
	_dialog._on_gallery_item_selected(item, _test_dir + "/img.png")
	assert_ne(item.modulate, Color.WHITE)

func test_on_gallery_item_selected_deselects_previous():
	var item1 = Panel.new()
	var item2 = Panel.new()
	add_child_autofree(item1)
	add_child_autofree(item2)
	_dialog._on_gallery_item_selected(item1, _test_dir + "/img1.png")
	_dialog._on_gallery_item_selected(item2, _test_dir + "/img2.png")
	assert_eq(item1.modulate, Color.WHITE)
	assert_ne(item2.modulate, Color.WHITE)

# --- Intégration : sélection fichier applique chemin copié ---

func test_on_file_selected_sets_selected_path_to_copied():
	var src_dir = _test_dir + "/src"
	DirAccess.make_dir_recursive_absolute(src_dir)
	var src_path = src_dir + "/myfile.png"
	_create_minimal_png(src_path)
	_dialog.setup(ImagePickerDialog.Mode.FOREGROUND, _test_dir)
	_dialog._on_file_selected_from_dialog(src_path)
	assert_ne(_dialog._selected_path, "")
	assert_ne(_dialog._selected_path, src_path)
	assert_true(_dialog._selected_path.contains("assets/foregrounds"))

func test_on_file_selected_enables_validate():
	var src_dir = _test_dir + "/src"
	DirAccess.make_dir_recursive_absolute(src_dir)
	var src_path = src_dir + "/myfile.png"
	_create_minimal_png(src_path)
	_dialog.setup(ImagePickerDialog.Mode.FOREGROUND, _test_dir)
	_dialog._on_file_selected_from_dialog(src_path)
	assert_false(_dialog._validate_btn.disabled)

func test_on_file_selected_without_story_does_not_set_path():
	_dialog.setup(ImagePickerDialog.Mode.FOREGROUND, "")
	_dialog._on_file_selected_from_dialog("/some/path/image.png")
	assert_eq(_dialog._selected_path, "")


# --- Plugin tab injection ---

func test_add_plugin_tab_adds_tab_to_container() -> void:
	var tab_def: RefCounted = Contributions.ImagePickerTabDef.new()
	tab_def.label = "IA"
	tab_def.create_tab = func(_ctx): return Control.new()
	_dialog.setup(ImagePickerDialog.Mode.FOREGROUND, "")
	_dialog.add_plugin_tab(tab_def)
	assert_eq(_dialog._tab_container.get_tab_title(2), "IA")


func test_add_plugin_tab_calls_setup_on_tab() -> void:
	var calls := []
	var tab_def: RefCounted = Contributions.ImagePickerTabDef.new()
	tab_def.label = "Test"
	var fake_tab := _TabWithSetup.new()
	fake_tab.calls = calls
	tab_def.create_tab = func(_ctx): return fake_tab
	_dialog.setup(ImagePickerDialog.Mode.FOREGROUND, "")
	_dialog.add_plugin_tab(tab_def)
	assert_eq(calls.size(), 1)


func test_set_source_image_forwards_to_plugin_tab() -> void:
	var paths := []
	var tab_def: RefCounted = Contributions.ImagePickerTabDef.new()
	tab_def.label = "IA"
	var fake_tab := _TabWithSource.new()
	fake_tab.paths = paths
	tab_def.create_tab = func(_ctx): return fake_tab
	_dialog.setup(ImagePickerDialog.Mode.FOREGROUND, "")
	_dialog.add_plugin_tab(tab_def)
	_dialog.set_source_image("/some/image.png")
	assert_eq(paths, ["/some/image.png"])


# --- Search field in gallery ---

func test_has_gallery_search_edit():
	assert_not_null(_dialog._gallery_search_edit)
	assert_is(_dialog._gallery_search_edit, LineEdit)


func test_gallery_search_edit_has_placeholder():
	assert_eq(_dialog._gallery_search_edit.placeholder_text, tr("Rechercher..."))


func test_gallery_search_filters_by_name():
	var dir = _test_dir + "/assets/foregrounds"
	DirAccess.make_dir_recursive_absolute(dir)
	_create_minimal_png(dir + "/hero.png")
	_create_minimal_png(dir + "/villain.png")
	_dialog.setup(ImagePickerDialog.Mode.FOREGROUND, _test_dir)
	_dialog._gallery_search_edit.text = "hero"
	_dialog._refresh_gallery()
	assert_eq(_dialog._gallery_grid.get_child_count(), 1)


func test_gallery_search_is_case_insensitive():
	var dir = _test_dir + "/assets/foregrounds"
	DirAccess.make_dir_recursive_absolute(dir)
	_create_minimal_png(dir + "/Hero.png")
	_create_minimal_png(dir + "/villain.png")
	_dialog.setup(ImagePickerDialog.Mode.FOREGROUND, _test_dir)
	_dialog._gallery_search_edit.text = "HERO"
	_dialog._refresh_gallery()
	assert_eq(_dialog._gallery_grid.get_child_count(), 1)


func test_gallery_search_empty_shows_all():
	var dir = _test_dir + "/assets/foregrounds"
	DirAccess.make_dir_recursive_absolute(dir)
	_create_minimal_png(dir + "/img1.png")
	_create_minimal_png(dir + "/img2.png")
	_dialog.setup(ImagePickerDialog.Mode.FOREGROUND, _test_dir)
	_dialog._gallery_search_edit.text = ""
	_dialog._refresh_gallery()
	assert_eq(_dialog._gallery_grid.get_child_count(), 2)


func test_gallery_search_no_match_shows_empty():
	var dir = _test_dir + "/assets/foregrounds"
	DirAccess.make_dir_recursive_absolute(dir)
	_create_minimal_png(dir + "/img1.png")
	_dialog.setup(ImagePickerDialog.Mode.FOREGROUND, _test_dir)
	_dialog._gallery_search_edit.text = "zzzzz"
	_dialog._refresh_gallery()
	assert_eq(_dialog._gallery_grid.get_child_count(), 0)
	assert_true(_dialog._empty_label.visible)


class _TabWithSetup extends Control:
	var calls: Array = []
	func setup(_ctx: Dictionary) -> void:
		calls.append(true)


class _TabWithSource extends Control:
	var paths: Array = []
	func set_source_image(path: String) -> void:
		paths.append(path)


# --- Helpers ---

func _create_file(path: String) -> void:
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string("test")
		f.close()

func _create_minimal_png(path: String) -> void:
	var img = Image.create(1, 1, false, Image.FORMAT_RGB8)
	img.save_png(path)

func _remove_dir_recursive(path: String) -> void:
	var dir = DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname == "." or fname == "..":
			fname = dir.get_next()
			continue
		var full = path + "/" + fname
		if dir.current_is_dir():
			_remove_dir_recursive(full)
		else:
			DirAccess.remove_absolute(full)
		fname = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)
