extends GutTest

# Tests pour l'éditeur visuel de séquence

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

func test_load_sequence():
	_editor.load_sequence(_sequence)
	assert_eq(_editor.get_sequence(), _sequence)

func test_get_background():
	_sequence.background = "foret.png"
	_editor.load_sequence(_sequence)
	assert_eq(_editor.get_background(), "foret.png")

func test_set_background():
	_editor.load_sequence(_sequence)
	_editor.set_background("montagne.png")
	assert_eq(_sequence.background, "montagne.png")

func test_add_foreground():
	_editor.load_sequence(_sequence)
	_editor.add_foreground("Héros", "personnage-a.png")
	assert_eq(_sequence.foregrounds.size(), 1)
	assert_eq(_sequence.foregrounds[0].fg_name, "Héros")
	assert_eq(_sequence.foregrounds[0].image, "personnage-a.png")

func test_remove_foreground():
	_editor.load_sequence(_sequence)
	_editor.add_foreground("A", "a.png")
	_editor.add_foreground("B", "b.png")
	var uuid = _sequence.foregrounds[0].uuid
	_editor.remove_foreground(uuid)
	assert_eq(_sequence.foregrounds.size(), 1)
	assert_eq(_sequence.foregrounds[0].fg_name, "B")

func test_get_foreground_count():
	_editor.load_sequence(_sequence)
	assert_eq(_editor.get_foreground_count(), 0)
	_editor.add_foreground("A", "a.png")
	assert_eq(_editor.get_foreground_count(), 1)

func test_update_foreground_z_order():
	_editor.load_sequence(_sequence)
	_editor.add_foreground("Test", "test.png")
	var uuid = _sequence.foregrounds[0].uuid
	_editor.update_foreground_property(uuid, "z_order", 5)
	assert_eq(_sequence.foregrounds[0].z_order, 5)

func test_update_foreground_opacity():
	_editor.load_sequence(_sequence)
	_editor.add_foreground("Test", "test.png")
	var uuid = _sequence.foregrounds[0].uuid
	_editor.update_foreground_property(uuid, "opacity", 0.5)
	assert_almost_eq(_sequence.foregrounds[0].opacity, 0.5, 0.001)

func test_update_foreground_flip():
	_editor.load_sequence(_sequence)
	_editor.add_foreground("Test", "test.png")
	var uuid = _sequence.foregrounds[0].uuid
	_editor.update_foreground_property(uuid, "flip_h", true)
	_editor.update_foreground_property(uuid, "flip_v", true)
	assert_true(_sequence.foregrounds[0].flip_h)
	assert_true(_sequence.foregrounds[0].flip_v)

func test_update_foreground_scale():
	_editor.load_sequence(_sequence)
	_editor.add_foreground("Test", "test.png")
	var uuid = _sequence.foregrounds[0].uuid
	_editor.update_foreground_property(uuid, "scale", 2.0)
	assert_almost_eq(_sequence.foregrounds[0].scale, 2.0, 0.001)

func test_update_foreground_name():
	_editor.load_sequence(_sequence)
	_editor.add_foreground("Ancien", "test.png")
	var uuid = _sequence.foregrounds[0].uuid
	_editor.update_foreground_property(uuid, "fg_name", "Nouveau")
	assert_eq(_sequence.foregrounds[0].fg_name, "Nouveau")

func test_set_foreground_anchor_bg():
	_editor.load_sequence(_sequence)
	_editor.add_foreground("Test", "test.png")
	var uuid = _sequence.foregrounds[0].uuid
	_editor.set_foreground_anchor_bg(uuid, Vector2(0.3, 0.7))
	assert_almost_eq(_sequence.foregrounds[0].anchor_bg.x, 0.3, 0.001)
	assert_almost_eq(_sequence.foregrounds[0].anchor_bg.y, 0.7, 0.001)

func test_set_foreground_anchor_fg():
	_editor.load_sequence(_sequence)
	_editor.add_foreground("Test", "test.png")
	var uuid = _sequence.foregrounds[0].uuid
	_editor.set_foreground_anchor_fg(uuid, Vector2(0.5, 1.0))
	assert_almost_eq(_sequence.foregrounds[0].anchor_fg.x, 0.5, 0.001)
	assert_almost_eq(_sequence.foregrounds[0].anchor_fg.y, 1.0, 0.001)

func test_compute_foreground_position():
	# Le système d'ancrage point-à-point:
	# position du foreground = anchor_bg * bg_size - anchor_fg * fg_size
	_editor.load_sequence(_sequence)
	_editor.add_foreground("Test", "test.png")
	var uuid = _sequence.foregrounds[0].uuid
	_editor.set_foreground_anchor_bg(uuid, Vector2(0.5, 0.8))
	_editor.set_foreground_anchor_fg(uuid, Vector2(0.5, 1.0))
	var bg_size = Vector2(1920, 1080)
	var fg_size = Vector2(200, 400)
	var pos = _editor.compute_foreground_position(uuid, bg_size, fg_size)
	# anchor_bg * bg_size = (960, 864)
	# anchor_fg * fg_size = (100, 400)
	# position = (860, 464)
	assert_almost_eq(pos.x, 860.0, 0.1)
	assert_almost_eq(pos.y, 464.0, 0.1)

func test_foregrounds_sorted_by_z_order():
	_editor.load_sequence(_sequence)
	_editor.add_foreground("Back", "back.png")
	_editor.add_foreground("Front", "front.png")
	_sequence.foregrounds[0].z_order = 2
	_sequence.foregrounds[1].z_order = 1
	var sorted = _editor.get_foregrounds_sorted()
	assert_eq(sorted[0].fg_name, "Front")
	assert_eq(sorted[1].fg_name, "Back")

func test_find_foreground_by_uuid():
	_editor.load_sequence(_sequence)
	_editor.add_foreground("Target", "target.png")
	var uuid = _sequence.foregrounds[0].uuid
	var found = _editor.find_foreground(uuid)
	assert_not_null(found)
	assert_eq(found.fg_name, "Target")

func test_find_foreground_not_found():
	_editor.load_sequence(_sequence)
	var found = _editor.find_foreground("nonexistent-uuid")
	assert_null(found)

# --- CA-17: Visual nodes and zoom ---

func test_ready_creates_visual_nodes():
	assert_not_null(_editor._canvas)
	assert_not_null(_editor._bg_rect)
	assert_not_null(_editor._fg_container)
	assert_true(_editor._canvas.is_inside_tree())

func test_initial_zoom():
	assert_almost_eq(_editor._zoom, 1.0, 0.001)

func test_zoom_clamped():
	_editor._set_zoom(0.01)
	assert_almost_eq(_editor._zoom, 0.1, 0.001)
	_editor._set_zoom(10.0)
	assert_almost_eq(_editor._zoom, 5.0, 0.001)

func test_bg_not_visible_without_image():
	_editor.load_sequence(_sequence)
	assert_false(_editor._bg_rect.visible)

# --- CA-19: Foreground visuals ---

func test_fg_visual_created_on_add():
	_editor.load_sequence(_sequence)
	_editor.add_foreground("Hero", "hero.png")
	var uuid = _sequence.foregrounds[0].uuid
	assert_true(_editor._fg_visual_map.has(uuid))

func test_fg_visual_removed_on_delete():
	_editor.load_sequence(_sequence)
	_editor.add_foreground("Hero", "hero.png")
	var uuid = _sequence.foregrounds[0].uuid
	_editor.remove_foreground(uuid)
	assert_false(_editor._fg_visual_map.has(uuid))

func test_select_foreground():
	_editor.load_sequence(_sequence)
	_editor.add_foreground("Hero", "hero.png")
	var uuid = _sequence.foregrounds[0].uuid
	_editor._select_foreground(uuid)
	assert_eq(_editor._selected_fg_uuid, uuid)

func test_deselect_foreground():
	_editor.load_sequence(_sequence)
	_editor.add_foreground("Hero", "hero.png")
	var uuid = _sequence.foregrounds[0].uuid
	_editor._select_foreground(uuid)
	_editor._deselect_foreground()
	assert_eq(_editor._selected_fg_uuid, "")

func test_on_play_started_deselects_foreground():
	_editor.load_sequence(_sequence)
	_editor.add_foreground("Hero", "hero.png")
	var uuid = _sequence.foregrounds[0].uuid
	_editor._select_foreground(uuid)
	assert_eq(_editor._selected_fg_uuid, uuid)
	
	EventBus.play_started.emit("sequence")
	assert_eq(_editor._selected_fg_uuid, "")

# --- Context menu (right-click delete) ---

func test_context_menu_created():
	assert_not_null(_editor._context_menu)
	assert_eq(_editor._context_menu.item_count, 6)
	assert_eq(_editor._context_menu.get_item_text(0), "Supprimer")
	assert_eq(_editor._context_menu.get_item_text(1), "Copier les paramètres")
	assert_eq(_editor._context_menu.get_item_text(2), "Coller les paramètres")
	# index 3 = séparateur
	assert_eq(_editor._context_menu.get_item_text(4), "Copier le foreground")
	assert_eq(_editor._context_menu.get_item_text(5), "Coller le foreground")

func test_show_context_menu_sets_uuid():
	_editor.load_sequence(_sequence)
	_editor.add_foreground("Hero", "hero.png")
	var uuid = _sequence.foregrounds[0].uuid
	_editor._show_context_menu(uuid, Vector2(100, 100))
	assert_eq(_editor._context_menu_uuid, uuid)

func test_context_menu_delete_removes_foreground():
	_editor.load_sequence(_sequence)
	_editor.add_foreground("Hero", "hero.png")
	var uuid = _sequence.foregrounds[0].uuid
	_editor._select_foreground(uuid)
	_editor._show_context_menu(uuid, Vector2(100, 100))
	_editor._on_context_menu_id_pressed(0)
	assert_eq(_sequence.foregrounds.size(), 0)
	assert_eq(_editor._selected_fg_uuid, "")

func test_context_menu_delete_correct_foreground():
	_editor.load_sequence(_sequence)
	_editor.add_foreground("A", "a.png")
	_editor.add_foreground("B", "b.png")
	var uuid_a = _sequence.foregrounds[0].uuid
	_editor._select_foreground(uuid_a)
	_editor._show_context_menu(uuid_a, Vector2(100, 100))
	_editor._on_context_menu_id_pressed(0)
	assert_eq(_sequence.foregrounds.size(), 1)
	assert_eq(_sequence.foregrounds[0].fg_name, "B")
