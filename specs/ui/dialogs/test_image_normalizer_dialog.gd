extends GutTest

const ImageNormalizerDialogScript = preload("res://src/ui/dialogs/image_normalizer_dialog.gd")

var _dialog: Window
var _test_dir: String = ""


func before_each():
	_test_dir = "user://test_normalizer_dlg_" + str(randi())
	DirAccess.make_dir_recursive_absolute(_test_dir + "/assets/backgrounds")
	DirAccess.make_dir_recursive_absolute(_test_dir + "/assets/foregrounds")
	_dialog = Window.new()
	_dialog.set_script(ImageNormalizerDialogScript)
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


func _create_test_image(path: String, color: Color = Color.WHITE) -> void:
	var img = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(color)
	img.save_png(path)


# --- Structure tests ---

func test_dialog_size():
	assert_eq(_dialog.size, Vector2i(1000, 700))


func test_dialog_is_exclusive():
	assert_true(_dialog.exclusive)


func test_dialog_title():
	assert_eq(_dialog.title, "Normalisation des images")


# --- Phase 1: Selection ---

func test_selection_grid_has_4_columns():
	assert_eq(_dialog._selection_grid.columns, 4)


func test_displays_background_images():
	_create_test_image(_test_dir + "/assets/backgrounds/bg1.png")
	_create_test_image(_test_dir + "/assets/backgrounds/bg2.png")
	_dialog.setup(_test_dir)
	assert_eq(_dialog._selection_grid.get_child_count(), 2)


func test_displays_foreground_images():
	_create_test_image(_test_dir + "/assets/foregrounds/fg1.png")
	_dialog.setup(_test_dir)
	assert_eq(_dialog._selection_grid.get_child_count(), 1)


func test_displays_both_bg_and_fg():
	_create_test_image(_test_dir + "/assets/backgrounds/bg1.png")
	_create_test_image(_test_dir + "/assets/foregrounds/fg1.png")
	_dialog.setup(_test_dir)
	assert_eq(_dialog._selection_grid.get_child_count(), 2)


func test_selection_count_label_initial():
	_create_test_image(_test_dir + "/assets/backgrounds/bg1.png")
	_dialog.setup(_test_dir)
	assert_eq(_dialog._selection_count_label.text, "0 image(s) sélectionnée(s)")


func test_next_button_disabled_when_less_than_2_selected():
	_create_test_image(_test_dir + "/assets/backgrounds/bg1.png")
	_create_test_image(_test_dir + "/assets/backgrounds/bg2.png")
	_dialog.setup(_test_dir)
	assert_true(_dialog._next_button.disabled)


func test_next_button_enabled_when_2_or_more_selected():
	_create_test_image(_test_dir + "/assets/backgrounds/bg1.png")
	_create_test_image(_test_dir + "/assets/backgrounds/bg2.png")
	_dialog.setup(_test_dir)
	_dialog._on_select_all()
	assert_false(_dialog._next_button.disabled)


func test_select_all_checks_all():
	_create_test_image(_test_dir + "/assets/backgrounds/bg1.png")
	_create_test_image(_test_dir + "/assets/backgrounds/bg2.png")
	_dialog.setup(_test_dir)
	_dialog._on_select_all()
	for path in _dialog._selection_checkboxes:
		assert_true(_dialog._selection_checkboxes[path].button_pressed)


func test_deselect_all_unchecks_all():
	_create_test_image(_test_dir + "/assets/backgrounds/bg1.png")
	_create_test_image(_test_dir + "/assets/backgrounds/bg2.png")
	_dialog.setup(_test_dir)
	_dialog._on_select_all()
	_dialog._on_deselect_all()
	for path in _dialog._selection_checkboxes:
		assert_false(_dialog._selection_checkboxes[path].button_pressed)


func test_selection_count_label_updates():
	_create_test_image(_test_dir + "/assets/backgrounds/bg1.png")
	_create_test_image(_test_dir + "/assets/backgrounds/bg2.png")
	_dialog.setup(_test_dir)
	_dialog._on_select_all()
	assert_eq(_dialog._selection_count_label.text, "2 image(s) sélectionnée(s)")


func test_close_button_exists():
	assert_not_null(_dialog._close_button)
	assert_eq(_dialog._close_button.text, "Fermer")


# --- Phase 2: Reference selection ---

func test_phase_2_shows_selected_images_only():
	_create_test_image(_test_dir + "/assets/backgrounds/bg1.png")
	_create_test_image(_test_dir + "/assets/backgrounds/bg2.png")
	_create_test_image(_test_dir + "/assets/backgrounds/bg3.png")
	_dialog.setup(_test_dir)
	# Select only first two
	var paths = _dialog._selection_checkboxes.keys()
	_dialog._selection_checkboxes[paths[0]].button_pressed = true
	_dialog._selection_checkboxes[paths[1]].button_pressed = true
	_dialog._on_next_to_reference()
	assert_eq(_dialog._reference_grid.get_child_count(), 2)


func test_normalize_button_disabled_until_reference_chosen():
	_create_test_image(_test_dir + "/assets/backgrounds/bg1.png")
	_create_test_image(_test_dir + "/assets/backgrounds/bg2.png")
	_dialog.setup(_test_dir)
	_dialog._on_select_all()
	_dialog._on_next_to_reference()
	assert_true(_dialog._normalize_button.disabled)


func test_normalize_button_enabled_after_reference_chosen():
	_create_test_image(_test_dir + "/assets/backgrounds/bg1.png")
	_create_test_image(_test_dir + "/assets/backgrounds/bg2.png")
	_dialog.setup(_test_dir)
	_dialog._on_select_all()
	_dialog._on_next_to_reference()
	_dialog._select_reference(_dialog._selected_paths[0])
	assert_false(_dialog._normalize_button.disabled)


func test_reference_label_updates_with_filename():
	_create_test_image(_test_dir + "/assets/backgrounds/bg1.png")
	_create_test_image(_test_dir + "/assets/backgrounds/bg2.png")
	_dialog.setup(_test_dir)
	_dialog._on_select_all()
	_dialog._on_next_to_reference()
	_dialog._select_reference(_dialog._selected_paths[0])
	assert_string_contains(_dialog._reference_label.text, _dialog._selected_paths[0].get_file())


func test_reference_image_has_highlight():
	_create_test_image(_test_dir + "/assets/backgrounds/bg1.png")
	_create_test_image(_test_dir + "/assets/backgrounds/bg2.png")
	_dialog.setup(_test_dir)
	_dialog._on_select_all()
	_dialog._on_next_to_reference()
	_dialog._select_reference(_dialog._selected_paths[0])
	var first_container = _dialog._reference_grid.get_child(0)
	assert_eq(first_container.modulate, Color(0.5, 0.8, 1.0))


func test_non_reference_image_has_no_highlight():
	_create_test_image(_test_dir + "/assets/backgrounds/bg1.png")
	_create_test_image(_test_dir + "/assets/backgrounds/bg2.png")
	_dialog.setup(_test_dir)
	_dialog._on_select_all()
	_dialog._on_next_to_reference()
	_dialog._select_reference(_dialog._selected_paths[0])
	var second_container = _dialog._reference_grid.get_child(1)
	assert_eq(second_container.modulate, Color.WHITE)


func test_back_to_selection_shows_phase_1():
	_create_test_image(_test_dir + "/assets/backgrounds/bg1.png")
	_create_test_image(_test_dir + "/assets/backgrounds/bg2.png")
	_dialog.setup(_test_dir)
	_dialog._on_select_all()
	_dialog._on_next_to_reference()
	_dialog._show_phase(1)
	assert_true(_dialog._selection_container.visible)
	assert_false(_dialog._reference_container.visible)


# --- Phase 3: Preview ---

func test_phase_3_preview_grid_has_2_columns():
	assert_eq(_dialog._preview_grid.columns, 2)


func test_phase_3_creates_temp_files():
	_create_test_image(_test_dir + "/assets/backgrounds/bg1.png", Color(0.3, 0.3, 0.3))
	_create_test_image(_test_dir + "/assets/backgrounds/bg2.png", Color(0.7, 0.7, 0.7))
	_dialog.setup(_test_dir)
	_dialog._on_select_all()
	_dialog._on_next_to_reference()
	_dialog._select_reference(_dialog._selected_paths[0])
	_dialog._on_normalize_pressed()
	# Temp dir should exist
	assert_not_null(DirAccess.open(_test_dir + "/assets/.normalizer_temp"))


func test_phase_3_shows_before_after_for_each_image():
	_create_test_image(_test_dir + "/assets/backgrounds/bg1.png", Color(0.3, 0.3, 0.3))
	_create_test_image(_test_dir + "/assets/backgrounds/bg2.png", Color(0.7, 0.7, 0.7))
	_dialog.setup(_test_dir)
	_dialog._on_select_all()
	_dialog._on_next_to_reference()
	_dialog._select_reference(_dialog._selected_paths[0])
	_dialog._on_normalize_pressed()
	# 2 images × 2 columns (before + after) = 4 children
	assert_eq(_dialog._preview_grid.get_child_count(), 4)


func test_apply_button_exists():
	assert_not_null(_dialog._apply_button)
	assert_eq(_dialog._apply_button.text, "Appliquer")


func test_back_from_preview_cleans_temp():
	_create_test_image(_test_dir + "/assets/backgrounds/bg1.png", Color(0.3, 0.3, 0.3))
	_create_test_image(_test_dir + "/assets/backgrounds/bg2.png", Color(0.7, 0.7, 0.7))
	_dialog.setup(_test_dir)
	_dialog._on_select_all()
	_dialog._on_next_to_reference()
	_dialog._select_reference(_dialog._selected_paths[0])
	_dialog._on_normalize_pressed()
	_dialog._on_back_from_preview()
	assert_null(DirAccess.open(_test_dir + "/assets/.normalizer_temp"))


# --- Temp file management ---

func test_close_cleans_temp_dir():
	_create_test_image(_test_dir + "/assets/backgrounds/bg1.png", Color(0.3, 0.3, 0.3))
	_create_test_image(_test_dir + "/assets/backgrounds/bg2.png", Color(0.7, 0.7, 0.7))
	_dialog.setup(_test_dir)
	_dialog._on_select_all()
	_dialog._on_next_to_reference()
	_dialog._select_reference(_dialog._selected_paths[0])
	_dialog._on_normalize_pressed()
	_dialog._on_close()
	assert_null(DirAccess.open(_test_dir + "/assets/.normalizer_temp"))


# --- Phase visibility ---

func test_initial_phase_is_1():
	_dialog.setup(_test_dir)
	assert_true(_dialog._selection_container.visible)
	assert_false(_dialog._reference_container.visible)
	assert_false(_dialog._preview_container.visible)


func test_phase_2_visibility():
	_create_test_image(_test_dir + "/assets/backgrounds/bg1.png")
	_create_test_image(_test_dir + "/assets/backgrounds/bg2.png")
	_dialog.setup(_test_dir)
	_dialog._on_select_all()
	_dialog._on_next_to_reference()
	assert_false(_dialog._selection_container.visible)
	assert_true(_dialog._reference_container.visible)
	assert_false(_dialog._preview_container.visible)


func test_phase_3_visibility():
	_create_test_image(_test_dir + "/assets/backgrounds/bg1.png", Color(0.3, 0.3, 0.3))
	_create_test_image(_test_dir + "/assets/backgrounds/bg2.png", Color(0.7, 0.7, 0.7))
	_dialog.setup(_test_dir)
	_dialog._on_select_all()
	_dialog._on_next_to_reference()
	_dialog._select_reference(_dialog._selected_paths[0])
	_dialog._on_normalize_pressed()
	assert_false(_dialog._selection_container.visible)
	assert_false(_dialog._reference_container.visible)
	assert_true(_dialog._preview_container.visible)


# --- Image preview ---

func test_has_image_preview_popup():
	assert_not_null(_dialog._image_preview)


# --- Signal ---

func test_normalization_applied_signal_exists():
	assert_has_signal(_dialog, "normalization_applied")


# --- Prefix ---

func test_get_prefix_for_background():
	_create_test_image(_test_dir + "/assets/backgrounds/bg1.png")
	_dialog.setup(_test_dir)
	var bg_path = _test_dir + "/assets/backgrounds/bg1.png"
	assert_eq(_dialog._get_prefix_for_path(bg_path), "bg_")


func test_get_prefix_for_foreground():
	_create_test_image(_test_dir + "/assets/foregrounds/fg1.png")
	_dialog.setup(_test_dir)
	var fg_path = _test_dir + "/assets/foregrounds/fg1.png"
	assert_eq(_dialog._get_prefix_for_path(fg_path), "fg_")
