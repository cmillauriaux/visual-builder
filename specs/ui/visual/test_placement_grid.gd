extends GutTest

const PlacementGrid = preload("res://src/ui/visual/placement_grid.gd")

var grid: PlacementGrid

func before_each():
	grid = PlacementGrid.new()

# --- Grid dimensions ---

func test_default_grid_divisions():
	assert_eq(grid.divisions, 12, "Default grid should be 12x12")

func test_grid_line_count_horizontal():
	# 12 divisions = 13 horizontal lines (including edges)
	var lines = grid.get_horizontal_lines(Vector2(1920, 1080))
	assert_eq(lines.size(), 13)

func test_grid_line_count_vertical():
	var lines = grid.get_vertical_lines(Vector2(1920, 1080))
	assert_eq(lines.size(), 13)

func test_grid_first_horizontal_line_at_zero():
	var lines = grid.get_horizontal_lines(Vector2(1920, 1080))
	assert_eq(lines[0], 0.0)

func test_grid_last_horizontal_line_at_height():
	var lines = grid.get_horizontal_lines(Vector2(1920, 1080))
	assert_eq(lines[12], 1080.0)

func test_grid_first_vertical_line_at_zero():
	var lines = grid.get_vertical_lines(Vector2(1920, 1080))
	assert_eq(lines[0], 0.0)

func test_grid_last_vertical_line_at_width():
	var lines = grid.get_vertical_lines(Vector2(1920, 1080))
	assert_eq(lines[12], 1920.0)

func test_grid_horizontal_line_spacing():
	var lines = grid.get_horizontal_lines(Vector2(1920, 1080))
	var spacing = lines[1] - lines[0]
	assert_almost_eq(spacing, 1080.0 / 12.0, 0.01)

func test_grid_vertical_line_spacing():
	var lines = grid.get_vertical_lines(Vector2(1920, 1080))
	var spacing = lines[1] - lines[0]
	assert_almost_eq(spacing, 1920.0 / 12.0, 0.01)

# --- Snap points ---

func test_snap_points_count():
	# Intersections: 13x13 = 169, Cell centers: 12x12 = 144, Total: 313
	var points = grid.get_snap_points(Vector2(1920, 1080))
	assert_eq(points.size(), 313)

func test_snap_points_include_corners():
	var points = grid.get_snap_points(Vector2(1920, 1080))
	# Points are in normalized coordinates (0-1 range)
	assert_has(points, Vector2(0.0, 0.0), "Top-left corner")
	assert_has(points, Vector2(1.0, 0.0), "Top-right corner")
	assert_has(points, Vector2(0.0, 1.0), "Bottom-left corner")
	assert_has(points, Vector2(1.0, 1.0), "Bottom-right corner")

func test_snap_points_include_center():
	var points = grid.get_snap_points(Vector2(1920, 1080))
	assert_has(points, Vector2(0.5, 0.5), "Center intersection")

func test_snap_points_include_cell_center():
	var points = grid.get_snap_points(Vector2(1920, 1080))
	# First cell center: (1/24, 1/24) = midpoint of first cell
	var first_cell_center = Vector2(1.0 / 24.0, 1.0 / 24.0)
	var found = false
	for p in points:
		if p.distance_to(first_cell_center) < 0.001:
			found = true
			break
	assert_true(found, "Should include first cell center")

# --- Snap function ---

func test_snap_to_nearest_corner():
	# Position very close to top-left corner
	var snapped = grid.snap_position(Vector2(0.01, 0.02), Vector2(1920, 1080))
	assert_almost_eq(snapped.x, 0.0, 0.001)
	assert_almost_eq(snapped.y, 0.0, 0.001)

func test_snap_to_nearest_intersection():
	# Position close to (1/12, 1/12) intersection
	var target = Vector2(1.0 / 12.0, 1.0 / 12.0)
	var snapped = grid.snap_position(Vector2(target.x + 0.005, target.y - 0.005), Vector2(1920, 1080))
	assert_almost_eq(snapped.x, target.x, 0.001)
	assert_almost_eq(snapped.y, target.y, 0.001)

func test_snap_to_nearest_cell_center():
	# Position very close to first cell center (1/24, 1/24)
	var cell_center = Vector2(1.0 / 24.0, 1.0 / 24.0)
	var snapped = grid.snap_position(Vector2(cell_center.x + 0.001, cell_center.y + 0.001), Vector2(1920, 1080))
	assert_almost_eq(snapped.x, cell_center.x, 0.002)
	assert_almost_eq(snapped.y, cell_center.y, 0.002)

func test_snap_preserves_exact_grid_position():
	# Position already on a grid point should not move
	var exact = Vector2(0.5, 0.5)
	var snapped = grid.snap_position(exact, Vector2(1920, 1080))
	assert_almost_eq(snapped.x, 0.5, 0.001)
	assert_almost_eq(snapped.y, 0.5, 0.001)

func test_snap_clamps_to_valid_range():
	# Position outside background bounds should snap to edge
	var snapped = grid.snap_position(Vector2(-0.1, 1.2), Vector2(1920, 1080))
	assert_true(snapped.x >= 0.0 and snapped.x <= 1.0, "X should be clamped")
	assert_true(snapped.y >= 0.0 and snapped.y <= 1.0, "Y should be clamped")

func test_snap_with_different_bg_size():
	# Snap points are in normalized coords, so bg_size shouldn't change results
	var snapped_a = grid.snap_position(Vector2(0.5, 0.5), Vector2(1920, 1080))
	var snapped_b = grid.snap_position(Vector2(0.5, 0.5), Vector2(800, 600))
	assert_almost_eq(snapped_a.x, snapped_b.x, 0.001)
	assert_almost_eq(snapped_a.y, snapped_b.y, 0.001)
