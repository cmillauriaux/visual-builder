extends GutTest

var ForegroundClipboardScript
var ForegroundScript

var clipboard

func before_each():
	ForegroundClipboardScript = load("res://src/ui/visual/foreground_clipboard.gd")
	ForegroundScript = load("res://src/models/foreground.gd")
	clipboard = ForegroundClipboardScript.new()

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

# --- Paste ---

func test_paste_applies_scale():
	var source = _make_fg(2.0)
	var target = _make_fg(1.0)
	clipboard.copy_from(source)
	clipboard.paste_to(target)
	assert_eq(target.scale, 2.0)

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
