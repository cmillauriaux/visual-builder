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


func test_build_tab_creates_eye_zone_dropdown() -> void:
	var d = _make_tab()
	var tab: BlinkTab = d["tab"]
	assert_not_null(tab._eye_zone_dropdown)
	assert_true(tab._eye_zone_dropdown is OptionButton)
	assert_eq(tab._eye_zone_dropdown.item_count, 2)
	assert_eq(tab._eye_zone_dropdown.get_item_text(0), "Yeux seuls")
	assert_eq(tab._eye_zone_dropdown.get_item_text(1), "Yeux + sourcils")
	assert_eq(tab._eye_zone_dropdown.selected, 1)


func test_eye_expand_slider_default_value() -> void:
	var d = _make_tab()
	var tab: BlinkTab = d["tab"]
	assert_eq(int(tab._face_box_slider.value), 100)


func test_eye_expand_slider_range() -> void:
	var d = _make_tab()
	var tab: BlinkTab = d["tab"]
	assert_eq(int(tab._face_box_slider.min_value), 0)
	assert_eq(int(tab._face_box_slider.max_value), 150)


func test_open_multi_gallery_does_not_crash() -> void:
	# Regression: _open_multi_gallery used to set horizontal_alignment on CheckBox
	# which is an invalid property, causing a fatal script error.
	var d = _make_tab()
	var tab: BlinkTab = d["tab"]
	var parent_window: Window = d["parent_window"]

	# Create a temp directory with a test image so the gallery has content
	var temp_dir = ProjectSettings.globalize_path("user://test_blink_gallery")
	DirAccess.make_dir_recursive_absolute(temp_dir + "/assets/foregrounds")
	var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color.BLUE)
	img.save_png(temp_dir + "/assets/foregrounds/test_char.png")

	tab.setup(temp_dir, true)

	# Click the Gallery button — this triggers _open_multi_gallery
	tab._gallery_btn.emit_signal("pressed")
	await get_tree().process_frame
	await get_tree().process_frame

	# Find the gallery window that was opened
	var gallery_window: Window = null
	for child in parent_window.get_children():
		if child is Window and child.title == "Choisir les images sources":
			gallery_window = child
			break

	assert_not_null(gallery_window, "Gallery window should have opened without error")

	# Cleanup
	if gallery_window and is_instance_valid(gallery_window):
		gallery_window.queue_free()
	DirAccess.remove_absolute(temp_dir + "/assets/foregrounds/test_char.png")
	DirAccess.remove_absolute(temp_dir + "/assets/foregrounds")
	DirAccess.remove_absolute(temp_dir + "/assets")
	DirAccess.remove_absolute(temp_dir)


# --- Helper to create a temp gallery with known images ---

func _make_gallery_env(foregrounds: Array = [], backgrounds: Array = [], manifest_content: String = "") -> Dictionary:
	var temp_dir = ProjectSettings.globalize_path("user://test_blink_gallery_border")
	DirAccess.make_dir_recursive_absolute(temp_dir + "/assets/foregrounds")
	DirAccess.make_dir_recursive_absolute(temp_dir + "/assets/backgrounds")

	var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color.BLUE)

	for fname in foregrounds:
		img.save_png(temp_dir + "/assets/foregrounds/" + fname)
	for fname in backgrounds:
		img.save_png(temp_dir + "/assets/backgrounds/" + fname)

	if manifest_content != "":
		var f = FileAccess.open(temp_dir + "/assets/foregrounds/blink_manifest.yaml", FileAccess.WRITE)
		f.store_string(manifest_content)
		f.close()

	return {"temp_dir": temp_dir}


func _open_gallery_and_get_grid(tab, parent_window: Window) -> GridContainer:
	tab._gallery_btn.emit_signal("pressed")
	await get_tree().process_frame
	await get_tree().process_frame
	var gallery_window: Window = null
	for child in parent_window.get_children():
		if child is Window and child.title == "Choisir les images sources":
			gallery_window = child
			break
	if gallery_window == null:
		return null
	# Find the GridContainer inside the gallery
	var scroll = gallery_window.get_child(0).get_child(0).get_child(0) # margin > vbox > scroll
	return scroll.get_child(0) as GridContainer


func _cleanup_gallery_env(temp_dir: String, parent_window: Window) -> void:
	for child in parent_window.get_children():
		if child is Window and child.title == "Choisir les images sources":
			child.queue_free()
	# Remove all files in temp dirs
	for subdir in ["assets/foregrounds", "assets/backgrounds"]:
		var dir = DirAccess.open(temp_dir + "/" + subdir)
		if dir:
			dir.list_dir_begin()
			var fname = dir.get_next()
			while fname != "":
				if not dir.current_is_dir():
					DirAccess.remove_absolute(temp_dir + "/" + subdir + "/" + fname)
				fname = dir.get_next()
			dir.list_dir_end()
		DirAccess.remove_absolute(temp_dir + "/" + subdir)
	DirAccess.remove_absolute(temp_dir + "/assets")
	DirAccess.remove_absolute(temp_dir)


func test_gallery_foreground_without_blink_has_red_border() -> void:
	var env = _make_gallery_env(["hero.png"])
	var d = _make_tab()
	var tab: BlinkTab = d["tab"]
	tab.setup(env["temp_dir"], true)
	var grid = await _open_gallery_and_get_grid(tab, d["parent_window"])
	assert_not_null(grid)
	assert_eq(grid.get_child_count(), 1)
	var panel: PanelContainer = grid.get_child(0)
	var style = panel.get_theme_stylebox("panel") as StyleBoxFlat
	assert_not_null(style, "Should have a custom style")
	assert_almost_eq(style.border_color.r, 0.9, 0.1, "Red border")
	assert_almost_eq(style.border_color.g, 0.2, 0.1, "Red border")
	_cleanup_gallery_env(env["temp_dir"], d["parent_window"])


func test_gallery_foreground_with_blink_has_green_border() -> void:
	var manifest = "blinks:\n  hero.png: hero_blink.png\n"
	var env = _make_gallery_env(["hero.png", "hero_blink.png"], [], manifest)
	var d = _make_tab()
	var tab: BlinkTab = d["tab"]
	tab.setup(env["temp_dir"], true)
	var grid = await _open_gallery_and_get_grid(tab, d["parent_window"])
	assert_not_null(grid)
	# Find the hero.png panel (not hero_blink.png)
	var hero_panel: PanelContainer = null
	for child in grid.get_children():
		var cb = child.get_child(0).get_child(0) as CheckBox
		if cb.text == "hero.png":
			hero_panel = child
			break
	assert_not_null(hero_panel)
	var style = hero_panel.get_theme_stylebox("panel") as StyleBoxFlat
	assert_not_null(style)
	assert_almost_eq(style.border_color.g, 0.8, 0.1, "Green border")
	_cleanup_gallery_env(env["temp_dir"], d["parent_window"])


func test_gallery_blink_file_is_semi_transparent() -> void:
	var env = _make_gallery_env(["hero.png", "hero_blink.png"])
	var d = _make_tab()
	var tab: BlinkTab = d["tab"]
	tab.setup(env["temp_dir"], true)
	var grid = await _open_gallery_and_get_grid(tab, d["parent_window"])
	assert_not_null(grid)
	var blink_panel: PanelContainer = null
	for child in grid.get_children():
		var cb = child.get_child(0).get_child(0) as CheckBox
		if cb.text == "hero_blink.png":
			blink_panel = child
			break
	assert_not_null(blink_panel)
	assert_almost_eq(blink_panel.modulate.a, 0.4, 0.05, "Blink file should be semi-transparent")
	_cleanup_gallery_env(env["temp_dir"], d["parent_window"])


func test_gallery_background_is_semi_transparent() -> void:
	var env = _make_gallery_env([], ["sky.png"])
	var d = _make_tab()
	var tab: BlinkTab = d["tab"]
	tab.setup(env["temp_dir"], true)
	var grid = await _open_gallery_and_get_grid(tab, d["parent_window"])
	assert_not_null(grid)
	assert_eq(grid.get_child_count(), 1)
	var panel: PanelContainer = grid.get_child(0)
	assert_almost_eq(panel.modulate.a, 0.4, 0.05, "Background should be semi-transparent")
	_cleanup_gallery_env(env["temp_dir"], d["parent_window"])
