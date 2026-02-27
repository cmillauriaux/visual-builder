extends GutTest

const AIGenerateDialog = preload("res://src/ui/dialogs/ai_generate_dialog.gd")
const ComfyUIConfig = preload("res://src/services/comfyui_config.gd")

var _dialog: Window

func before_each():
	_dialog = Window.new()
	_dialog.set_script(AIGenerateDialog)
	add_child_autofree(_dialog)

# --- Structure UI ---

func test_dialog_is_window():
	assert_is(_dialog, Window)

func test_dialog_has_title():
	assert_ne(_dialog.title, "")

func test_dialog_has_url_field():
	assert_not_null(_dialog._url_input, "URL input should exist")
	assert_is(_dialog._url_input, LineEdit)

func test_dialog_has_token_field():
	assert_not_null(_dialog._token_input, "Token input should exist")
	assert_is(_dialog._token_input, LineEdit)
	assert_true(_dialog._token_input.secret, "Token should be masked")

func test_dialog_has_prompt_field():
	assert_not_null(_dialog._prompt_input, "Prompt input should exist")
	assert_is(_dialog._prompt_input, TextEdit)

func test_dialog_has_generate_button():
	assert_not_null(_dialog._generate_btn, "Generate button should exist")
	assert_is(_dialog._generate_btn, Button)

func test_dialog_has_accept_button():
	assert_not_null(_dialog._accept_btn, "Accept button should exist")
	assert_is(_dialog._accept_btn, Button)

func test_dialog_has_regenerate_button():
	assert_not_null(_dialog._regenerate_btn, "Regenerate button should exist")
	assert_is(_dialog._regenerate_btn, Button)

func test_dialog_has_status_label():
	assert_not_null(_dialog._status_label, "Status label should exist")
	assert_is(_dialog._status_label, Label)

func test_dialog_has_progress_bar():
	assert_not_null(_dialog._progress_bar, "Progress bar should exist")
	assert_is(_dialog._progress_bar, ProgressBar)

func test_dialog_has_source_path_label():
	assert_not_null(_dialog._source_path_label, "Source path label should exist")
	assert_is(_dialog._source_path_label, Label)

func test_dialog_has_result_preview():
	assert_not_null(_dialog._result_preview, "Result preview should exist")
	assert_is(_dialog._result_preview, TextureRect)

# --- Signal ---

func test_has_foreground_accepted_signal():
	assert_true(_dialog.has_signal("foreground_accepted"))

# --- Initial state ---

func test_accept_button_initially_disabled():
	assert_true(_dialog._accept_btn.disabled)

func test_regenerate_button_initially_disabled():
	assert_true(_dialog._regenerate_btn.disabled)

func test_progress_bar_initially_hidden():
	assert_false(_dialog._progress_bar.visible)

# --- Config loading ---

func test_loads_config_on_setup():
	var config = ComfyUIConfig.new()
	config.set_url("http://test-server:9999")
	config.set_token("test-token")
	_dialog.setup(config, "")
	assert_eq(_dialog._url_input.text, "http://test-server:9999")
	assert_eq(_dialog._token_input.text, "test-token")

# --- Source image ---

func test_set_source_image_path():
	_dialog.setup(ComfyUIConfig.new(), "/path/to/image.png")
	assert_eq(_dialog._source_image_path, "/path/to/image.png")
	assert_string_contains(_dialog._source_path_label.text, "image.png")

func test_set_source_image_empty():
	_dialog.setup(ComfyUIConfig.new(), "")
	assert_eq(_dialog._source_image_path, "")

# --- Generate button state ---

func test_generate_enabled_when_fields_filled():
	_dialog.setup(ComfyUIConfig.new(), "/path/to/image.png")
	_dialog._url_input.text = "http://localhost:8188"
	_dialog._prompt_input.text = "a cute cat"
	_dialog._update_generate_button_state()
	assert_false(_dialog._generate_btn.disabled)

func test_generate_disabled_without_source():
	_dialog.setup(ComfyUIConfig.new(), "")
	_dialog._url_input.text = "http://localhost:8188"
	_dialog._prompt_input.text = "a cute cat"
	_dialog._update_generate_button_state()
	assert_true(_dialog._generate_btn.disabled)

func test_generate_disabled_without_prompt():
	_dialog.setup(ComfyUIConfig.new(), "/path/to/img.png")
	_dialog._url_input.text = "http://localhost:8188"
	_dialog._prompt_input.text = ""
	_dialog._update_generate_button_state()
	assert_true(_dialog._generate_btn.disabled)

# --- Status updates ---

func test_show_status_message():
	_dialog._show_status("Uploading...")
	assert_eq(_dialog._status_label.text, "Uploading...")
	assert_true(_dialog._progress_bar.visible)

func test_show_error_message():
	_dialog._show_error("Network error")
	assert_string_contains(_dialog._status_label.text, "Network error")
	assert_false(_dialog._progress_bar.visible)

func test_show_success_message():
	_dialog._show_success("Done!")
	assert_eq(_dialog._status_label.text, "Done!")
	assert_false(_dialog._progress_bar.visible)

# --- Progress bar indeterminate ---

func test_progress_bar_is_indeterminate():
	assert_true(_dialog._progress_bar.indeterminate)

# --- Status colors ---

func test_status_color_on_progress():
	_dialog._show_status("loading")
	var color = _dialog._status_label.get_theme_color("font_color")
	assert_almost_eq(color.r, 0.8, 0.1)

func test_status_color_on_success():
	_dialog._show_success("ok")
	var color = _dialog._status_label.get_theme_color("font_color")
	assert_true(color.g > 0.8, "Success should be green")

func test_status_color_on_error():
	_dialog._show_error("fail")
	var color = _dialog._status_label.get_theme_color("font_color")
	assert_true(color.r > 0.8, "Error should be red")

# --- Inputs disabled during generation ---

func test_set_inputs_disabled():
	_dialog._set_inputs_enabled(false)
	assert_false(_dialog._url_input.editable)
	assert_false(_dialog._token_input.editable)
	assert_false(_dialog._prompt_input.editable)
	assert_true(_dialog._choose_source_btn.disabled)

func test_set_inputs_enabled():
	_dialog._set_inputs_enabled(false)
	_dialog._set_inputs_enabled(true)
	assert_true(_dialog._url_input.editable)
	assert_true(_dialog._token_input.editable)
	assert_true(_dialog._prompt_input.editable)
	assert_false(_dialog._choose_source_btn.disabled)

# --- Story name ---

func test_set_story_name():
	_dialog.set_story_name("my_story")
	assert_eq(_dialog._story_name, "my_story")

# --- Source preview loading ---

func test_load_source_preview_with_valid_image():
	var tmp_dir = "user://test_ai_preview_%d" % randi()
	DirAccess.make_dir_recursive_absolute(tmp_dir)
	var img_path = tmp_dir + "/source.png"
	var img = Image.create(1, 1, false, Image.FORMAT_RGB8)
	img.save_png(img_path)
	_dialog._load_source_preview(img_path)
	assert_not_null(_dialog._source_preview.texture)
	_remove_dir(tmp_dir)

func test_load_source_preview_with_invalid_path_clears_texture():
	_dialog._source_preview.texture = ImageTexture.new()
	_dialog._load_source_preview("user://nonexistent/path.png")
	assert_null(_dialog._source_preview.texture)

func _remove_dir(path: String) -> void:
	var dir = DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname != "." and fname != "..":
			DirAccess.remove_absolute(path + "/" + fname)
		fname = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)
