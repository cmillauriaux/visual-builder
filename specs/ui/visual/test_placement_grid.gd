extends GutTest

var PlacementGridScript

var grid

func before_each():
	PlacementGridScript = load("res://src/ui/visual/placement_grid.gd")
	grid = PlacementGridScript.new()

# --- Grid dimensions ---

func test_default_grid_divisions():
	assert_eq(grid.divisions, 12, "Default grid should be 12x12")

func test_grid_line_count_horizontal():
	var lines = grid.get_horizontal_lines(Vector2(1920, 1080))
	assert_eq(lines.size(), 13)

# --- Snap points ---

func test_snap_points_count():
	var points = grid.get_snap_points(Vector2(1920, 1080))
	assert_eq(points.size(), 313)

func test_snap_points_include_center():
	var points = grid.get_snap_points(Vector2(1920, 1080))
	assert_has(points, Vector2(0.5, 0.5), "Center intersection")

# --- Snap function ---

func test_snap_to_nearest_corner():
	var snapped = grid.snap_position(Vector2(0.01, 0.02), Vector2(1920, 1080))
	assert_almost_eq(snapped.x, 0.0, 0.001)
	assert_almost_eq(snapped.y, 0.0, 0.001)
