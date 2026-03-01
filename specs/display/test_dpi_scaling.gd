extends GutTest

# Tests pour le scaling DPI — spec 027


func test_stretch_mode_is_canvas_items():
	var mode = ProjectSettings.get_setting("display/window/stretch/mode")
	assert_eq(mode, "canvas_items", "Stretch mode should be canvas_items for DPI scaling")


func test_stretch_aspect_is_expand():
	var aspect = ProjectSettings.get_setting("display/window/stretch/aspect")
	assert_eq(aspect, "expand", "Stretch aspect should be expand for flexible aspect ratios")


func test_viewport_width_is_1920():
	var w = ProjectSettings.get_setting("display/window/size/viewport_width")
	assert_eq(w, 1920)


func test_viewport_height_is_1080():
	var h = ProjectSettings.get_setting("display/window/size/viewport_height")
	assert_eq(h, 1080)
