extends GutTest

var GraphReloadScript

func before_each():
	GraphReloadScript = load("res://src/views/graph_reload.gd")

func test_needs_reload_default():
	var helper = GraphReloadScript
	assert_false(helper.needs_reload())

func test_set_needs_reload():
	var helper = GraphReloadScript
	helper.set_needs_reload(true)
	assert_true(helper.needs_reload())
	helper.set_needs_reload(false)
	assert_false(helper.needs_reload())
