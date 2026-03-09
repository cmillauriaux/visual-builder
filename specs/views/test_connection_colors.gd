extends GutTest

var ConnectionColorsScript

func before_each():
	ConnectionColorsScript = load("res://src/views/connection_colors.gd")

func test_get_color_for_type():
	var colors = ConnectionColorsScript
	assert_true(colors.get_color("chapter") is Color, "Chapter color should be a Color")
	assert_true(colors.get_color("scene") is Color, "Scene color should be a Color")
	assert_true(colors.get_color("sequence") is Color, "Sequence color should be a Color")
	assert_true(colors.get_color("condition") is Color, "Condition color should be a Color")
	assert_true(colors.get_color("ending") is Color, "Ending color should be a Color")

func test_get_color_unknown_type():
	var colors = ConnectionColorsScript
	var default_color = colors.get_color("unknown")
	assert_true(default_color is Color, "Unknown type should return a default Color")
	assert_eq(default_color, Color.WHITE, "Default color should be white")
