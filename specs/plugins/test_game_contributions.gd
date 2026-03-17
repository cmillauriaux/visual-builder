extends GutTest

const GameContributions = preload("res://src/plugins/game_contributions.gd")


func test_toolbar_button_default_label():
	var btn = GameContributions.GameToolbarButton.new()
	assert_eq(btn.label, "")


func test_toolbar_button_default_icon_null():
	var btn = GameContributions.GameToolbarButton.new()
	assert_null(btn.icon)


func test_toolbar_button_fields_settable():
	var btn = GameContributions.GameToolbarButton.new()
	btn.label = "Test"
	btn.callback = func(_ctx): pass
	assert_eq(btn.label, "Test")
	assert_true(btn.callback.is_valid())


func test_overlay_panel_default_position():
	var panel = GameContributions.GameOverlayPanelDef.new()
	assert_eq(panel.position, "")


func test_overlay_panel_fields_settable():
	var panel = GameContributions.GameOverlayPanelDef.new()
	panel.position = "right"
	panel.create_panel = func(_ctx): return Control.new()
	assert_eq(panel.position, "right")
	assert_true(panel.create_panel.is_valid())


func test_overlay_panel_create_returns_control():
	var panel = GameContributions.GameOverlayPanelDef.new()
	panel.create_panel = func(_ctx): return Label.new()
	var ctrl = panel.create_panel.call(null)
	assert_not_null(ctrl)
	assert_true(ctrl is Label)
	ctrl.queue_free()


func test_options_control_create_returns_control():
	var def = GameContributions.GameOptionsControlDef.new()
	def.create_control = func(_settings): return CheckButton.new()
	var ctrl = def.create_control.call(null)
	assert_not_null(ctrl)
	assert_true(ctrl is CheckButton)
	ctrl.queue_free()
