extends GutTest

const ForegroundClipboard = preload("res://src/ui/visual/foreground_clipboard.gd")
const ForegroundScript = preload("res://src/models/foreground.gd")

var clipboard: ForegroundClipboard

func before_each():
	clipboard = ForegroundClipboard.new()

# --- Initial state ---

func test_initially_empty():
	assert_false(clipboard.has_data())

# --- Copy ---

func test_copy_stores_data():
	var fg = _make_fg()
	clipboard.copy_from(fg)
	assert_true(clipboard.has_data())

func test_copy_stores_scale():
	var fg = _make_fg(2.5)
	clipboard.copy_from(fg)
	assert_eq(clipboard.data.scale, 2.5)

func test_copy_stores_anchor_bg():
	var fg = _make_fg()
	fg.anchor_bg = Vector2(0.3, 0.7)
	clipboard.copy_from(fg)
	assert_eq(clipboard.data.anchor_bg, Vector2(0.3, 0.7))

func test_copy_stores_anchor_fg():
	var fg = _make_fg()
	fg.anchor_fg = Vector2(0.1, 0.9)
	clipboard.copy_from(fg)
	assert_eq(clipboard.data.anchor_fg, Vector2(0.1, 0.9))

func test_copy_stores_flip_h():
	var fg = _make_fg()
	fg.flip_h = true
	clipboard.copy_from(fg)
	assert_true(clipboard.data.flip_h)

func test_copy_stores_flip_v():
	var fg = _make_fg()
	fg.flip_v = true
	clipboard.copy_from(fg)
	assert_true(clipboard.data.flip_v)

func test_copy_overwrites_previous():
	var fg1 = _make_fg(1.0)
	var fg2 = _make_fg(3.0)
	clipboard.copy_from(fg1)
	clipboard.copy_from(fg2)
	assert_eq(clipboard.data.scale, 3.0)

# --- Paste ---

func test_paste_applies_scale():
	var source = _make_fg(2.0)
	var target = _make_fg(1.0)
	clipboard.copy_from(source)
	clipboard.paste_to(target)
	assert_eq(target.scale, 2.0)

func test_paste_applies_anchor_bg():
	var source = _make_fg()
	source.anchor_bg = Vector2(0.2, 0.8)
	var target = _make_fg()
	clipboard.copy_from(source)
	clipboard.paste_to(target)
	assert_eq(target.anchor_bg, Vector2(0.2, 0.8))

func test_paste_applies_anchor_fg():
	var source = _make_fg()
	source.anchor_fg = Vector2(0.4, 0.6)
	var target = _make_fg()
	clipboard.copy_from(source)
	clipboard.paste_to(target)
	assert_eq(target.anchor_fg, Vector2(0.4, 0.6))

func test_paste_applies_flip_h():
	var source = _make_fg()
	source.flip_h = true
	var target = _make_fg()
	clipboard.copy_from(source)
	clipboard.paste_to(target)
	assert_true(target.flip_h)

func test_paste_applies_flip_v():
	var source = _make_fg()
	source.flip_v = true
	var target = _make_fg()
	clipboard.copy_from(source)
	clipboard.paste_to(target)
	assert_true(target.flip_v)

# --- Paste does NOT modify unrelated properties ---

func test_paste_preserves_uuid():
	var source = _make_fg()
	var target = _make_fg()
	var original_uuid = target.uuid
	clipboard.copy_from(source)
	clipboard.paste_to(target)
	assert_eq(target.uuid, original_uuid)

func test_paste_preserves_fg_name():
	var source = _make_fg()
	source.fg_name = "Source"
	var target = _make_fg()
	target.fg_name = "Target"
	clipboard.copy_from(source)
	clipboard.paste_to(target)
	assert_eq(target.fg_name, "Target")

func test_paste_preserves_image():
	var source = _make_fg()
	source.image = "source.png"
	var target = _make_fg()
	target.image = "target.png"
	clipboard.copy_from(source)
	clipboard.paste_to(target)
	assert_eq(target.image, "target.png")

func test_paste_preserves_z_order():
	var source = _make_fg()
	source.z_order = 5
	var target = _make_fg()
	target.z_order = 10
	clipboard.copy_from(source)
	clipboard.paste_to(target)
	assert_eq(target.z_order, 10)

func test_paste_preserves_opacity():
	var source = _make_fg()
	source.opacity = 0.3
	var target = _make_fg()
	target.opacity = 0.8
	clipboard.copy_from(source)
	clipboard.paste_to(target)
	assert_eq(target.opacity, 0.8)

func test_paste_preserves_transition_type():
	var source = _make_fg()
	source.transition_type = "fade"
	var target = _make_fg()
	target.transition_type = "fade"
	clipboard.copy_from(source)
	clipboard.paste_to(target)
	assert_eq(target.transition_type, "fade")

func test_paste_preserves_transition_duration():
	var source = _make_fg()
	source.transition_duration = 1.0
	var target = _make_fg()
	target.transition_duration = 3.0
	clipboard.copy_from(source)
	clipboard.paste_to(target)
	assert_eq(target.transition_duration, 3.0)

# --- Paste returns false when empty ---

func test_paste_returns_false_when_empty():
	var target = _make_fg()
	var result = clipboard.paste_to(target)
	assert_false(result)

func test_paste_returns_true_when_has_data():
	var source = _make_fg()
	var target = _make_fg()
	clipboard.copy_from(source)
	var result = clipboard.paste_to(target)
	assert_true(result)

# --- Helper ---

func _make_fg(s: float = 1.0):
	var fg = ForegroundScript.new()
	fg.scale = s
	return fg
