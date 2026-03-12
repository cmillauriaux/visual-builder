extends GutTest

## Tests pour ImagePreviewPopup — overlay plein écran de prévisualisation d'image

var ImagePreviewPopup = load("res://src/ui/shared/image_preview_popup.gd")

var _popup: Control

func before_each():
	_popup = Control.new()
	_popup.set_script(ImagePreviewPopup)
	add_child_autofree(_popup)

# --- Structure UI ---

func test_extends_control():
	assert_is(_popup, Control)

func test_initially_hidden():
	assert_false(_popup.visible)

func test_has_overlay():
	assert_not_null(_popup._overlay)
	assert_is(_popup._overlay, ColorRect)

func test_overlay_is_semi_transparent_black():
	var color = _popup._overlay.color
	assert_almost_eq(color.r, 0.0, 0.01)
	assert_almost_eq(color.g, 0.0, 0.01)
	assert_almost_eq(color.b, 0.0, 0.01)
	assert_almost_eq(color.a, 0.7, 0.01)

func test_has_texture_rect():
	assert_not_null(_popup._texture_rect)
	assert_is(_popup._texture_rect, TextureRect)

func test_texture_rect_stretch_mode():
	assert_eq(_popup._texture_rect.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_CENTERED)

func test_has_filename_label():
	assert_not_null(_popup._filename_label)
	assert_is(_popup._filename_label, Label)

func test_has_close_button():
	assert_not_null(_popup._close_btn)
	assert_is(_popup._close_btn, Button)

func test_close_button_text():
	assert_eq(_popup._close_btn.text, "✕")

# --- show_preview ---

func test_show_preview_makes_visible():
	var tex = ImageTexture.new()
	var img = Image.create(2, 2, false, Image.FORMAT_RGB8)
	tex = ImageTexture.create_from_image(img)
	_popup.show_preview(tex, "test.png")
	assert_true(_popup.visible)

func test_show_preview_sets_texture():
	var img = Image.create(2, 2, false, Image.FORMAT_RGB8)
	var tex = ImageTexture.create_from_image(img)
	_popup.show_preview(tex, "test.png")
	assert_eq(_popup._texture_rect.texture, tex)

func test_show_preview_sets_filename():
	var img = Image.create(2, 2, false, Image.FORMAT_RGB8)
	var tex = ImageTexture.create_from_image(img)
	_popup.show_preview(tex, "my_image.png")
	assert_eq(_popup._filename_label.text, "my_image.png")

func test_show_preview_null_texture_stays_hidden():
	_popup.show_preview(null, "test.png")
	assert_false(_popup.visible)

func test_show_preview_empty_filename():
	var img = Image.create(2, 2, false, Image.FORMAT_RGB8)
	var tex = ImageTexture.create_from_image(img)
	_popup.show_preview(tex, "")
	assert_true(_popup.visible)
	assert_eq(_popup._filename_label.text, "")

# --- Fermeture ---

func test_close_hides_popup():
	var img = Image.create(2, 2, false, Image.FORMAT_RGB8)
	var tex = ImageTexture.create_from_image(img)
	_popup.show_preview(tex, "test.png")
	_popup._close()
	assert_false(_popup.visible)

func test_close_clears_texture():
	var img = Image.create(2, 2, false, Image.FORMAT_RGB8)
	var tex = ImageTexture.create_from_image(img)
	_popup.show_preview(tex, "test.png")
	_popup._close()
	assert_null(_popup._texture_rect.texture)

# --- Navigation bar ---

func test_has_nav_bar():
	assert_not_null(_popup._nav_bar)
	assert_is(_popup._nav_bar, HBoxContainer)

func test_nav_bar_initially_hidden():
	assert_false(_popup._nav_bar.visible)

func test_has_prev_button():
	assert_not_null(_popup._prev_btn)
	assert_is(_popup._prev_btn, Button)
	assert_eq(_popup._prev_btn.text, "◀ Précédent")

func test_has_next_button():
	assert_not_null(_popup._next_btn)
	assert_is(_popup._next_btn, Button)
	assert_eq(_popup._next_btn.text, "Suivant ▶")

func test_has_counter_label():
	assert_not_null(_popup._counter_label)
	assert_is(_popup._counter_label, Label)

func test_has_regenerate_button():
	assert_not_null(_popup._regenerate_btn)
	assert_is(_popup._regenerate_btn, Button)
	assert_eq(_popup._regenerate_btn.text, "Regénérer")

func test_has_delete_button():
	assert_not_null(_popup._delete_btn)
	assert_is(_popup._delete_btn, Button)
	assert_eq(_popup._delete_btn.text, "Supprimer")

# --- show_collection ---

func _make_collection() -> Array:
	var items: Array = []
	for i in range(3):
		var img = Image.create(2, 2, false, Image.FORMAT_RGB8)
		var tex = ImageTexture.create_from_image(img)
		items.append({"texture": tex, "filename": "image_%d.png" % i, "index": i})
	return items

func test_show_collection_makes_visible():
	_popup.show_collection(_make_collection(), 0)
	assert_true(_popup.visible)

func test_show_collection_shows_nav_bar():
	_popup.show_collection(_make_collection(), 0)
	assert_true(_popup._nav_bar.visible)

func test_show_collection_displays_first_image():
	var items = _make_collection()
	_popup.show_collection(items, 0)
	assert_eq(_popup._texture_rect.texture, items[0]["texture"])
	assert_eq(_popup._filename_label.text, "image_0.png")

func test_show_collection_displays_counter():
	_popup.show_collection(_make_collection(), 0)
	assert_eq(_popup._counter_label.text, "1 / 3")

func test_show_collection_prev_disabled_at_start():
	_popup.show_collection(_make_collection(), 0)
	assert_true(_popup._prev_btn.disabled)

func test_show_collection_next_enabled_at_start():
	_popup.show_collection(_make_collection(), 0)
	assert_false(_popup._next_btn.disabled)

func test_show_collection_empty_does_nothing():
	_popup.show_collection([], 0)
	assert_false(_popup.visible)

func test_show_collection_start_index_clamped():
	var items = _make_collection()
	_popup.show_collection(items, 10)
	assert_eq(_popup._current_collection_index, 2)

# --- Navigation ---

func test_next_button_advances():
	var items = _make_collection()
	_popup.show_collection(items, 0)
	_popup._on_next_pressed()
	assert_eq(_popup._current_collection_index, 1)
	assert_eq(_popup._texture_rect.texture, items[1]["texture"])
	assert_eq(_popup._filename_label.text, "image_1.png")
	assert_eq(_popup._counter_label.text, "2 / 3")

func test_prev_button_goes_back():
	var items = _make_collection()
	_popup.show_collection(items, 1)
	_popup._on_prev_pressed()
	assert_eq(_popup._current_collection_index, 0)
	assert_eq(_popup._texture_rect.texture, items[0]["texture"])

func test_next_disabled_at_last():
	var items = _make_collection()
	_popup.show_collection(items, 2)
	assert_true(_popup._next_btn.disabled)
	assert_false(_popup._prev_btn.disabled)

func test_prev_does_not_go_below_zero():
	_popup.show_collection(_make_collection(), 0)
	_popup._on_prev_pressed()
	assert_eq(_popup._current_collection_index, 0)

func test_next_does_not_exceed_max():
	var items = _make_collection()
	_popup.show_collection(items, 2)
	_popup._on_next_pressed()
	assert_eq(_popup._current_collection_index, 2)

# --- Regenerate signal ---

func test_regenerate_emits_signal():
	var items = _make_collection()
	_popup.show_collection(items, 1)
	watch_signals(_popup)
	_popup._on_regenerate_pressed()
	assert_signal_emitted_with_parameters(_popup, "regenerate_requested", [1])

func test_regenerate_closes_popup():
	_popup.show_collection(_make_collection(), 0)
	_popup._on_regenerate_pressed()
	assert_false(_popup.visible)

# --- Delete signal ---

func test_delete_emits_signal():
	var items = _make_collection()
	_popup.show_collection(items, 1)
	watch_signals(_popup)
	_popup._on_delete_pressed()
	assert_signal_emitted_with_parameters(_popup, "delete_requested", [1])

func test_delete_removes_item_from_collection():
	var items = _make_collection()
	_popup.show_collection(items, 1)
	_popup._on_delete_pressed()
	assert_eq(_popup._collection_items.size(), 2)

func test_delete_shows_next_image():
	var items = _make_collection()
	_popup.show_collection(items, 0)
	_popup._on_delete_pressed()
	# Should now show what was index 1 (now at 0)
	assert_true(_popup.visible)
	assert_eq(_popup._filename_label.text, "image_1.png")

func test_delete_last_item_closes_popup():
	var img = Image.create(2, 2, false, Image.FORMAT_RGB8)
	var tex = ImageTexture.create_from_image(img)
	var items = [{"texture": tex, "filename": "only.png", "index": 0}]
	_popup.show_collection(items, 0)
	_popup._on_delete_pressed()
	assert_false(_popup.visible)

func test_delete_at_end_adjusts_index():
	var items = _make_collection()
	_popup.show_collection(items, 2)
	_popup._on_delete_pressed()
	# Should adjust to last available index (1)
	assert_eq(_popup._current_collection_index, 1)
	assert_true(_popup.visible)

# --- Single mode hides nav bar ---

func test_show_preview_hides_nav_bar():
	_popup.show_collection(_make_collection(), 0)
	assert_true(_popup._nav_bar.visible)
	var img = Image.create(2, 2, false, Image.FORMAT_RGB8)
	var tex = ImageTexture.create_from_image(img)
	_popup.show_preview(tex, "single.png")
	assert_false(_popup._nav_bar.visible)
