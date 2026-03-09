extends GutTest

## Tests d'intégration pour la grille, le snapping et le clipboard
## dans SequenceVisualEditor (spec 005).

var SequenceVisualEditor = load("res://src/ui/sequence/sequence_visual_editor.gd")
var Sequence = load("res://src/models/sequence.gd")
var Foreground = load("res://src/models/foreground.gd")

var _editor: Control = null
var _sequence = null

func before_each():
	_editor = Control.new()
	_editor.set_script(SequenceVisualEditor)
	add_child_autofree(_editor)
	_sequence = Sequence.new()
	_sequence.seq_name = "Test Sequence"

# ===================
# GRILLE
# ===================

func test_grid_overlay_node_exists():
	assert_not_null(_editor._grid_overlay, "Grid overlay node should exist")

func test_grid_overlay_between_bg_and_fg():
	# Grid should be child of canvas, after bg_rect but before fg_container
	var canvas = _editor._canvas
	var grid_idx = _editor._grid_overlay.get_index()
	var bg_idx = _editor._bg_rect.get_index()
	var fg_idx = _editor._fg_container.get_index()
	assert_true(grid_idx > bg_idx, "Grid should be after background")
	assert_true(grid_idx < fg_idx, "Grid should be before foreground container")

func test_grid_initially_hidden():
	assert_false(_editor._grid_visible, "Grid should be hidden by default")

func test_toggle_grid_on():
	_editor.set_grid_visible(true)
	assert_true(_editor._grid_visible)

func test_toggle_grid_off():
	_editor.set_grid_visible(true)
	_editor.set_grid_visible(false)
	assert_false(_editor._grid_visible)

func test_grid_not_visible_without_background():
	_editor.load_sequence(_sequence)
	_editor.set_grid_visible(true)
	assert_false(_editor._grid_overlay.visible, "Grid should not show without background")

func test_grid_has_correct_divisions():
	assert_eq(_editor._placement_grid.divisions, 12)

# ===================
# SNAPPING
# ===================

func test_snapping_initially_off():
	assert_false(_editor._snap_enabled)

func test_toggle_snapping_on():
	_editor.set_snap_enabled(true)
	assert_true(_editor._snap_enabled)

func test_toggle_snapping_off():
	_editor.set_snap_enabled(true)
	_editor.set_snap_enabled(false)
	assert_false(_editor._snap_enabled)

func test_snapping_independent_of_grid():
	# Can enable snapping without grid visible
	_editor.set_grid_visible(false)
	_editor.set_snap_enabled(true)
	assert_false(_editor._grid_visible)
	assert_true(_editor._snap_enabled)

func test_snap_anchor_on_drag_end():
	_editor.load_sequence(_sequence)
	_editor.add_foreground("Hero", "hero.png")
	var uuid = _sequence.foregrounds[0].uuid
	var fg = _editor.find_foreground(uuid)
	fg.anchor_bg = Vector2(0.09, 0.09)  # Close to (1/12, 1/12)
	_editor.set_snap_enabled(true)
	_editor._apply_snap_to_foreground(uuid)
	var expected = Vector2(1.0 / 12.0, 1.0 / 12.0)
	assert_almost_eq(fg.anchor_bg.x, expected.x, 0.01)
	assert_almost_eq(fg.anchor_bg.y, expected.y, 0.01)

func test_snap_does_not_modify_anchor_fg():
	_editor.load_sequence(_sequence)
	_editor.add_foreground("Hero", "hero.png")
	var uuid = _sequence.foregrounds[0].uuid
	var fg = _editor.find_foreground(uuid)
	fg.anchor_fg = Vector2(0.3, 0.7)
	fg.anchor_bg = Vector2(0.09, 0.09)
	_editor.set_snap_enabled(true)
	_editor._apply_snap_to_foreground(uuid)
	assert_almost_eq(fg.anchor_fg.x, 0.3, 0.001)
	assert_almost_eq(fg.anchor_fg.y, 0.7, 0.001)

func test_snap_does_not_modify_scale():
	_editor.load_sequence(_sequence)
	_editor.add_foreground("Hero", "hero.png")
	var uuid = _sequence.foregrounds[0].uuid
	var fg = _editor.find_foreground(uuid)
	fg.scale = 2.5
	fg.anchor_bg = Vector2(0.09, 0.09)
	_editor.set_snap_enabled(true)
	_editor._apply_snap_to_foreground(uuid)
	assert_almost_eq(fg.scale, 2.5, 0.001)

func test_no_snap_when_disabled():
	_editor.load_sequence(_sequence)
	_editor.add_foreground("Hero", "hero.png")
	var uuid = _sequence.foregrounds[0].uuid
	var fg = _editor.find_foreground(uuid)
	fg.anchor_bg = Vector2(0.09, 0.09)
	_editor.set_snap_enabled(false)
	_editor._apply_snap_to_foreground(uuid)
	# Should not snap — position unchanged
	assert_almost_eq(fg.anchor_bg.x, 0.09, 0.001)
	assert_almost_eq(fg.anchor_bg.y, 0.09, 0.001)

# ===================
# CONTEXT MENU — COPIER/COLLER
# ===================

func test_context_menu_has_copy_item():
	var menu = _editor._context_menu
	var found = false
	for i in range(menu.item_count):
		if menu.get_item_text(i) == "Copier les paramètres":
			found = true
			break
	assert_true(found, "Context menu should have 'Copier les paramètres'")

func test_context_menu_has_paste_item():
	var menu = _editor._context_menu
	var found = false
	for i in range(menu.item_count):
		if menu.get_item_text(i) == "Coller les paramètres":
			found = true
			break
	assert_true(found, "Context menu should have 'Coller les paramètres'")

func test_paste_disabled_when_clipboard_empty():
	var menu = _editor._context_menu
	_editor._update_context_menu_state()
	var paste_idx = -1
	for i in range(menu.item_count):
		if menu.get_item_text(i) == "Coller les paramètres":
			paste_idx = i
			break
	assert_ne(paste_idx, -1)
	assert_true(menu.is_item_disabled(paste_idx), "Paste should be disabled when clipboard is empty")

func test_paste_enabled_after_copy():
	_editor.load_sequence(_sequence)
	_editor.add_foreground("Hero", "hero.png")
	var uuid = _sequence.foregrounds[0].uuid
	_editor._copy_foreground_params(uuid)
	_editor._update_context_menu_state()
	var menu = _editor._context_menu
	var paste_idx = -1
	for i in range(menu.item_count):
		if menu.get_item_text(i) == "Coller les paramètres":
			paste_idx = i
			break
	assert_false(menu.is_item_disabled(paste_idx), "Paste should be enabled after copy")

func test_copy_paste_applies_params():
	_editor.load_sequence(_sequence)
	_editor.add_foreground("Source", "source.png")
	_editor.add_foreground("Target", "target.png")
	var source = _sequence.foregrounds[0]
	var target = _sequence.foregrounds[1]
	source.scale = 2.5
	source.anchor_bg = Vector2(0.3, 0.7)
	source.anchor_fg = Vector2(0.1, 0.9)
	source.flip_h = true
	source.flip_v = true
	target.scale = 1.0
	target.anchor_bg = Vector2(0.5, 0.5)
	_editor._copy_foreground_params(source.uuid)
	_editor._paste_foreground_params(target.uuid)
	assert_almost_eq(target.scale, 2.5, 0.001)
	assert_almost_eq(target.anchor_bg.x, 0.3, 0.001)
	assert_almost_eq(target.anchor_bg.y, 0.7, 0.001)
	assert_almost_eq(target.anchor_fg.x, 0.1, 0.001)
	assert_almost_eq(target.anchor_fg.y, 0.9, 0.001)
	assert_true(target.flip_h)
	assert_true(target.flip_v)

func test_paste_preserves_unrelated_props():
	_editor.load_sequence(_sequence)
	_editor.add_foreground("Source", "source.png")
	_editor.add_foreground("Target", "target.png")
	var source = _sequence.foregrounds[0]
	var target = _sequence.foregrounds[1]
	source.z_order = 99
	source.opacity = 0.1
	source.transition_type = "fade"
	target.z_order = 5
	target.opacity = 0.8
	target.transition_type = "fade"
	var target_uuid = target.uuid
	var target_image = target.image
	var target_name = target.fg_name
	_editor._copy_foreground_params(source.uuid)
	_editor._paste_foreground_params(target.uuid)
	assert_eq(target.uuid, target_uuid)
	assert_eq(target.image, target_image)
	assert_eq(target.fg_name, target_name)
	assert_eq(target.z_order, 5)
	assert_almost_eq(target.opacity, 0.8, 0.001)
	assert_eq(target.transition_type, "fade")

func test_clipboard_accessible():
	assert_not_null(_editor._fg_clipboard)
	assert_false(_editor._fg_clipboard.has_data())
