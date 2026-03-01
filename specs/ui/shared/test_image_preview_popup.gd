extends GutTest

## Tests pour ImagePreviewPopup — overlay plein écran de prévisualisation d'image

const ImagePreviewPopup = preload("res://src/ui/shared/image_preview_popup.gd")

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
