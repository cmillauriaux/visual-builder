extends GutTest

# Tests pour l'adaptation résolution et letterboxing 16:9

var SequenceVisualEditor = load("res://src/ui/sequence/sequence_visual_editor.gd")
var Sequence = load("res://src/models/sequence.gd")
var MainScript = load("res://src/main.gd")

var _editor: Control = null
var _sequence = null

func before_each():
	_editor = Control.new()
	_editor.set_script(SequenceVisualEditor)
	_editor.size = Vector2(960, 540)
	add_child_autofree(_editor)
	_sequence = Sequence.new()
	_sequence.seq_name = "Test Sequence"

# --- Auto-fit tests ---

func test_auto_fit_exact_ratio():
	# 960x540 = exactly half of 1920x1080, same aspect ratio
	_editor.size = Vector2(960, 540)
	var result = _editor.compute_auto_fit()
	assert_almost_eq(result["zoom"], 0.5, 0.001)
	assert_almost_eq(result["pan"].x, 0.0, 1.0)
	assert_almost_eq(result["pan"].y, 0.0, 1.0)

func test_auto_fit_wider_window():
	# Window is wider than 16:9 → horizontal letterbox (centered, pan.x > 0)
	_editor.size = Vector2(1920, 540)
	var result = _editor.compute_auto_fit()
	assert_almost_eq(result["zoom"], 0.5, 0.001)
	assert_true(result["pan"].x > 0.0, "Should have positive horizontal offset for centering")
	assert_almost_eq(result["pan"].y, 0.0, 1.0)

func test_auto_fit_taller_window():
	# Window is taller than 16:9 → vertical letterbox (centered, pan.y > 0)
	_editor.size = Vector2(960, 1080)
	var result = _editor.compute_auto_fit()
	assert_almost_eq(result["zoom"], 0.5, 0.001)
	assert_almost_eq(result["pan"].x, 0.0, 1.0)
	assert_true(result["pan"].y > 0.0, "Should have positive vertical offset for centering")

func test_auto_fit_square():
	# 1080x1080 → limited by width (1080/1920 ≈ 0.5625)
	_editor.size = Vector2(1080, 1080)
	var result = _editor.compute_auto_fit()
	var expected_zoom = 1080.0 / 1920.0  # ≈ 0.5625
	assert_almost_eq(result["zoom"], expected_zoom, 0.001)

func test_auto_fit_zero_size():
	# Zero size should not crash and return safe defaults
	_editor.size = Vector2(0, 0)
	var result = _editor.compute_auto_fit()
	assert_not_null(result)
	assert_true(result.has("zoom"))
	assert_true(result.has("pan"))

func test_auto_fit_disabled_after_manual_zoom():
	_editor.load_sequence(_sequence)
	assert_true(_editor._auto_fit_enabled, "Auto-fit should be enabled initially")
	# Simulate manual zoom
	_editor._set_zoom(2.0)
	assert_false(_editor._auto_fit_enabled, "Auto-fit should be disabled after manual zoom")

func test_reset_view_re_enables_auto_fit():
	_editor.load_sequence(_sequence)
	_editor._set_zoom(2.0)
	assert_false(_editor._auto_fit_enabled)
	_editor.reset_view()
	assert_true(_editor._auto_fit_enabled, "Auto-fit should be re-enabled after reset_view()")

# --- Letterbox and overlay container tests ---

func test_letterbox_bg_exists():
	var letterbox = _editor.get_node_or_null("LetterboxBackground")
	assert_not_null(letterbox, "LetterboxBackground should exist")
	assert_true(letterbox is ColorRect, "LetterboxBackground should be a ColorRect")

func test_letterbox_bg_is_black():
	var letterbox = _editor.get_node_or_null("LetterboxBackground")
	assert_eq(letterbox.color, Color(0, 0, 0, 1), "LetterboxBackground should be black")

func test_overlay_container_exists():
	assert_not_null(_editor._overlay_container, "OverlayContainer should exist")
	assert_true(_editor._overlay_container.is_inside_tree(), "OverlayContainer should be in the tree")

func test_overlay_container_matches_canvas_rect():
	_editor.size = Vector2(960, 540)
	_editor.apply_auto_fit()
	var canvas_rect = _editor.get_canvas_rect()
	assert_almost_eq(_editor._overlay_container.position.x, canvas_rect.position.x, 1.0)
	assert_almost_eq(_editor._overlay_container.position.y, canvas_rect.position.y, 1.0)
	assert_almost_eq(_editor._overlay_container.size.x, canvas_rect.size.x, 1.0)
	assert_almost_eq(_editor._overlay_container.size.y, canvas_rect.size.y, 1.0)

# --- Node hierarchy tests ---

func test_node_hierarchy_order():
	# LetterboxBackground should be before Canvas, Canvas before OverlayContainer
	var letterbox = _editor.get_node_or_null("LetterboxBackground")
	var canvas = _editor.get_node_or_null("Canvas")
	var overlay = _editor.get_node_or_null("OverlayContainer")
	assert_not_null(letterbox)
	assert_not_null(canvas)
	assert_not_null(overlay)
	assert_true(letterbox.get_index() < canvas.get_index(), "LetterboxBackground should be before Canvas")
	assert_true(canvas.get_index() < overlay.get_index(), "Canvas should be before OverlayContainer")

func test_load_sequence_reactivates_auto_fit():
	_editor._set_zoom(2.0)
	assert_false(_editor._auto_fit_enabled)
	_editor.load_sequence(_sequence)
	assert_true(_editor._auto_fit_enabled, "load_sequence should reactivate auto_fit")

# --- Play fullscreen tests ---

func test_enter_fullscreen_creates_layer():
	var main_ctrl = Control.new()
	main_ctrl.set_script(MainScript)
	add_child_autofree(main_ctrl)
	# Wait for _ready to complete
	await get_tree().process_frame
	main_ctrl._play_ctrl._enter_play_fullscreen()
	assert_not_null(main_ctrl._play_ctrl._fullscreen_layer, "Fullscreen layer should be created")
	assert_true(main_ctrl._play_ctrl._fullscreen_layer.is_inside_tree(), "Fullscreen layer should be in the tree")
	main_ctrl._play_ctrl._exit_play_fullscreen()

func test_visual_editor_reparented_in_fullscreen():
	var main_ctrl = Control.new()
	main_ctrl.set_script(MainScript)
	add_child_autofree(main_ctrl)
	await get_tree().process_frame
	var original_parent = main_ctrl._visual_editor.get_parent()
	main_ctrl._play_ctrl._enter_play_fullscreen()
	assert_eq(main_ctrl._visual_editor.get_parent(), main_ctrl._play_ctrl._fullscreen_layer, "Visual editor should be child of fullscreen layer")
	main_ctrl._play_ctrl._exit_play_fullscreen()

func test_exit_fullscreen_restores_hierarchy():
	var main_ctrl = Control.new()
	main_ctrl.set_script(MainScript)
	add_child_autofree(main_ctrl)
	await get_tree().process_frame
	var original_parent = main_ctrl._visual_editor.get_parent()
	main_ctrl._play_ctrl._enter_play_fullscreen()
	main_ctrl._play_ctrl._exit_play_fullscreen()
	assert_eq(main_ctrl._visual_editor.get_parent(), main_ctrl._sequence_content, "Visual editor should be restored to left_panel")

func test_stop_button_visible_in_fullscreen():
	var main_ctrl = Control.new()
	main_ctrl.set_script(MainScript)
	add_child_autofree(main_ctrl)
	await get_tree().process_frame
	main_ctrl._play_ctrl._enter_play_fullscreen()
	var stop_btn = main_ctrl._play_ctrl._fullscreen_layer.get_node_or_null("FullscreenStopButton")
	assert_not_null(stop_btn, "Stop button should exist in fullscreen layer")
	assert_true(stop_btn.visible, "Stop button should be visible")
	main_ctrl._play_ctrl._exit_play_fullscreen()

func test_editor_ui_hidden_in_fullscreen():
	var main_ctrl = Control.new()
	main_ctrl.set_script(MainScript)
	add_child_autofree(main_ctrl)
	await get_tree().process_frame
	assert_true(main_ctrl._vbox.visible, "Editor UI should be visible initially")
	main_ctrl._play_ctrl._enter_play_fullscreen()
	assert_false(main_ctrl._vbox.visible, "Editor UI should be hidden in fullscreen")
	main_ctrl._play_ctrl._exit_play_fullscreen()
	assert_true(main_ctrl._vbox.visible, "Editor UI should be restored after fullscreen")

func test_fullscreen_layer_is_black():
	var main_ctrl = Control.new()
	main_ctrl.set_script(MainScript)
	add_child_autofree(main_ctrl)
	await get_tree().process_frame
	main_ctrl._play_ctrl._enter_play_fullscreen()
	assert_true(main_ctrl._play_ctrl._fullscreen_layer is ColorRect, "Fullscreen layer should be a ColorRect")
	assert_eq(main_ctrl._play_ctrl._fullscreen_layer.color, Color(0, 0, 0, 1), "Fullscreen layer should be black")
	main_ctrl._play_ctrl._exit_play_fullscreen()

# --- UI Controller fullscreen tests (play overlay) ---

func test_ui_ctrl_enter_fullscreen_adds_play_overlay():
	var main_ctrl = Control.new()
	main_ctrl.set_script(MainScript)
	add_child_autofree(main_ctrl)
	await get_tree().process_frame
	assert_false(main_ctrl._play_overlay.visible, "Play overlay should be hidden initially")
	main_ctrl._ui_ctrl.enter_fullscreen()
	assert_eq(main_ctrl._play_overlay.get_parent(), main_ctrl._visual_editor._overlay_container, "Play overlay should be in overlay container")
	assert_true(main_ctrl._play_overlay.visible, "Play overlay should be visible in fullscreen")
	main_ctrl._ui_ctrl.exit_fullscreen()

func test_ui_ctrl_enter_fullscreen_recomputes_canvas_and_overlay_in_preview_mode():
	var main_ctrl = Control.new()
	main_ctrl.set_script(MainScript)
	add_child_autofree(main_ctrl)
	await get_tree().process_frame
	main_ctrl._visual_editor.size = Vector2(640, 360)
	main_ctrl._visual_editor.apply_auto_fit()
	main_ctrl._visual_editor._is_preview_mode = true

	main_ctrl._ui_ctrl.enter_fullscreen()

	var viewport_size = main_ctrl.get_viewport().get_visible_rect().size
	var canvas_rect = main_ctrl._visual_editor.get_canvas_rect()
	assert_almost_eq(main_ctrl._visual_editor.size.x, viewport_size.x, 1.0)
	assert_almost_eq(main_ctrl._visual_editor.size.y, viewport_size.y, 1.0)
	assert_almost_eq(main_ctrl._visual_editor._overlay_container.position.x, canvas_rect.position.x, 1.0)
	assert_almost_eq(main_ctrl._visual_editor._overlay_container.position.y, canvas_rect.position.y, 1.0)
	assert_almost_eq(main_ctrl._visual_editor._overlay_container.size.x, canvas_rect.size.x, 1.0)
	assert_almost_eq(main_ctrl._visual_editor._overlay_container.size.y, canvas_rect.size.y, 1.0)

	main_ctrl._ui_ctrl.exit_fullscreen()

func test_ui_ctrl_exit_fullscreen_removes_play_overlay():
	var main_ctrl = Control.new()
	main_ctrl.set_script(MainScript)
	add_child_autofree(main_ctrl)
	await get_tree().process_frame
	main_ctrl._ui_ctrl.enter_fullscreen()
	assert_true(main_ctrl._play_overlay.visible)
	main_ctrl._ui_ctrl.exit_fullscreen()
	assert_false(main_ctrl._play_overlay.visible, "Play overlay should be hidden after exit")
	assert_null(main_ctrl._play_overlay.get_parent(), "Play overlay should be removed from tree")
