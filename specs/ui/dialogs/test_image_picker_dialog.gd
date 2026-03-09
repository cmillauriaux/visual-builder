extends GutTest

## Tests pour ImagePickerDialog — dialog unifié de sélection d'images
## (onglet Fichier + onglet Galerie + onglet IA)

var ImagePickerDialog = load("res://src/ui/dialogs/image_picker_dialog.gd")
var ImageCategoryService = load("res://src/services/image_category_service.gd")

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

func test_has_three_tabs():
	assert_eq(_dialog._tab_container.get_tab_count(), 3)

func test_tab_fichier_exists():
	assert_eq(_dialog._tab_container.get_tab_title(0), "Fichier")

func test_tab_galerie_exists():
	assert_eq(_dialog._tab_container.get_tab_title(1), "Galerie")

func test_tab_ia_exists():
	assert_eq(_dialog._tab_container.get_tab_title(2), "IA")

func test_has_validate_button():
	assert_not_null(_dialog._validate_btn)
	assert_is(_dialog._validate_btn, Button)
	assert_eq(_dialog._validate_btn.text, "Valider")

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
	assert_string_contains(_dialog._file_path_label.text.to_lower(), "aucun")

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
	assert_string_contains(_dialog._empty_label.text, "Aucune image disponible")

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

# --- Onglet IA : Structure UI ---

func test_ia_has_url_input():
	assert_not_null(_dialog._ia_url_input)
	assert_is(_dialog._ia_url_input, LineEdit)

func test_ia_has_token_input():
	assert_not_null(_dialog._ia_token_input)
	assert_is(_dialog._ia_token_input, LineEdit)
	assert_true(_dialog._ia_token_input.secret)

func test_ia_has_prompt_input():
	assert_not_null(_dialog._ia_prompt_input)
	assert_is(_dialog._ia_prompt_input, TextEdit)

func test_ia_has_generate_button():
	assert_not_null(_dialog._ia_generate_btn)
	assert_is(_dialog._ia_generate_btn, Button)

func test_ia_has_accept_button():
	assert_not_null(_dialog._ia_accept_btn)
	assert_is(_dialog._ia_accept_btn, Button)

func test_ia_has_regenerate_button():
	assert_not_null(_dialog._ia_regenerate_btn)
	assert_is(_dialog._ia_regenerate_btn, Button)

func test_ia_has_status_label():
	assert_not_null(_dialog._ia_status_label)
	assert_is(_dialog._ia_status_label, Label)

func test_ia_has_progress_bar():
	assert_not_null(_dialog._ia_progress_bar)
	assert_is(_dialog._ia_progress_bar, ProgressBar)

func test_ia_has_source_path_label():
	assert_not_null(_dialog._ia_source_path_label)
	assert_is(_dialog._ia_source_path_label, Label)

func test_ia_has_result_preview():
	assert_not_null(_dialog._ia_result_preview)
	assert_is(_dialog._ia_result_preview, TextureRect)

func test_ia_has_choose_source_button():
	assert_not_null(_dialog._ia_choose_source_btn)
	assert_is(_dialog._ia_choose_source_btn, Button)

# --- Onglet IA : Bouton Galerie source ---

func test_ia_has_choose_gallery_button():
	assert_not_null(_dialog._ia_choose_gallery_btn)
	assert_is(_dialog._ia_choose_gallery_btn, Button)

func test_ia_choose_gallery_button_disabled_without_story():
	_dialog.setup(ImagePickerDialog.Mode.FOREGROUND, "")
	assert_true(_dialog._ia_choose_gallery_btn.disabled)

func test_ia_choose_gallery_button_enabled_with_story():
	_dialog.setup(ImagePickerDialog.Mode.FOREGROUND, _test_dir)
	assert_false(_dialog._ia_choose_gallery_btn.disabled)

func test_ia_set_inputs_disabled_includes_gallery_button():
	_dialog._ia_set_inputs_enabled(false)
	assert_true(_dialog._ia_choose_gallery_btn.disabled)

func test_ia_set_inputs_enabled_includes_gallery_button():
	_dialog._ia_set_inputs_enabled(false)
	_dialog._ia_set_inputs_enabled(true)
	assert_false(_dialog._ia_choose_gallery_btn.disabled)

# --- Onglet IA : CFG slider ---

func test_ia_has_cfg_slider():
	assert_not_null(_dialog._ia_cfg_slider)
	assert_is(_dialog._ia_cfg_slider, HSlider)

func test_ia_cfg_slider_default_value():
	assert_eq(_dialog._ia_cfg_slider.value, 1.0)

func test_ia_cfg_slider_range():
	assert_eq(_dialog._ia_cfg_slider.min_value, 1.0)
	assert_eq(_dialog._ia_cfg_slider.max_value, 30.0)

func test_ia_cfg_slider_step():
	assert_eq(_dialog._ia_cfg_slider.step, 0.5)

func test_ia_has_cfg_value_label():
	assert_not_null(_dialog._ia_cfg_value_label)
	assert_is(_dialog._ia_cfg_value_label, Label)
	assert_eq(_dialog._ia_cfg_value_label.text, "1.0")

# --- Onglet IA : État initial ---

func test_ia_accept_button_initially_disabled():
	assert_true(_dialog._ia_accept_btn.disabled)

func test_ia_regenerate_button_initially_disabled():
	assert_true(_dialog._ia_regenerate_btn.disabled)

func test_ia_progress_bar_initially_hidden():
	assert_false(_dialog._ia_progress_bar.visible)

func test_ia_generate_button_initially_disabled():
	assert_true(_dialog._ia_generate_btn.disabled)

func test_ia_progress_bar_is_indeterminate():
	assert_true(_dialog._ia_progress_bar.indeterminate)

# --- Onglet IA : Generate button state ---

func test_ia_generate_enabled_when_fields_filled():
	_dialog._ia_source_image_path = "/path/to/image.png"
	_dialog._ia_url_input.text = "http://localhost:8188"
	_dialog._ia_prompt_input.text = "a cute cat"
	_dialog._ia_update_generate_button_state()
	assert_false(_dialog._ia_generate_btn.disabled)

func test_ia_generate_disabled_without_source():
	_dialog._ia_source_image_path = ""
	_dialog._ia_url_input.text = "http://localhost:8188"
	_dialog._ia_prompt_input.text = "a cute cat"
	_dialog._ia_update_generate_button_state()
	assert_true(_dialog._ia_generate_btn.disabled)

func test_ia_generate_disabled_without_prompt():
	_dialog._ia_source_image_path = "/path/to/img.png"
	_dialog._ia_url_input.text = "http://localhost:8188"
	_dialog._ia_prompt_input.text = ""
	_dialog._ia_update_generate_button_state()
	assert_true(_dialog._ia_generate_btn.disabled)

func test_ia_generate_disabled_without_url():
	_dialog._ia_source_image_path = "/path/to/img.png"
	_dialog._ia_url_input.text = ""
	_dialog._ia_prompt_input.text = "a cute cat"
	_dialog._ia_update_generate_button_state()
	assert_true(_dialog._ia_generate_btn.disabled)

# --- Onglet IA : set_source_image ---

func test_set_source_image_sets_path():
	_dialog.set_source_image("/path/to/image.png")
	assert_eq(_dialog._ia_source_image_path, "/path/to/image.png")

func test_set_source_image_updates_label():
	_dialog.set_source_image("/path/to/image.png")
	assert_string_contains(_dialog._ia_source_path_label.text, "image.png")

func test_set_source_image_empty_resets_label():
	_dialog.set_source_image("/path/to/image.png")
	_dialog.set_source_image("")
	assert_eq(_dialog._ia_source_image_path, "")
	assert_string_contains(_dialog._ia_source_path_label.text.to_lower(), "aucune")

# --- Onglet IA : Status messages ---

func test_ia_show_status_message():
	_dialog._ia_show_status("Uploading...")
	assert_eq(_dialog._ia_status_label.text, "Uploading...")
	assert_true(_dialog._ia_progress_bar.visible)

func test_ia_show_error_message():
	_dialog._ia_show_error("Network error")
	assert_string_contains(_dialog._ia_status_label.text, "Network error")
	assert_false(_dialog._ia_progress_bar.visible)

func test_ia_show_success_message():
	_dialog._ia_show_success("Done!")
	assert_eq(_dialog._ia_status_label.text, "Done!")
	assert_false(_dialog._ia_progress_bar.visible)

# --- Onglet IA : Status colors ---

func test_ia_status_color_on_progress():
	_dialog._ia_show_status("loading")
	var color = _dialog._ia_status_label.get_theme_color("font_color")
	assert_almost_eq(color.r, 0.8, 0.1)

func test_ia_status_color_on_success():
	_dialog._ia_show_success("ok")
	var color = _dialog._ia_status_label.get_theme_color("font_color")
	assert_true(color.g > 0.8, "Success should be green")

func test_ia_status_color_on_error():
	_dialog._ia_show_error("fail")
	var color = _dialog._ia_status_label.get_theme_color("font_color")
	assert_true(color.r > 0.8, "Error should be red")

# --- Onglet IA : Inputs disabled/enabled ---

func test_ia_set_inputs_disabled():
	_dialog._ia_set_inputs_enabled(false)
	assert_false(_dialog._ia_url_input.editable)
	assert_false(_dialog._ia_token_input.editable)
	assert_false(_dialog._ia_prompt_input.editable)
	assert_true(_dialog._ia_choose_source_btn.disabled)

func test_ia_set_inputs_enabled():
	_dialog._ia_set_inputs_enabled(false)
	_dialog._ia_set_inputs_enabled(true)
	assert_true(_dialog._ia_url_input.editable)
	assert_true(_dialog._ia_token_input.editable)
	assert_true(_dialog._ia_prompt_input.editable)
	assert_false(_dialog._ia_choose_source_btn.disabled)

# --- Onglet IA : Save dir depends on mode ---

func test_ia_save_dir_foreground_mode():
	_dialog.setup(ImagePickerDialog.Mode.FOREGROUND, _test_dir)
	assert_true(_dialog._get_assets_dir().contains("foregrounds"))

func test_ia_save_dir_background_mode():
	_dialog.setup(ImagePickerDialog.Mode.BACKGROUND, _test_dir)
	assert_true(_dialog._get_assets_dir().contains("backgrounds"))

# --- Onglet IA : Source preview ---

func test_ia_load_source_preview_with_valid_image():
	var tmp_dir = "user://test_ia_preview_%d" % randi()
	DirAccess.make_dir_recursive_absolute(tmp_dir)
	var img_path = tmp_dir + "/source.png"
	var img = Image.create(1, 1, false, Image.FORMAT_RGB8)
	img.save_png(img_path)
	_dialog._ia_load_source_preview(img_path)
	assert_not_null(_dialog._ia_source_preview.texture)
	_remove_dir_recursive(tmp_dir)

func test_ia_load_source_preview_with_invalid_path_clears_texture():
	_dialog._ia_source_preview.texture = ImageTexture.new()
	_dialog._ia_load_source_preview("user://nonexistent/path.png")
	assert_null(_dialog._ia_source_preview.texture)

func test_ia_load_source_preview_empty_path_clears_texture():
	_dialog._ia_source_preview.texture = ImageTexture.new()
	_dialog._ia_load_source_preview("")
	assert_null(_dialog._ia_source_preview.texture)

# --- Image Preview : Structure ---

func test_has_image_preview():
	assert_not_null(_dialog._image_preview)
	assert_is(_dialog._image_preview, Control)

func test_image_preview_initially_hidden():
	assert_false(_dialog._image_preview.visible)

# --- Image Preview : show_image_preview ---

func test_show_image_preview_opens_popup():
	var img = Image.create(2, 2, false, Image.FORMAT_RGB8)
	var tex = ImageTexture.create_from_image(img)
	_dialog._show_image_preview(tex, "test.png")
	assert_true(_dialog._image_preview.visible)

func test_show_image_preview_null_texture_stays_hidden():
	_dialog._show_image_preview(null, "test.png")
	assert_false(_dialog._image_preview.visible)

# --- Image Preview : show_image_preview_from_path ---

func test_show_image_preview_from_path_with_valid_image():
	var tmp_dir = "user://test_preview_%d" % randi()
	DirAccess.make_dir_recursive_absolute(tmp_dir)
	var img_path = tmp_dir + "/preview_test.png"
	_create_minimal_png(img_path)
	_dialog._show_image_preview_from_path(img_path)
	assert_true(_dialog._image_preview.visible)
	_remove_dir_recursive(tmp_dir)

func test_show_image_preview_from_path_empty_does_nothing():
	_dialog._show_image_preview_from_path("")
	assert_false(_dialog._image_preview.visible)

# --- Image Preview : IA result click ---

func test_ia_result_preview_mouse_filter_stop():
	assert_eq(_dialog._ia_result_preview.mouse_filter, Control.MOUSE_FILTER_STOP)

# --- Image Preview : IA source click ---

func test_ia_source_preview_mouse_filter_stop():
	assert_eq(_dialog._ia_source_preview.mouse_filter, Control.MOUSE_FILTER_STOP)

# --- Galerie : Filtre par catégorie ---

func test_has_gallery_category_filter_container():
	assert_not_null(_dialog._gallery_category_filter_container)
	assert_is(_dialog._gallery_category_filter_container, HBoxContainer)


func test_gallery_category_filter_has_default_categories():
	_dialog.setup(ImagePickerDialog.Mode.FOREGROUND, _test_dir)
	assert_eq(_dialog._gallery_category_checkboxes.size(), 3)


func test_gallery_category_checkboxes_initially_unchecked():
	_dialog.setup(ImagePickerDialog.Mode.FOREGROUND, _test_dir)
	for cb in _dialog._gallery_category_checkboxes:
		assert_false(cb.button_pressed)


func test_category_service_loaded_on_setup():
	_dialog.setup(ImagePickerDialog.Mode.FOREGROUND, _test_dir)
	assert_not_null(_dialog._category_service)


func test_gallery_context_menu_initially_null():
	assert_null(_dialog._gallery_context_menu)


func test_gallery_context_menu_rename_is_first_item():
	_dialog.setup(ImagePickerDialog.Mode.FOREGROUND, _test_dir)
	_dialog._show_gallery_context_menu(_test_dir + "/assets/foregrounds/test.png", Vector2(100, 100))
	assert_eq(_dialog._gallery_context_menu.get_item_text(0), "Renommer")


func test_gallery_context_menu_rename_id_is_8000():
	_dialog.setup(ImagePickerDialog.Mode.FOREGROUND, _test_dir)
	_dialog._show_gallery_context_menu(_test_dir + "/assets/foregrounds/test.png", Vector2(100, 100))
	assert_eq(_dialog._gallery_context_menu.get_item_id(0), 8000)


func test_gallery_context_menu_has_rename_then_separator():
	_dialog.setup(ImagePickerDialog.Mode.FOREGROUND, _test_dir)
	_dialog._show_gallery_context_menu(_test_dir + "/assets/foregrounds/test.png", Vector2(100, 100))
	# index 0 = Renommer, index 1 = separator
	assert_true(_dialog._gallery_context_menu.is_item_separator(1))


func test_gallery_context_menu_total_count_with_default_categories():
	_dialog.setup(ImagePickerDialog.Mode.FOREGROUND, _test_dir)
	_dialog._show_gallery_context_menu(_test_dir + "/assets/foregrounds/test.png", Vector2(100, 100))
	# Renommer + sep + 3 categories + sep + Gérer = 7
	assert_eq(_dialog._gallery_context_menu.item_count, 7)


func test_gallery_has_image_renamed_signal():
	assert_true(_dialog.has_signal("image_renamed"))


# --- Onglet IA : Workflow selector ---

func test_ia_has_workflow_option():
	assert_not_null(_dialog._ia_workflow_option)
	assert_is(_dialog._ia_workflow_option, OptionButton)

func test_ia_workflow_option_has_two_items():
	assert_eq(_dialog._ia_workflow_option.item_count, 2)

func test_ia_workflow_option_first_is_creation():
	assert_eq(_dialog._ia_workflow_option.get_item_text(0), "Création")

func test_ia_workflow_option_second_is_expression():
	assert_eq(_dialog._ia_workflow_option.get_item_text(1), "Expression")

func test_ia_workflow_option_default_is_creation():
	assert_eq(_dialog._ia_workflow_option.selected, 0)

func test_ia_workflow_option_creation_id_is_0():
	assert_eq(_dialog._ia_workflow_option.get_item_id(0), 0)

func test_ia_workflow_option_expression_id_is_1():
	assert_eq(_dialog._ia_workflow_option.get_item_id(1), 1)

func test_ia_set_inputs_disabled_includes_workflow():
	_dialog._ia_set_inputs_enabled(false)
	assert_true(_dialog._ia_workflow_option.disabled)

func test_ia_set_inputs_enabled_includes_workflow():
	_dialog._ia_set_inputs_enabled(false)
	_dialog._ia_set_inputs_enabled(true)
	assert_false(_dialog._ia_workflow_option.disabled)

# --- Onglet IA : Nom de l'image ---

func test_ia_has_name_input():
	assert_not_null(_dialog._ia_name_input)
	assert_is(_dialog._ia_name_input, LineEdit)

func test_ia_name_input_initially_empty():
	assert_eq(_dialog._ia_name_input.text, "")

func test_ia_name_input_initially_not_editable():
	assert_false(_dialog._ia_name_input.editable)

func test_ia_name_input_has_placeholder():
	assert_ne(_dialog._ia_name_input.placeholder_text, "")

func test_ia_name_input_editable_after_generation():
	var img = Image.create(2, 2, false, Image.FORMAT_RGB8)
	_dialog._on_ia_generation_completed(img)
	assert_true(_dialog._ia_name_input.editable)

func test_ia_name_input_prefilled_after_generation():
	var img = Image.create(2, 2, false, Image.FORMAT_RGB8)
	_dialog._on_ia_generation_completed(img)
	assert_string_starts_with(_dialog._ia_name_input.text, "ai_")

func test_ia_name_input_disabled_during_generation():
	_dialog._ia_set_inputs_enabled(false)
	assert_false(_dialog._ia_name_input.editable)

func test_ia_name_input_enabled_after_generation():
	_dialog._ia_set_inputs_enabled(false)
	_dialog._ia_set_inputs_enabled(true)
	assert_true(_dialog._ia_name_input.editable)

func test_ia_accept_uses_custom_name():
	_dialog.setup(ImagePickerDialog.Mode.FOREGROUND, _test_dir)
	var img = Image.create(2, 2, false, Image.FORMAT_RGB8)
	_dialog._ia_generated_image = img
	_dialog._ia_name_input.text = "mon_personnage"
	watch_signals(_dialog)
	_dialog._on_ia_accept_pressed()
	assert_signal_emitted(_dialog, "image_selected")
	var args = get_signal_parameters(_dialog, "image_selected")
	assert_string_contains(args[0], "mon_personnage.png")

func test_ia_accept_fallback_name_when_empty():
	_dialog.setup(ImagePickerDialog.Mode.FOREGROUND, _test_dir)
	var img = Image.create(2, 2, false, Image.FORMAT_RGB8)
	_dialog._ia_generated_image = img
	_dialog._ia_name_input.text = ""
	watch_signals(_dialog)
	_dialog._on_ia_accept_pressed()
	assert_signal_emitted(_dialog, "image_selected")
	var args = get_signal_parameters(_dialog, "image_selected")
	assert_string_contains(args[0], "ai_")

func test_ia_accept_rejects_invalid_name():
	_dialog.setup(ImagePickerDialog.Mode.FOREGROUND, _test_dir)
	var img = Image.create(2, 2, false, Image.FORMAT_RGB8)
	_dialog._ia_generated_image = img
	_dialog._ia_name_input.text = "nom avec espaces"
	watch_signals(_dialog)
	_dialog._on_ia_accept_pressed()
	assert_signal_not_emitted(_dialog, "image_selected")

func test_ia_accept_shows_error_on_invalid_name():
	_dialog.setup(ImagePickerDialog.Mode.FOREGROUND, _test_dir)
	var img = Image.create(2, 2, false, Image.FORMAT_RGB8)
	_dialog._ia_generated_image = img
	_dialog._ia_name_input.text = "nom avec espaces"
	_dialog._on_ia_accept_pressed()
	assert_ne(_dialog._ia_status_label.text, "")

func test_ia_accept_handles_name_conflict():
	_dialog.setup(ImagePickerDialog.Mode.FOREGROUND, _test_dir)
	var dir = _test_dir + "/assets/foregrounds"
	DirAccess.make_dir_recursive_absolute(dir)
	_create_minimal_png(dir + "/existing.png")
	var img = Image.create(2, 2, false, Image.FORMAT_RGB8)
	_dialog._ia_generated_image = img
	_dialog._ia_name_input.text = "existing"
	watch_signals(_dialog)
	_dialog._on_ia_accept_pressed()
	assert_signal_emitted(_dialog, "image_selected")
	var args = get_signal_parameters(_dialog, "image_selected")
	assert_string_contains(args[0], "existing_1.png")

# --- Popup "Choisir une image source" : filtre catégories ---

func test_ia_choose_gallery_filter_no_checkboxes_shows_all():
	var dir = _test_dir + "/assets/foregrounds"
	DirAccess.make_dir_recursive_absolute(dir)
	_create_minimal_png(dir + "/img1.png")
	_create_minimal_png(dir + "/img2.png")
	_dialog.setup(ImagePickerDialog.Mode.FOREGROUND, _test_dir)
	# Aucune case cochée → toutes les images
	var all_images = _dialog._list_gallery_images()
	var selected: Array = []
	var filtered = _dialog._category_service.filter_paths_by_categories(all_images, selected)
	assert_eq(filtered.size(), 2)


func test_ia_choose_gallery_filter_by_category():
	var dir = _test_dir + "/assets/foregrounds"
	DirAccess.make_dir_recursive_absolute(dir)
	_create_minimal_png(dir + "/img1.png")
	_create_minimal_png(dir + "/img2.png")
	_dialog.setup(ImagePickerDialog.Mode.FOREGROUND, _test_dir)
	_dialog._category_service.assign_image_to_category("foregrounds/img1.png", "Base")
	var all_images = _dialog._list_gallery_images()
	var filtered = _dialog._category_service.filter_paths_by_categories(all_images, ["Base"])
	assert_eq(filtered.size(), 1)
	assert_string_contains(filtered[0], "img1.png")


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
