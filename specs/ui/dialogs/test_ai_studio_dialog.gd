extends GutTest

## Tests pour AIStudioDialog — Studio IA avec onglets Décliner et Expressions

var AIStudioDialog = load("res://src/ui/dialogs/ai_studio_dialog.gd")
var ExpressionQueueService = load("res://src/services/expression_queue_service.gd")
var ComfyUIConfig = load("res://src/services/comfyui_config.gd")

var _dialog: Window
var _test_dir: String = ""
var _config_path: String = ""


func before_each():
	_dialog = Window.new()
	_dialog.set_script(AIStudioDialog)
	add_child_autofree(_dialog)
	_test_dir = "user://test_ai_studio_%d" % randi()
	_config_path = "user://test_ai_studio_config_%d.cfg" % randi()


func after_each():
	_remove_dir_recursive(_test_dir)
	if FileAccess.file_exists(_config_path):
		DirAccess.remove_absolute(_config_path)


# ========================================================
# Structure UI
# ========================================================

func test_is_window():
	assert_is(_dialog, Window)


func test_has_title():
	assert_eq(_dialog.title, "Studio IA")


func test_has_tab_container():
	assert_not_null(_dialog._tab_container)
	assert_is(_dialog._tab_container, TabContainer)


func test_has_two_tabs():
	assert_eq(_dialog._tab_container.get_tab_count(), 2)


func test_tab_decliner_exists():
	assert_eq(_dialog._tab_container.get_tab_title(0), "Décliner")


func test_tab_expressions_exists():
	assert_eq(_dialog._tab_container.get_tab_title(1), "Expressions")


func test_has_shared_url_input():
	assert_not_null(_dialog._url_input)
	assert_is(_dialog._url_input, LineEdit)


func test_has_shared_token_input():
	assert_not_null(_dialog._token_input)
	assert_is(_dialog._token_input, LineEdit)
	assert_true(_dialog._token_input.secret)


func test_has_image_preview():
	assert_not_null(_dialog._image_preview)


func test_is_exclusive():
	assert_true(_dialog.exclusive)


# ========================================================
# Décliner Tab — Structure
# ========================================================

func test_decl_has_workflow_option():
	assert_not_null(_dialog._decl_workflow_option)
	assert_is(_dialog._decl_workflow_option, OptionButton)


func test_decl_workflow_has_two_items():
	assert_eq(_dialog._decl_workflow_option.item_count, 2)


func test_decl_workflow_default_creation():
	assert_eq(_dialog._decl_workflow_option.selected, 0)


func test_decl_has_source_preview():
	assert_not_null(_dialog._decl_source_preview)
	assert_is(_dialog._decl_source_preview, TextureRect)


func test_decl_has_source_path_label():
	assert_not_null(_dialog._decl_source_path_label)
	assert_is(_dialog._decl_source_path_label, Label)


func test_decl_has_choose_source_btn():
	assert_not_null(_dialog._decl_choose_source_btn)
	assert_is(_dialog._decl_choose_source_btn, Button)


func test_decl_has_choose_gallery_btn():
	assert_not_null(_dialog._decl_choose_gallery_btn)
	assert_is(_dialog._decl_choose_gallery_btn, Button)


func test_decl_has_prompt_input():
	assert_not_null(_dialog._decl_prompt_input)
	assert_is(_dialog._decl_prompt_input, TextEdit)


func test_decl_has_cfg_slider():
	assert_not_null(_dialog._decl_cfg_slider)
	assert_is(_dialog._decl_cfg_slider, HSlider)
	assert_eq(_dialog._decl_cfg_slider.min_value, 1.0)
	assert_eq(_dialog._decl_cfg_slider.max_value, 30.0)
	assert_eq(_dialog._decl_cfg_slider.step, 0.5)
	assert_eq(_dialog._decl_cfg_slider.value, 1.0)


func test_decl_has_steps_slider():
	assert_not_null(_dialog._decl_steps_slider)
	assert_is(_dialog._decl_steps_slider, HSlider)
	assert_eq(_dialog._decl_steps_slider.min_value, 1.0)
	assert_eq(_dialog._decl_steps_slider.max_value, 50.0)
	assert_eq(_dialog._decl_steps_slider.step, 1.0)
	assert_eq(_dialog._decl_steps_slider.value, 4.0)


func test_decl_has_generate_btn():
	assert_not_null(_dialog._decl_generate_btn)
	assert_is(_dialog._decl_generate_btn, Button)


func test_decl_has_result_preview():
	assert_not_null(_dialog._decl_result_preview)
	assert_is(_dialog._decl_result_preview, TextureRect)


func test_decl_has_status_label():
	assert_not_null(_dialog._decl_status_label)
	assert_is(_dialog._decl_status_label, Label)


func test_decl_has_progress_bar():
	assert_not_null(_dialog._decl_progress_bar)
	assert_is(_dialog._decl_progress_bar, ProgressBar)


func test_decl_has_name_input():
	assert_not_null(_dialog._decl_name_input)
	assert_is(_dialog._decl_name_input, LineEdit)


func test_decl_has_save_btn():
	assert_not_null(_dialog._decl_save_btn)
	assert_is(_dialog._decl_save_btn, Button)
	assert_eq(_dialog._decl_save_btn.text, "Sauvegarder")


func test_decl_has_regenerate_btn():
	assert_not_null(_dialog._decl_regenerate_btn)
	assert_is(_dialog._decl_regenerate_btn, Button)


# ========================================================
# Décliner Tab — État initial
# ========================================================

func test_decl_generate_btn_initially_disabled():
	assert_true(_dialog._decl_generate_btn.disabled)


func test_decl_save_btn_initially_disabled():
	assert_true(_dialog._decl_save_btn.disabled)


func test_decl_regenerate_btn_initially_disabled():
	assert_true(_dialog._decl_regenerate_btn.disabled)


func test_decl_name_input_initially_not_editable():
	assert_false(_dialog._decl_name_input.editable)


func test_decl_progress_bar_initially_hidden():
	assert_false(_dialog._decl_progress_bar.visible)


func test_decl_source_path_label_initial_text():
	assert_eq(_dialog._decl_source_path_label.text, "Aucune image sélectionnée")


func test_decl_initial_source_image_path_empty():
	assert_eq(_dialog._decl_source_image_path, "")


func test_decl_initial_generated_image_null():
	assert_null(_dialog._decl_generated_image)


# ========================================================
# Décliner Tab — Generate button state
# ========================================================

func test_decl_generate_enabled_when_all_fields_set():
	_dialog._url_input.text = "http://localhost:8188"
	_dialog._decl_prompt_input.text = "a character"
	_dialog._decl_source_image_path = "/tmp/test.png"
	_dialog._update_decl_generate_button()
	assert_false(_dialog._decl_generate_btn.disabled)


func test_decl_generate_disabled_without_url():
	_dialog._url_input.text = ""
	_dialog._decl_prompt_input.text = "a character"
	_dialog._decl_source_image_path = "/tmp/test.png"
	_dialog._update_decl_generate_button()
	assert_true(_dialog._decl_generate_btn.disabled)


func test_decl_generate_disabled_without_prompt():
	_dialog._url_input.text = "http://localhost:8188"
	_dialog._decl_prompt_input.text = ""
	_dialog._decl_source_image_path = "/tmp/test.png"
	_dialog._update_decl_generate_button()
	assert_true(_dialog._decl_generate_btn.disabled)


func test_decl_generate_disabled_without_source():
	_dialog._url_input.text = "http://localhost:8188"
	_dialog._decl_prompt_input.text = "a character"
	_dialog._decl_source_image_path = ""
	_dialog._update_decl_generate_button()
	assert_true(_dialog._decl_generate_btn.disabled)


# ========================================================
# Décliner Tab — Save logic
# ========================================================

func test_decl_save_creates_file():
	DirAccess.make_dir_recursive_absolute(_test_dir + "/assets/foregrounds")
	_dialog._story_base_path = _test_dir
	_dialog._decl_generated_image = Image.create(10, 10, false, Image.FORMAT_RGBA8)
	_dialog._decl_name_input.text = "test_image"
	_dialog._on_decl_save_pressed()
	assert_true(FileAccess.file_exists(_test_dir + "/assets/foregrounds/test_image.png"))


func test_decl_save_resets_state():
	DirAccess.make_dir_recursive_absolute(_test_dir + "/assets/foregrounds")
	_dialog._story_base_path = _test_dir
	_dialog._decl_generated_image = Image.create(10, 10, false, Image.FORMAT_RGBA8)
	_dialog._decl_name_input.text = "test_image"
	_dialog._on_decl_save_pressed()
	assert_null(_dialog._decl_generated_image)
	assert_true(_dialog._decl_save_btn.disabled)


func test_decl_save_shows_overwrite_confirmation():
	DirAccess.make_dir_recursive_absolute(_test_dir + "/assets/foregrounds")
	# Create existing file
	var img = Image.create(10, 10, false, Image.FORMAT_RGBA8)
	img.save_png(_test_dir + "/assets/foregrounds/test_dup.png")
	_dialog._story_base_path = _test_dir
	_dialog._decl_generated_image = Image.create(10, 10, false, Image.FORMAT_RGBA8)
	_dialog._decl_name_input.text = "test_dup"
	_dialog._on_decl_save_pressed()
	# Should show a confirmation dialog, not save immediately
	var confirm_dialog: ConfirmationDialog = null
	for child in _dialog.get_children():
		if child is ConfirmationDialog:
			confirm_dialog = child
			break
	assert_not_null(confirm_dialog, "A confirmation dialog should appear")
	assert_string_contains(confirm_dialog.dialog_text, "test_dup.png")


func test_decl_save_overwrites_on_confirm():
	DirAccess.make_dir_recursive_absolute(_test_dir + "/assets/foregrounds")
	var img = Image.create(10, 10, false, Image.FORMAT_RGBA8)
	img.save_png(_test_dir + "/assets/foregrounds/test_dup.png")
	_dialog._story_base_path = _test_dir
	_dialog._decl_generated_image = Image.create(10, 10, false, Image.FORMAT_RGBA8)
	_dialog._decl_name_input.text = "test_dup"
	_dialog._on_decl_save_pressed()
	# Confirm overwrite
	for child in _dialog.get_children():
		if child is ConfirmationDialog:
			child.confirmed.emit()
			break
	assert_true(FileAccess.file_exists(_test_dir + "/assets/foregrounds/test_dup.png"))
	assert_false(FileAccess.file_exists(_test_dir + "/assets/foregrounds/test_dup_1.png"))


# ========================================================
# Expressions Tab — Structure
# ========================================================

func test_expr_has_source_preview():
	assert_not_null(_dialog._expr_source_preview)
	assert_is(_dialog._expr_source_preview, TextureRect)


func test_expr_has_source_path_label():
	assert_not_null(_dialog._expr_source_path_label)
	assert_is(_dialog._expr_source_path_label, Label)


func test_expr_has_choose_source_btn():
	assert_not_null(_dialog._expr_choose_source_btn)
	assert_is(_dialog._expr_choose_source_btn, Button)


func test_expr_has_choose_gallery_btn():
	assert_not_null(_dialog._expr_choose_gallery_btn)
	assert_is(_dialog._expr_choose_gallery_btn, Button)


func test_expr_has_prefix_input():
	assert_not_null(_dialog._expr_prefix_input)
	assert_is(_dialog._expr_prefix_input, LineEdit)


func test_expr_has_cfg_slider():
	assert_not_null(_dialog._expr_cfg_slider)
	assert_is(_dialog._expr_cfg_slider, HSlider)


func test_expr_has_steps_slider():
	assert_not_null(_dialog._expr_steps_slider)
	assert_is(_dialog._expr_steps_slider, HSlider)


func test_expr_has_default_expression_checkboxes():
	# At least 30 default expressions
	var default_count = AIStudioDialog.DEFAULT_EXPRESSIONS.size()
	assert_true(_dialog._expr_expression_checkboxes.size() >= default_count)


func test_expr_expression_labels():
	assert_eq(_dialog._expr_expression_checkboxes[0].text, "smile")
	assert_eq(_dialog._expr_expression_checkboxes[1].text, "sad")
	assert_eq(_dialog._expr_expression_checkboxes[2].text, "shy")
	assert_eq(_dialog._expr_expression_checkboxes[3].text, "grumpy")
	assert_eq(_dialog._expr_expression_checkboxes[4].text, "laughing out loud")


func test_expr_first_expression_checked_by_default():
	assert_true(_dialog._expr_expression_checkboxes[0].button_pressed)


func test_expr_has_custom_input():
	assert_not_null(_dialog._expr_custom_input)
	assert_is(_dialog._expr_custom_input, LineEdit)


func test_expr_has_add_custom_btn():
	assert_not_null(_dialog._expr_add_custom_btn)
	assert_is(_dialog._expr_add_custom_btn, Button)


func test_expr_has_generate_btn():
	assert_not_null(_dialog._expr_generate_btn)
	assert_is(_dialog._expr_generate_btn, Button)


func test_expr_has_cancel_btn():
	assert_not_null(_dialog._expr_cancel_btn)
	assert_is(_dialog._expr_cancel_btn, Button)


func test_expr_has_status_label():
	assert_not_null(_dialog._expr_status_label)
	assert_is(_dialog._expr_status_label, Label)


func test_expr_has_progress_bar():
	assert_not_null(_dialog._expr_progress_bar)
	assert_is(_dialog._expr_progress_bar, ProgressBar)


func test_expr_has_results_grid():
	assert_not_null(_dialog._expr_results_grid)
	assert_is(_dialog._expr_results_grid, GridContainer)
	assert_eq(_dialog._expr_results_grid.columns, 4)


func test_expr_has_save_all_btn():
	assert_not_null(_dialog._expr_save_all_btn)
	assert_is(_dialog._expr_save_all_btn, Button)


func test_expr_has_context_menu():
	assert_not_null(_dialog._expr_context_menu)
	assert_is(_dialog._expr_context_menu, PopupMenu)


# ========================================================
# Expressions Tab — État initial
# ========================================================

func test_expr_generate_btn_initially_disabled():
	assert_true(_dialog._expr_generate_btn.disabled)


func test_expr_cancel_btn_initially_hidden():
	assert_false(_dialog._expr_cancel_btn.visible)


func test_expr_save_all_btn_initially_disabled():
	assert_true(_dialog._expr_save_all_btn.disabled)


func test_expr_progress_bar_initially_hidden():
	assert_false(_dialog._expr_progress_bar.visible)


func test_expr_initial_source_path_empty():
	assert_eq(_dialog._expr_source_image_path, "")


func test_expr_initial_not_generating():
	assert_false(_dialog._expr_generating)


# ========================================================
# Expressions Tab — Generate button state
# ========================================================

func test_expr_generate_enabled_when_all_fields_set():
	_dialog._url_input.text = "http://localhost:8188"
	_dialog._expr_source_image_path = "/tmp/test.png"
	_dialog._expr_prefix_input.text = "hero"
	# front view already checked, smile already checked
	_dialog._update_expr_generate_button()
	assert_false(_dialog._expr_generate_btn.disabled)


func test_expr_generate_disabled_without_url():
	_dialog._url_input.text = ""
	_dialog._expr_source_image_path = "/tmp/test.png"
	_dialog._expr_prefix_input.text = "hero"
	_dialog._update_expr_generate_button()
	assert_true(_dialog._expr_generate_btn.disabled)


func test_expr_generate_disabled_without_source():
	_dialog._url_input.text = "http://localhost:8188"
	_dialog._expr_source_image_path = ""
	_dialog._expr_prefix_input.text = "hero"
	_dialog._update_expr_generate_button()
	assert_true(_dialog._expr_generate_btn.disabled)


func test_expr_generate_disabled_without_prefix():
	_dialog._url_input.text = "http://localhost:8188"
	_dialog._expr_source_image_path = "/tmp/test.png"
	_dialog._expr_prefix_input.text = ""
	_dialog._update_expr_generate_button()
	assert_true(_dialog._expr_generate_btn.disabled)


func test_expr_generate_disabled_without_expression():
	_dialog._url_input.text = "http://localhost:8188"
	_dialog._expr_source_image_path = "/tmp/test.png"
	_dialog._expr_prefix_input.text = "hero"
	# Uncheck all expressions
	for cb in _dialog._expr_expression_checkboxes:
		cb.button_pressed = false
	_dialog._update_expr_generate_button()
	assert_true(_dialog._expr_generate_btn.disabled)


# ========================================================
# Expressions Tab — Expression selection
# ========================================================

func test_get_selected_expressions_default():
	var exprs = _dialog._get_selected_expressions()
	assert_eq(exprs, ["smile"])


func test_get_selected_expressions_multiple():
	_dialog._expr_expression_checkboxes[1].button_pressed = true
	var exprs = _dialog._get_selected_expressions()
	assert_eq(exprs, ["smile", "sad"])


# ========================================================
# Expressions Tab — Custom expressions
# ========================================================

func test_add_custom_expression():
	var initial_count = _dialog._expr_expression_checkboxes.size()
	_dialog._add_custom_expression_ui("test_unique_expr")
	assert_eq(_dialog._expr_expression_checkboxes.size(), initial_count + 1)
	assert_eq(_dialog._expr_expression_checkboxes[initial_count].text, "test_unique_expr")


func test_add_custom_expression_via_input_clears_text():
	_dialog._expr_custom_input.text = "excited"
	_dialog._on_expr_add_custom()
	assert_eq(_dialog._expr_custom_input.text, "")


func test_add_empty_custom_expression_ignored():
	var initial_count = _dialog._expr_expression_checkboxes.size()
	_dialog._expr_custom_input.text = ""
	_dialog._on_expr_add_custom()
	assert_eq(_dialog._expr_expression_checkboxes.size(), initial_count)


func test_add_whitespace_custom_expression_ignored():
	var initial_count = _dialog._expr_expression_checkboxes.size()
	_dialog._expr_custom_input.text = "   "
	_dialog._on_expr_add_custom()
	assert_eq(_dialog._expr_expression_checkboxes.size(), initial_count)


func test_custom_expression_has_delete_button():
	_dialog._add_custom_expression_ui("test_unique_expr")
	var last_hbox = _dialog._expr_custom_container.get_child(_dialog._expr_custom_container.get_child_count() - 1)
	assert_eq(last_hbox.get_child_count(), 2)
	assert_is(last_hbox.get_child(1), Button)
	assert_eq(last_hbox.get_child(1).text, "✕")


func test_add_duplicate_expression_ignored():
	var initial_count = _dialog._expr_expression_checkboxes.size()
	_dialog._expr_custom_input.text = "smile"
	_dialog._on_expr_add_custom()
	assert_eq(_dialog._expr_expression_checkboxes.size(), initial_count)


func test_add_duplicate_expression_case_insensitive():
	var initial_count = _dialog._expr_expression_checkboxes.size()
	_dialog._expr_custom_input.text = "Smile"
	_dialog._on_expr_add_custom()
	assert_eq(_dialog._expr_expression_checkboxes.size(), initial_count)


# ========================================================
# Expressions Tab — Results grid
# ========================================================

func test_build_results_grid_creates_cells():
	_dialog._expr_queue = ExpressionQueueService.new()
	_dialog._expr_queue.build_queue(["smile", "sad"], "hero")
	_dialog._build_results_grid()
	assert_eq(_dialog._expr_results_grid.get_child_count(), 2)


func test_build_results_grid_clears_previous():
	_dialog._expr_queue = ExpressionQueueService.new()
	_dialog._expr_queue.build_queue(["smile"], "hero")
	_dialog._build_results_grid()
	_dialog._expr_queue.build_queue(["smile", "sad"], "hero")
	_dialog._build_results_grid()
	assert_eq(_dialog._expr_results_grid.get_child_count(), 2)


func test_grid_cell_has_preview():
	_dialog._expr_queue = ExpressionQueueService.new()
	_dialog._expr_queue.build_queue(["smile"], "hero")
	_dialog._build_results_grid()
	var cell = _dialog._expr_results_grid.get_child(0)
	assert_true(cell.has_node("VBox/Preview"))


func test_grid_cell_has_label():
	_dialog._expr_queue = ExpressionQueueService.new()
	_dialog._expr_queue.build_queue(["smile"], "hero")
	_dialog._build_results_grid()
	var cell = _dialog._expr_results_grid.get_child(0)
	assert_true(cell.has_node("VBox/Label"))
	var lbl = cell.get_node("VBox/Label")
	assert_eq(lbl.text, "hero_smile")


func test_grid_cell_has_status():
	_dialog._expr_queue = ExpressionQueueService.new()
	_dialog._expr_queue.build_queue(["smile"], "hero")
	_dialog._build_results_grid()
	var cell = _dialog._expr_results_grid.get_child(0)
	assert_true(cell.has_node("VBox/Status"))
	var status = cell.get_node("VBox/Status")
	assert_eq(status.text, "En attente")


# ========================================================
# Expressions Tab — Save all
# ========================================================

func test_save_all_creates_files():
	DirAccess.make_dir_recursive_absolute(_test_dir + "/assets/foregrounds")
	_dialog._story_base_path = _test_dir
	_dialog._expr_queue = ExpressionQueueService.new()
	_dialog._expr_queue.build_queue(["smile", "sad"], "hero")
	var img1 = Image.create(10, 10, false, Image.FORMAT_RGBA8)
	var img2 = Image.create(10, 10, false, Image.FORMAT_RGBA8)
	_dialog._expr_queue.mark_generating(0)
	_dialog._expr_queue.mark_completed(0, img1)
	_dialog._expr_queue.mark_generating(1)
	_dialog._expr_queue.mark_completed(1, img2)
	_dialog._on_expr_save_all_pressed()
	assert_true(FileAccess.file_exists(_test_dir + "/assets/foregrounds/hero_smile.png"))
	assert_true(FileAccess.file_exists(_test_dir + "/assets/foregrounds/hero_sad.png"))


func test_save_all_disables_button():
	DirAccess.make_dir_recursive_absolute(_test_dir + "/assets/foregrounds")
	_dialog._story_base_path = _test_dir
	_dialog._expr_queue = ExpressionQueueService.new()
	_dialog._expr_queue.build_queue(["smile"], "hero")
	_dialog._expr_queue.mark_generating(0)
	_dialog._expr_queue.mark_completed(0, Image.create(10, 10, false, Image.FORMAT_RGBA8))
	_dialog._on_expr_save_all_pressed()
	assert_true(_dialog._expr_save_all_btn.disabled)


func test_save_all_skips_failed_items():
	DirAccess.make_dir_recursive_absolute(_test_dir + "/assets/foregrounds")
	_dialog._story_base_path = _test_dir
	_dialog._expr_queue = ExpressionQueueService.new()
	_dialog._expr_queue.build_queue(["smile", "sad"], "hero")
	_dialog._expr_queue.mark_generating(0)
	_dialog._expr_queue.mark_completed(0, Image.create(10, 10, false, Image.FORMAT_RGBA8))
	_dialog._expr_queue.mark_generating(1)
	_dialog._expr_queue.mark_failed(1, "error")
	_dialog._on_expr_save_all_pressed()
	assert_true(FileAccess.file_exists(_test_dir + "/assets/foregrounds/hero_smile.png"))
	assert_false(FileAccess.file_exists(_test_dir + "/assets/foregrounds/hero_sad.png"))


# ========================================================
# Expressions Tab — Context menu
# ========================================================

func test_context_menu_has_regenerate():
	assert_eq(_dialog._expr_context_menu.get_item_text(0), "Régénérer")


func test_context_menu_has_delete():
	assert_eq(_dialog._expr_context_menu.get_item_text(1), "Supprimer")


# ========================================================
# Setup
# ========================================================

func test_setup_stores_story():
	var story = RefCounted.new()
	_dialog.setup(story, _test_dir)
	assert_eq(_dialog._story, story)
	assert_eq(_dialog._story_base_path, _test_dir)


func test_setup_gallery_btn_disabled_without_story():
	_dialog.setup(null, "")
	assert_true(_dialog._decl_choose_gallery_btn.disabled)
	assert_true(_dialog._expr_choose_gallery_btn.disabled)


func test_setup_gallery_btn_enabled_with_story():
	_dialog.setup(RefCounted.new(), _test_dir)
	assert_false(_dialog._decl_choose_gallery_btn.disabled)
	assert_false(_dialog._expr_choose_gallery_btn.disabled)


# ========================================================
# Resolve unique path
# ========================================================

func test_resolve_unique_path_no_conflict():
	DirAccess.make_dir_recursive_absolute(_test_dir)
	var result = AIStudioDialog._resolve_unique_path(_test_dir, "image.png")
	assert_eq(result, _test_dir + "/image.png")


func test_resolve_unique_path_with_conflict():
	DirAccess.make_dir_recursive_absolute(_test_dir)
	var img = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.save_png(_test_dir + "/image.png")
	var result = AIStudioDialog._resolve_unique_path(_test_dir, "image.png")
	assert_eq(result, _test_dir + "/image_1.png")


# ========================================================
# ComfyUIConfig — Custom expressions persistence
# ========================================================

func test_config_save_load_custom_expressions():
	var config = ComfyUIConfig.new()
	config.set_custom_expressions(PackedStringArray(["excited", "bored"]))
	config.save_to(_config_path)
	var loaded = ComfyUIConfig.new()
	loaded.load_from(_config_path)
	var customs = loaded.get_custom_expressions()
	assert_eq(customs.size(), 2)
	assert_eq(customs[0], "excited")
	assert_eq(customs[1], "bored")


func test_config_empty_custom_expressions():
	var config = ComfyUIConfig.new()
	config.save_to(_config_path)
	var loaded = ComfyUIConfig.new()
	loaded.load_from(_config_path)
	assert_eq(loaded.get_custom_expressions().size(), 0)


# ========================================================
# Helpers
# ========================================================

func _remove_dir_recursive(path: String) -> void:
	var dir = DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file = dir.get_next()
	while file != "":
		if dir.current_is_dir():
			_remove_dir_recursive(path + "/" + file)
		else:
			DirAccess.remove_absolute(path + "/" + file)
		file = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)
