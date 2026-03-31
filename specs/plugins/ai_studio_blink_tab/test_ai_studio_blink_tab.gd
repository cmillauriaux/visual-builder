extends GutTest

## Tests unitaires pour ai_studio_blink_tab.gd

const BlinkTab = preload("res://plugins/ai_studio/ai_studio_blink_tab.gd")


# Helper: creates a minimal initialized blink tab with a real parent window and tab container.
# By default, returns a config with empty URL (so generate button stays disabled by default).
func _make_tab(url: String = "") -> Dictionary:
	var parent_window = Window.new()
	parent_window.size = Vector2i(800, 600)
	add_child_autofree(parent_window)

	var neg_input = TextEdit.new()
	add_child_autofree(neg_input)

	var tab = BlinkTab.new()
	tab.initialize(
		parent_window,
		func() -> RefCounted:
			var config = load("res://src/services/comfyui_config.gd").new()
			config.set_url(url)
			return config,
		neg_input,
		func(_tex, _name): pass,
		func(_cb): pass,
		func(): pass,
		func(dir, fname): return dir + "/" + fname
	)

	var tab_container = TabContainer.new()
	add_child_autofree(tab_container)
	tab.build_tab(tab_container)

	return {"tab": tab, "tab_container": tab_container, "parent_window": parent_window, "neg_input": neg_input}


func test_build_tab_creates_tab_named_blink() -> void:
	var d = _make_tab()
	var tab_container: TabContainer = d["tab_container"]
	assert_eq(tab_container.get_tab_count(), 1)
	assert_eq(tab_container.get_tab_title(0), "Blink")


func test_build_tab_creates_gallery_button() -> void:
	var d = _make_tab()
	var tab: BlinkTab = d["tab"]
	assert_not_null(tab._gallery_btn)
	assert_true(tab._gallery_btn is Button)


func test_build_tab_creates_selection_count_label() -> void:
	var d = _make_tab()
	var tab: BlinkTab = d["tab"]
	assert_not_null(tab._selection_count_label)
	assert_eq(tab._selection_count_label.text, "(0 sélectionnée(s))")


func test_build_tab_creates_generate_button_disabled() -> void:
	var d = _make_tab()
	var tab: BlinkTab = d["tab"]
	assert_not_null(tab._generate_btn)
	assert_true(tab._generate_btn.disabled, "Generate button should start disabled")


func test_build_tab_creates_cancel_button_hidden() -> void:
	var d = _make_tab()
	var tab: BlinkTab = d["tab"]
	assert_not_null(tab._cancel_btn)
	assert_false(tab._cancel_btn.visible, "Cancel button should start hidden")


func test_build_tab_creates_save_all_button_disabled() -> void:
	var d = _make_tab()
	var tab: BlinkTab = d["tab"]
	assert_not_null(tab._save_all_btn)
	assert_true(tab._save_all_btn.disabled, "Save all button should start disabled")


func test_build_tab_creates_preview_button_disabled() -> void:
	var d = _make_tab()
	var tab: BlinkTab = d["tab"]
	assert_not_null(tab._preview_btn)
	assert_true(tab._preview_btn.disabled, "Preview button should start disabled")


func test_build_tab_creates_progress_bar_hidden() -> void:
	var d = _make_tab()
	var tab: BlinkTab = d["tab"]
	assert_not_null(tab._progress_bar)
	assert_false(tab._progress_bar.visible, "Progress bar should start hidden")


func test_build_tab_creates_results_grid_with_four_columns() -> void:
	var d = _make_tab()
	var tab: BlinkTab = d["tab"]
	assert_not_null(tab._results_grid)
	assert_eq(tab._results_grid.columns, 4)


func test_selected_sources_starts_empty() -> void:
	var d = _make_tab()
	var tab: BlinkTab = d["tab"]
	assert_eq(tab._selected_sources.size(), 0)


func test_on_multi_gallery_selected_updates_selected_sources() -> void:
	var d = _make_tab()
	var tab: BlinkTab = d["tab"]
	tab._on_multi_gallery_selected(["/some/path/a.png", "/some/path/b.png"])
	assert_eq(tab._selected_sources.size(), 2)


func test_on_multi_gallery_selected_updates_count_label() -> void:
	var d = _make_tab()
	var tab: BlinkTab = d["tab"]
	tab._on_multi_gallery_selected(["/some/path/a.png"])
	assert_eq(tab._selection_count_label.text, "(1 sélectionnée(s))")


func test_on_multi_gallery_selected_empty_shows_zero() -> void:
	var d = _make_tab()
	var tab: BlinkTab = d["tab"]
	tab._on_multi_gallery_selected(["/some/path/a.png"])
	tab._on_multi_gallery_selected([])
	assert_eq(tab._selection_count_label.text, "(0 sélectionnée(s))")


func test_generate_button_stays_disabled_when_no_images() -> void:
	var d = _make_tab()
	var tab: BlinkTab = d["tab"]
	# No images selected, no URL
	tab.update_generate_button()
	assert_true(tab._generate_btn.disabled)


func test_generate_button_stays_disabled_when_images_but_no_url() -> void:
	var d = _make_tab()
	var tab: BlinkTab = d["tab"]
	tab._on_multi_gallery_selected(["/some/path/a.png"])
	# Config URL is empty by default
	tab.update_generate_button()
	assert_true(tab._generate_btn.disabled)


func test_generate_button_enabled_when_images_and_url_set() -> void:
	var d = _make_tab("http://localhost:8188")
	var tab: BlinkTab = d["tab"]
	tab._on_multi_gallery_selected(["/some/path/a.png"])
	tab.update_generate_button()
	assert_false(tab._generate_btn.disabled)


func test_generate_button_not_changed_when_generating() -> void:
	var d = _make_tab("http://localhost:8188")
	var tab: BlinkTab = d["tab"]
	tab._on_multi_gallery_selected(["/some/path/a.png"])
	# Enable the button first
	tab.update_generate_button()
	assert_false(tab._generate_btn.disabled)
	# Simulate generation started: button was disabled by _on_generate_pressed
	tab._generate_btn.disabled = true
	tab._generating = true
	# update_generate_button returns early when generating, so button stays disabled
	tab.update_generate_button()
	assert_true(tab._generate_btn.disabled)


func test_setup_disables_gallery_button_when_no_story() -> void:
	var d = _make_tab()
	var tab: BlinkTab = d["tab"]
	tab.setup("", false)
	assert_true(tab._gallery_btn.disabled)


func test_setup_enables_gallery_button_when_has_story() -> void:
	var d = _make_tab()
	var tab: BlinkTab = d["tab"]
	tab.setup("/some/story", true)
	assert_false(tab._gallery_btn.disabled)


func test_setup_stores_story_base_path() -> void:
	var d = _make_tab()
	var tab: BlinkTab = d["tab"]
	tab.setup("/my/story/path", true)
	assert_eq(tab._story_base_path, "/my/story/path")


func test_cancel_generation_does_not_crash_when_no_client() -> void:
	var d = _make_tab()
	var tab: BlinkTab = d["tab"]
	# Should not throw
	tab.cancel_generation()
	assert_null(tab._client)


func test_set_image_preview_stores_reference() -> void:
	var d = _make_tab()
	var tab: BlinkTab = d["tab"]
	var fake_preview = Control.new()
	add_child_autofree(fake_preview)
	tab.set_image_preview(fake_preview)
	assert_eq(tab._image_preview, fake_preview)


func test_cfg_hint_visible_when_has_negative_and_low_cfg() -> void:
	var d = _make_tab()
	var tab: BlinkTab = d["tab"]
	tab._cfg_slider.value = 1.0
	tab.update_cfg_hint(true)
	assert_true(tab._cfg_hint.visible)


func test_cfg_hint_hidden_when_no_negative() -> void:
	var d = _make_tab()
	var tab: BlinkTab = d["tab"]
	tab._cfg_slider.value = 1.0
	tab.update_cfg_hint(false)
	assert_false(tab._cfg_hint.visible)


func test_cfg_hint_hidden_when_cfg_high_enough() -> void:
	var d = _make_tab()
	var tab: BlinkTab = d["tab"]
	tab._cfg_slider.value = 5.0
	tab.update_cfg_hint(true)
	assert_false(tab._cfg_hint.visible)


func test_selected_grid_rebuilt_after_multi_gallery_selected() -> void:
	var d = _make_tab()
	var tab: BlinkTab = d["tab"]
	# Initially empty
	assert_eq(tab._selected_grid.get_child_count(), 0)
	# Selecting with non-existing paths: grid cells are created regardless of texture loading
	tab._on_multi_gallery_selected(["/nonexistent/a.png", "/nonexistent/b.png"])
	# queue_free() is deferred for old children — wait a frame
	await get_tree().process_frame
	assert_eq(tab._selected_grid.get_child_count(), 2)


func test_selected_grid_cleared_when_empty_selection() -> void:
	var d = _make_tab()
	var tab: BlinkTab = d["tab"]
	tab._on_multi_gallery_selected(["/nonexistent/a.png"])
	assert_eq(tab._selected_grid.get_child_count(), 1)
	tab._on_multi_gallery_selected([])
	# queue_free() is deferred — wait a frame for nodes to be removed
	await get_tree().process_frame
	assert_eq(tab._selected_grid.get_child_count(), 0)
