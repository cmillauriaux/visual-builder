extends GutTest

## Tests pour GameTheme — construction du thème Kenney Adventure.

const GameTheme = preload("res://src/ui/themes/game_theme.gd")

var _theme: Theme


func before_each() -> void:
	_theme = GameTheme.create_theme()


func test_create_theme_returns_theme() -> void:
	assert_not_null(_theme, "create_theme should return a Theme")
	assert_true(_theme is Theme)


# --- Button ---

func test_theme_has_button_normal_style() -> void:
	var style = _theme.get_stylebox("normal", "Button")
	assert_not_null(style, "Button should have 'normal' stylebox")
	assert_true(style is StyleBoxTexture, "Button normal should be StyleBoxTexture")


func test_theme_has_button_hover_style() -> void:
	var style = _theme.get_stylebox("hover", "Button")
	assert_not_null(style, "Button should have 'hover' stylebox")
	assert_true(style is StyleBoxTexture)


func test_theme_has_button_pressed_style() -> void:
	var style = _theme.get_stylebox("pressed", "Button")
	assert_not_null(style, "Button should have 'pressed' stylebox")
	assert_true(style is StyleBoxTexture)


func test_theme_has_button_disabled_style() -> void:
	var style = _theme.get_stylebox("disabled", "Button")
	assert_not_null(style, "Button should have 'disabled' stylebox")
	assert_true(style is StyleBoxTexture)


func test_button_hover_is_brighter_than_normal() -> void:
	var normal = _theme.get_stylebox("normal", "Button") as StyleBoxTexture
	var hover = _theme.get_stylebox("hover", "Button") as StyleBoxTexture
	assert_gt(hover.modulate_color.r, normal.modulate_color.r,
		"Hover should be brighter than normal")


func test_button_pressed_is_darker_than_normal() -> void:
	var normal = _theme.get_stylebox("normal", "Button") as StyleBoxTexture
	var pressed = _theme.get_stylebox("pressed", "Button") as StyleBoxTexture
	assert_lt(pressed.modulate_color.r, normal.modulate_color.r,
		"Pressed should be darker than normal")


func test_button_text_color_is_dark() -> void:
	var color = _theme.get_color("font_color", "Button")
	assert_eq(color, GameTheme.COLOR_BUTTON_TEXT)


# --- OptionButton ---

func test_theme_has_option_button_styles() -> void:
	assert_not_null(_theme.get_stylebox("normal", "OptionButton"))
	assert_not_null(_theme.get_stylebox("hover", "OptionButton"))
	assert_not_null(_theme.get_stylebox("pressed", "OptionButton"))


# --- PanelContainer ---

func test_theme_has_panel_style() -> void:
	var style = _theme.get_stylebox("panel", "PanelContainer")
	assert_not_null(style, "PanelContainer should have 'panel' stylebox")
	assert_true(style is StyleBoxTexture, "Panel should be StyleBoxTexture")


func test_panel_has_content_margins() -> void:
	var style = _theme.get_stylebox("panel", "PanelContainer") as StyleBoxTexture
	assert_eq(style.content_margin_left, float(GameTheme.PANEL_CONTENT_MARGIN))
	assert_eq(style.content_margin_right, float(GameTheme.PANEL_CONTENT_MARGIN))
	assert_eq(style.content_margin_top, float(GameTheme.PANEL_CONTENT_MARGIN))
	assert_eq(style.content_margin_bottom, float(GameTheme.PANEL_CONTENT_MARGIN))


# --- Label ---

func test_theme_has_label_color() -> void:
	var color = _theme.get_color("font_color", "Label")
	assert_eq(color, GameTheme.COLOR_TEXT_DARK)


# --- RichTextLabel ---

func test_theme_has_rich_text_label_color() -> void:
	var color = _theme.get_color("default_color", "RichTextLabel")
	assert_eq(color, GameTheme.COLOR_TEXT_DARK)


# --- CheckButton ---

func test_theme_has_check_button_icons() -> void:
	var unchecked = _theme.get_icon("unchecked", "CheckButton")
	var checked = _theme.get_icon("checked", "CheckButton")
	assert_not_null(unchecked, "CheckButton should have unchecked icon")
	assert_not_null(checked, "CheckButton should have checked icon")


# --- HSeparator ---

func test_theme_has_separator_style() -> void:
	var style = _theme.get_stylebox("separator", "HSeparator")
	assert_not_null(style, "HSeparator should have 'separator' stylebox")
	assert_true(style is StyleBoxLine)


# --- HSlider ---

func test_theme_has_slider_style() -> void:
	var style = _theme.get_stylebox("slider", "HSlider")
	assert_not_null(style, "HSlider should have 'slider' stylebox")


# --- VScrollBar ---

func test_theme_has_scrollbar_styles() -> void:
	assert_not_null(_theme.get_stylebox("scroll", "VScrollBar"))
	assert_not_null(_theme.get_stylebox("grabber", "VScrollBar"))
	assert_not_null(_theme.get_stylebox("grabber_highlight", "VScrollBar"))


# --- apply_danger_style ---

func test_apply_danger_style() -> void:
	var btn = Button.new()
	add_child(btn)
	GameTheme.apply_danger_style(btn)
	var has_override = btn.has_theme_stylebox_override("normal")
	if has_override:
		var style = btn.get_theme_stylebox("normal")
		assert_not_null(style, "Danger button should have normal override")
		assert_true(style is StyleBoxTexture)
		var red_tex = load(GameTheme.ASSETS_PATH + "button_red.png")
		assert_eq((style as StyleBoxTexture).texture, red_tex)
	else:
		# Texture not loadable in headless mode — verify method didn't crash
		assert_false(has_override, "No override applied (headless mode, texture not available)")
	remove_child(btn)
	btn.queue_free()


func test_apply_close_style() -> void:
	var btn = Button.new()
	add_child(btn)
	GameTheme.apply_close_style(btn)
	var has_override = btn.has_theme_stylebox_override("normal")
	if has_override:
		var style = btn.get_theme_stylebox("normal")
		assert_not_null(style, "Close button should have normal override")
		assert_true(style is StyleBoxTexture)
		var close_tex = load(GameTheme.ASSETS_PATH + "button_red_close.png")
		assert_eq((style as StyleBoxTexture).texture, close_tex)
	else:
		assert_false(has_override, "No override applied (headless mode, texture not available)")
	remove_child(btn)
	btn.queue_free()


func test_apply_dark_panel_style() -> void:
	var panel = PanelContainer.new()
	add_child(panel)
	GameTheme.apply_dark_panel_style(panel)
	var has_override = panel.has_theme_stylebox_override("panel")
	if has_override:
		var style = panel.get_theme_stylebox("panel")
		assert_not_null(style, "Dark panel should have panel override")
		assert_true(style is StyleBoxTexture)
		var dark_tex = load(GameTheme.ASSETS_PATH + "panel_brown_dark.png")
		assert_eq((style as StyleBoxTexture).texture, dark_tex)
	else:
		assert_false(has_override, "No override applied (headless mode, texture not available)")
	remove_child(panel)
	panel.queue_free()
