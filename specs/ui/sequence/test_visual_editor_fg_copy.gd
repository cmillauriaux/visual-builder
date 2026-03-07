extends GutTest

## Tests pour copier/coller un foreground entier dans l'éditeur visuel (spec 062).
## Couvre aussi la multi-sélection SHIFT et le clic droit sur le background.

const SequenceVisualEditor = preload("res://src/ui/sequence/sequence_visual_editor.gd")
const Sequence = preload("res://src/models/sequence.gd")
const Foreground = preload("res://src/models/foreground.gd")

var _editor: Control = null
var _sequence = null

func before_each():
	_editor = Control.new()
	_editor.set_script(SequenceVisualEditor)
	add_child_autofree(_editor)
	_sequence = Sequence.new()
	_sequence.seq_name = "Test Sequence"

# ===================
# MENU CONTEXTUEL FOREGROUND
# ===================

func test_context_menu_has_copy_foreground_item():
	var menu = _editor._context_menu
	var found = false
	for i in range(menu.item_count):
		if menu.get_item_text(i) == "Copier le foreground":
			found = true
			break
	assert_true(found, "Context menu should have 'Copier le foreground'")

func test_context_menu_has_paste_foreground_item():
	var menu = _editor._context_menu
	var found = false
	for i in range(menu.item_count):
		if menu.get_item_text(i) == "Coller le foreground":
			found = true
			break
	assert_true(found, "Context menu should have 'Coller le foreground'")

func test_paste_foreground_disabled_when_clipboard_empty():
	var menu = _editor._context_menu
	_editor._update_context_menu_state()
	var paste_idx = -1
	for i in range(menu.item_count):
		if menu.get_item_text(i) == "Coller le foreground":
			paste_idx = i
			break
	assert_ne(paste_idx, -1)
	assert_true(menu.is_item_disabled(paste_idx), "Paste foreground should be disabled when clipboard is empty")

func test_paste_foreground_enabled_after_copy():
	_editor.load_sequence(_sequence)
	_editor.add_foreground("Hero", "hero.png")
	var uuid = _sequence.foregrounds[0].uuid
	_editor._copy_foreground(uuid)
	_editor._update_context_menu_state()
	var menu = _editor._context_menu
	var paste_idx = -1
	for i in range(menu.item_count):
		if menu.get_item_text(i) == "Coller le foreground":
			paste_idx = i
			break
	assert_false(menu.is_item_disabled(paste_idx), "Paste foreground should be enabled after copy")

# ===================
# COPIER / COLLER (simple)
# ===================

func test_copy_foreground_stores_data():
	_editor.load_sequence(_sequence)
	_editor.add_foreground("Hero", "hero.png")
	var uuid = _sequence.foregrounds[0].uuid
	_editor._copy_foreground(uuid)
	assert_true(_editor._fg_clipboard.has_foreground_data())

func test_paste_foreground_creates_new_foreground():
	_editor.load_sequence(_sequence)
	_editor.add_foreground("Hero", "hero.png")
	var uuid = _sequence.foregrounds[0].uuid
	_editor._copy_foreground(uuid)
	_editor._paste_foreground()
	assert_eq(_sequence.foregrounds.size(), 2, "Should have 2 foregrounds after paste")

func test_paste_foreground_has_new_uuid():
	_editor.load_sequence(_sequence)
	_editor.add_foreground("Hero", "hero.png")
	var source = _sequence.foregrounds[0]
	_editor._copy_foreground(source.uuid)
	_editor._paste_foreground()
	var pasted = _sequence.foregrounds[1]
	assert_ne(pasted.uuid, source.uuid, "Pasted foreground should have a new UUID")

func test_paste_foreground_preserves_all_properties():
	_editor.load_sequence(_sequence)
	_editor.add_foreground("Hero", "hero.png")
	var source = _sequence.foregrounds[0]
	source.scale = 2.5
	source.anchor_bg = Vector2(0.3, 0.7)
	source.anchor_fg = Vector2(0.1, 0.9)
	source.flip_h = true
	source.flip_v = true
	source.opacity = 0.6
	source.z_order = 5
	source.transition_type = "fade"
	source.transition_duration = 1.5
	_editor._copy_foreground(source.uuid)
	_editor._paste_foreground()
	var pasted = _sequence.foregrounds[1]
	assert_eq(pasted.fg_name, "Hero")
	assert_eq(pasted.image, "hero.png")
	assert_almost_eq(pasted.scale, 2.5, 0.001)
	assert_almost_eq(pasted.anchor_bg.x, 0.3, 0.001)
	assert_almost_eq(pasted.anchor_bg.y, 0.7, 0.001)
	assert_almost_eq(pasted.anchor_fg.x, 0.1, 0.001)
	assert_almost_eq(pasted.anchor_fg.y, 0.9, 0.001)
	assert_true(pasted.flip_h)
	assert_true(pasted.flip_v)
	assert_almost_eq(pasted.opacity, 0.6, 0.001)
	assert_eq(pasted.z_order, 5)
	assert_eq(pasted.transition_type, "fade")
	assert_almost_eq(pasted.transition_duration, 1.5, 0.001)

func test_paste_without_copy_does_nothing():
	_editor.load_sequence(_sequence)
	_editor.add_foreground("Hero", "hero.png")
	_editor._paste_foreground()
	assert_eq(_sequence.foregrounds.size(), 1, "Should still have 1 foreground")

func test_paste_without_sequence_does_nothing():
	_editor.load_sequence(_sequence)
	_editor.add_foreground("Hero", "hero.png")
	var uuid = _sequence.foregrounds[0].uuid
	_editor._copy_foreground(uuid)
	_editor.load_sequence(null)
	_editor._paste_foreground()
	assert_null(_editor.get_sequence(), "No crash and sequence remains null")

func test_copy_replaces_previous_clipboard():
	_editor.load_sequence(_sequence)
	_editor.add_foreground("First", "first.png")
	_editor.add_foreground("Second", "second.png")
	_editor._copy_foreground(_sequence.foregrounds[0].uuid)
	_editor._copy_foreground(_sequence.foregrounds[1].uuid)
	_editor._paste_foreground()
	var pasted = _sequence.foregrounds[2]
	assert_eq(pasted.fg_name, "Second", "Should paste the last copied foreground")
	assert_eq(pasted.image, "second.png")

func test_multiple_pastes_create_independent_foregrounds():
	_editor.load_sequence(_sequence)
	_editor.add_foreground("Hero", "hero.png")
	_editor._copy_foreground(_sequence.foregrounds[0].uuid)
	_editor._paste_foreground()
	_editor._paste_foreground()
	assert_eq(_sequence.foregrounds.size(), 3, "Should have 3 foregrounds after 2 pastes")
	assert_ne(_sequence.foregrounds[1].uuid, _sequence.foregrounds[2].uuid, "Each paste should have a unique UUID")

# ===================
# MULTI-SÉLECTION SHIFT
# ===================

func test_select_single_foreground():
	_editor.load_sequence(_sequence)
	_editor.add_foreground("A", "a.png")
	var uuid = _sequence.foregrounds[0].uuid
	_editor._select_foreground(uuid)
	assert_eq(_editor._selected_fg_uuids.size(), 1)
	assert_eq(_editor._selected_fg_uuid, uuid)

func test_shift_select_adds_to_selection():
	_editor.load_sequence(_sequence)
	_editor.add_foreground("A", "a.png")
	_editor.add_foreground("B", "b.png")
	var uuid_a = _sequence.foregrounds[0].uuid
	var uuid_b = _sequence.foregrounds[1].uuid
	_editor._select_foreground(uuid_a)
	_editor._select_foreground(uuid_b, true)
	assert_eq(_editor._selected_fg_uuids.size(), 2)
	assert_true(uuid_a in _editor._selected_fg_uuids)
	assert_true(uuid_b in _editor._selected_fg_uuids)

func test_shift_select_toggles_off():
	_editor.load_sequence(_sequence)
	_editor.add_foreground("A", "a.png")
	_editor.add_foreground("B", "b.png")
	var uuid_a = _sequence.foregrounds[0].uuid
	var uuid_b = _sequence.foregrounds[1].uuid
	_editor._select_foreground(uuid_a)
	_editor._select_foreground(uuid_b, true)
	_editor._select_foreground(uuid_a, true)  # Toggle off A
	assert_eq(_editor._selected_fg_uuids.size(), 1)
	assert_false(uuid_a in _editor._selected_fg_uuids)
	assert_true(uuid_b in _editor._selected_fg_uuids)

func test_click_without_shift_replaces_selection():
	_editor.load_sequence(_sequence)
	_editor.add_foreground("A", "a.png")
	_editor.add_foreground("B", "b.png")
	var uuid_a = _sequence.foregrounds[0].uuid
	var uuid_b = _sequence.foregrounds[1].uuid
	_editor._select_foreground(uuid_a)
	_editor._select_foreground(uuid_b, true)
	_editor._select_foreground(uuid_a)  # Click without shift replaces
	assert_eq(_editor._selected_fg_uuids.size(), 1)
	assert_eq(_editor._selected_fg_uuid, uuid_a)

func test_all_selected_show_border():
	_editor.load_sequence(_sequence)
	_editor.add_foreground("A", "a.png")
	_editor.add_foreground("B", "b.png")
	var uuid_a = _sequence.foregrounds[0].uuid
	var uuid_b = _sequence.foregrounds[1].uuid
	_editor._select_foreground(uuid_a)
	_editor._select_foreground(uuid_b, true)
	var border_a = _editor._fg_visual_map[uuid_a].get_node("SelectionBorder")
	var border_b = _editor._fg_visual_map[uuid_b].get_node("SelectionBorder")
	assert_true(border_a.visible, "Border A should be visible")
	assert_true(border_b.visible, "Border B should be visible")

func test_resize_handle_only_for_single_selection():
	_editor.load_sequence(_sequence)
	_editor.add_foreground("A", "a.png")
	_editor.add_foreground("B", "b.png")
	var uuid_a = _sequence.foregrounds[0].uuid
	var uuid_b = _sequence.foregrounds[1].uuid
	# Single selection — handle visible
	_editor._select_foreground(uuid_a)
	var handle_a = _editor._fg_visual_map[uuid_a].get_node("ResizeHandle")
	assert_true(handle_a.visible, "Handle should be visible for single selection")
	# Multi selection — handle hidden
	_editor._select_foreground(uuid_b, true)
	handle_a = _editor._fg_visual_map[uuid_a].get_node("ResizeHandle")
	var handle_b = _editor._fg_visual_map[uuid_b].get_node("ResizeHandle")
	assert_false(handle_a.visible, "Handle A should be hidden for multi selection")
	assert_false(handle_b.visible, "Handle B should be hidden for multi selection")

func test_deselect_clears_all():
	_editor.load_sequence(_sequence)
	_editor.add_foreground("A", "a.png")
	_editor.add_foreground("B", "b.png")
	_editor._select_foreground(_sequence.foregrounds[0].uuid)
	_editor._select_foreground(_sequence.foregrounds[1].uuid, true)
	_editor._deselect_foreground()
	assert_eq(_editor._selected_fg_uuids.size(), 0)
	assert_eq(_editor._selected_fg_uuid, "")

func test_selected_fg_uuid_returns_last():
	_editor.load_sequence(_sequence)
	_editor.add_foreground("A", "a.png")
	_editor.add_foreground("B", "b.png")
	var uuid_a = _sequence.foregrounds[0].uuid
	var uuid_b = _sequence.foregrounds[1].uuid
	_editor._select_foreground(uuid_a)
	_editor._select_foreground(uuid_b, true)
	assert_eq(_editor._selected_fg_uuid, uuid_b, "Should return last selected")

# ===================
# COPIER / COLLER MULTI-SÉLECTION
# ===================

func test_copy_selected_foregrounds_copies_all():
	_editor.load_sequence(_sequence)
	_editor.add_foreground("A", "a.png")
	_editor.add_foreground("B", "b.png")
	_editor._select_foreground(_sequence.foregrounds[0].uuid)
	_editor._select_foreground(_sequence.foregrounds[1].uuid, true)
	_editor._copy_selected_foregrounds()
	_editor._paste_foreground()
	assert_eq(_sequence.foregrounds.size(), 4, "Should have 4 foregrounds (2 original + 2 pasted)")

func test_paste_multi_creates_unique_uuids():
	_editor.load_sequence(_sequence)
	_editor.add_foreground("A", "a.png")
	_editor.add_foreground("B", "b.png")
	var uuid_a = _sequence.foregrounds[0].uuid
	var uuid_b = _sequence.foregrounds[1].uuid
	_editor._select_foreground(uuid_a)
	_editor._select_foreground(uuid_b, true)
	_editor._copy_selected_foregrounds()
	_editor._paste_foreground()
	var pasted_a = _sequence.foregrounds[2]
	var pasted_b = _sequence.foregrounds[3]
	assert_ne(pasted_a.uuid, uuid_a)
	assert_ne(pasted_b.uuid, uuid_b)
	assert_ne(pasted_a.uuid, pasted_b.uuid)

func test_paste_multi_preserves_properties():
	_editor.load_sequence(_sequence)
	_editor.add_foreground("A", "a.png")
	_editor.add_foreground("B", "b.png")
	_sequence.foregrounds[0].scale = 2.0
	_sequence.foregrounds[1].scale = 3.0
	_editor._select_foreground(_sequence.foregrounds[0].uuid)
	_editor._select_foreground(_sequence.foregrounds[1].uuid, true)
	_editor._copy_selected_foregrounds()
	_editor._paste_foreground()
	assert_eq(_sequence.foregrounds[2].fg_name, "A")
	assert_eq(_sequence.foregrounds[3].fg_name, "B")
	assert_almost_eq(_sequence.foregrounds[2].scale, 2.0, 0.001)
	assert_almost_eq(_sequence.foregrounds[3].scale, 3.0, 0.001)

func test_delete_removes_all_selected():
	_editor.load_sequence(_sequence)
	_editor.add_foreground("A", "a.png")
	_editor.add_foreground("B", "b.png")
	_editor.add_foreground("C", "c.png")
	_editor._select_foreground(_sequence.foregrounds[0].uuid)
	_editor._select_foreground(_sequence.foregrounds[1].uuid, true)
	# Simulate delete via context menu
	_editor._on_context_menu_id_pressed(0)
	assert_eq(_sequence.foregrounds.size(), 1)
	assert_eq(_sequence.foregrounds[0].fg_name, "C")

# ===================
# MENU CONTEXTUEL BACKGROUND
# ===================

func test_bg_context_menu_exists():
	assert_not_null(_editor._bg_context_menu)

func test_bg_context_menu_has_paste_item():
	var menu = _editor._bg_context_menu
	var found = false
	for i in range(menu.item_count):
		if menu.get_item_text(i) == "Coller le foreground":
			found = true
			break
	assert_true(found, "Background context menu should have 'Coller le foreground'")

func test_bg_context_menu_paste_disabled_when_empty():
	_editor._update_bg_context_menu_state()
	var menu = _editor._bg_context_menu
	var paste_idx = menu.get_item_index(4)
	assert_true(menu.is_item_disabled(paste_idx), "Paste should be disabled when clipboard empty")

func test_bg_context_menu_paste_enabled_after_copy():
	_editor.load_sequence(_sequence)
	_editor.add_foreground("Hero", "hero.png")
	_editor._copy_foreground(_sequence.foregrounds[0].uuid)
	_editor._update_bg_context_menu_state()
	var menu = _editor._bg_context_menu
	var paste_idx = menu.get_item_index(4)
	assert_false(menu.is_item_disabled(paste_idx), "Paste should be enabled after copy")

func test_bg_context_menu_only_has_paste():
	var menu = _editor._bg_context_menu
	assert_eq(menu.item_count, 1, "Background context menu should only have paste item")
