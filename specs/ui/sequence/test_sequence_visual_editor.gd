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
	assert_not_null(_editor._fx_container)
	assert_true(_editor._canvas.is_inside_tree())


func test_fx_container_between_canvas_and_overlay():
	var fx_idx = _editor._fx_container.get_index()
	var canvas_idx = _editor._canvas.get_index()
	var overlay_idx = _editor._overlay_container.get_index()
	assert_true(fx_idx > canvas_idx, "FxContainer should be after Canvas")
	assert_true(fx_idx < overlay_idx, "FxContainer should be before OverlayContainer")


func test_load_sequence_preserves_fx_container_children():
	# Regression: load_sequence must NOT destroy FX overlays managed by sequence_fx_player
	var fx_child = ColorRect.new()
	fx_child.name = "FxVignetteOverlay"
	_editor._fx_container.add_child(fx_child)
	assert_eq(_editor._fx_container.get_child_count(), 1)

	_editor.load_sequence(_sequence)

	assert_eq(_editor._fx_container.get_child_count(), 1, "load_sequence should not clear _fx_container children")
	assert_true(is_instance_valid(fx_child), "FX overlay should still be valid after load_sequence")
	fx_child.queue_free()


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
	assert_eq(_editor._context_menu.item_count, 11)
	assert_eq(_editor._context_menu.get_item_text(0), "Supprimer")
	assert_eq(_editor._context_menu.get_item_text(1), "Copier les paramètres")
	assert_eq(_editor._context_menu.get_item_text(2), "Coller les paramètres")
	# index 3 = séparateur
	assert_eq(_editor._context_menu.get_item_text(4), "Remplacer")
	assert_eq(_editor._context_menu.get_item_text(5), "Remplacer par un nouveau foreground")
	# index 6 = séparateur
	assert_eq(_editor._context_menu.get_item_text(7), "Copier le foreground")
	assert_eq(_editor._context_menu.get_item_text(8), "Coller le foreground")
	# index 9 = séparateur
	assert_eq(_editor._context_menu.get_item_text(10), "Cacher")

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

# --- Cacher un foreground ---

func test_hide_foreground_hides_visual():
	_editor.load_sequence(_sequence)
	_editor.add_foreground("Hero", "hero.png")
	var uuid = _sequence.foregrounds[0].uuid
	_editor.hide_foreground(uuid)
	assert_true(_editor.is_foreground_hidden(uuid))
	var wrapper = _editor.get_foreground_node(uuid)
	assert_false(wrapper.visible)

func test_hide_foreground_deselects():
	_editor.load_sequence(_sequence)
	_editor.add_foreground("Hero", "hero.png")
	var uuid = _sequence.foregrounds[0].uuid
	_editor._select_foreground(uuid)
	_editor.hide_foreground(uuid)
	assert_eq(_editor._selected_fg_uuid, "")

func test_hidden_foreground_reappears_on_load_sequence():
	_editor.load_sequence(_sequence)
	_editor.add_foreground("Hero", "hero.png")
	var uuid = _sequence.foregrounds[0].uuid
	_editor.hide_foreground(uuid)
	_editor.load_sequence(_sequence)
	assert_false(_editor.is_foreground_hidden(uuid))
	var wrapper = _editor.get_foreground_node(uuid)
	assert_true(wrapper.visible)

# --- Normaliser les foregrounds ---

func test_normalize_removes_duplicate_foregrounds():
	_editor.load_sequence(_sequence)
	var fg1 = Foreground.new()
	fg1.image = "hero.png"
	fg1.anchor_bg = Vector2(0.5, 0.5)
	fg1.anchor_fg = Vector2(0.5, 1.0)
	var fg2 = Foreground.new()
	fg2.image = "hero.png"
	fg2.anchor_bg = Vector2(0.5, 0.5)
	fg2.anchor_fg = Vector2(0.5, 1.0)
	_sequence.foregrounds.append(fg1)
	_sequence.foregrounds.append(fg2)
	_editor._update_foreground_visuals()
	var removed = _editor.normalize_foregrounds()
	assert_eq(removed, 1)
	assert_eq(_sequence.foregrounds.size(), 1)

func test_normalize_keeps_different_images():
	_editor.load_sequence(_sequence)
	var fg1 = Foreground.new()
	fg1.image = "hero.png"
	fg1.anchor_bg = Vector2(0.5, 0.5)
	var fg2 = Foreground.new()
	fg2.image = "villain.png"
	fg2.anchor_bg = Vector2(0.5, 0.5)
	_sequence.foregrounds.append(fg1)
	_sequence.foregrounds.append(fg2)
	_editor._update_foreground_visuals()
	var removed = _editor.normalize_foregrounds()
	assert_eq(removed, 0)
	assert_eq(_sequence.foregrounds.size(), 2)

func test_normalize_keeps_different_positions():
	_editor.load_sequence(_sequence)
	var fg1 = Foreground.new()
	fg1.image = "hero.png"
	fg1.anchor_bg = Vector2(0.1, 0.1)
	var fg2 = Foreground.new()
	fg2.image = "hero.png"
	fg2.anchor_bg = Vector2(0.9, 0.9)
	_sequence.foregrounds.append(fg1)
	_sequence.foregrounds.append(fg2)
	_editor._update_foreground_visuals()
	var removed = _editor.normalize_foregrounds()
	assert_eq(removed, 0)
	assert_eq(_sequence.foregrounds.size(), 2)

func test_normalize_within_threshold():
	_editor.load_sequence(_sequence)
	var fg1 = Foreground.new()
	fg1.image = "hero.png"
	fg1.anchor_bg = Vector2(0.500, 0.500)
	fg1.anchor_fg = Vector2(0.5, 1.0)
	var fg2 = Foreground.new()
	fg2.image = "hero.png"
	fg2.anchor_bg = Vector2(0.505, 0.503)
	fg2.anchor_fg = Vector2(0.5, 1.0)
	_sequence.foregrounds.append(fg1)
	_sequence.foregrounds.append(fg2)
	_editor._update_foreground_visuals()
	var removed = _editor.normalize_foregrounds()
	assert_eq(removed, 1)

func test_normalize_returns_zero_when_no_duplicates():
	_editor.load_sequence(_sequence)
	_editor.add_foreground("A", "a.png")
	var removed = _editor.normalize_foregrounds()
	assert_eq(removed, 0)

func test_normalize_empty_sequence():
	_editor.load_sequence(_sequence)
	var removed = _editor.normalize_foregrounds()
	assert_eq(removed, 0)

# --- Réutilisation de wrappers (pas de clignotement) ---

func test_wrapper_reused_when_uuid_changes_but_visual_identical():
	# Simule le scénario : même image/position, UUID différent entre 2 dialogues
	# → le wrapper doit être RÉUTILISÉ (pas détruit/recréé)
	_editor.load_sequence(_sequence)
	_editor.add_foreground("Grille", "prison_bars.png")
	var old_uuid = _sequence.foregrounds[0].uuid
	var old_wrapper = _editor._fg_visual_map[old_uuid]

	# Simuler un changement de dialogue : nouveau foreground, UUID différent, même visuel
	var new_fg = Foreground.new()
	new_fg.image = "prison_bars.png"
	new_fg.anchor_bg = _sequence.foregrounds[0].anchor_bg
	new_fg.anchor_fg = _sequence.foregrounds[0].anchor_fg
	new_fg.scale = _sequence.foregrounds[0].scale
	new_fg.flip_h = _sequence.foregrounds[0].flip_h
	new_fg.flip_v = _sequence.foregrounds[0].flip_v
	# UUID différent (auto-généré par Foreground.new())

	_sequence.foregrounds = [new_fg]
	_editor.load_sequence(_sequence)

	# Le wrapper doit être le MÊME objet (réutilisé, pas recréé)
	var new_wrapper = _editor._fg_visual_map[new_fg.uuid]
	assert_eq(old_wrapper.get_instance_id(), new_wrapper.get_instance_id(),
		"Le wrapper doit être réutilisé quand le visuel est identique")

func test_wrapper_not_reused_when_image_changes():
	_editor.load_sequence(_sequence)
	_editor.add_foreground("Perso", "jessy_sad.png")
	var old_uuid = _sequence.foregrounds[0].uuid
	var old_wrapper = _editor._fg_visual_map[old_uuid]

	# Nouveau foreground avec une image différente
	var new_fg = Foreground.new()
	new_fg.image = "jessy_happy.png"
	new_fg.anchor_bg = _sequence.foregrounds[0].anchor_bg
	new_fg.anchor_fg = _sequence.foregrounds[0].anchor_fg
	new_fg.scale = _sequence.foregrounds[0].scale

	_sequence.foregrounds = [new_fg]
	_editor.load_sequence(_sequence)

	var new_wrapper = _editor._fg_visual_map[new_fg.uuid]
	assert_ne(old_wrapper.get_instance_id(), new_wrapper.get_instance_id(),
		"Le wrapper ne doit PAS être réutilisé quand l'image change")

func test_wrapper_reused_for_unchanged_fg_among_changed_ones():
	# Scénario "Lucy" : 3 FGs, seul le personnage change, la grille reste
	_editor.load_sequence(_sequence)
	_editor.add_foreground("Grille", "prison_bars.png")
	_editor.add_foreground("Jessy", "jessy_sad.png")
	var grille_uuid = _sequence.foregrounds[0].uuid
	var grille_wrapper = _editor._fg_visual_map[grille_uuid]

	# Nouveau dialogue : grille identique (UUID différent), Jessy change d'image
	var new_grille = Foreground.new()
	new_grille.image = "prison_bars.png"
	new_grille.anchor_bg = _sequence.foregrounds[0].anchor_bg
	new_grille.anchor_fg = _sequence.foregrounds[0].anchor_fg
	new_grille.scale = _sequence.foregrounds[0].scale
	new_grille.flip_h = _sequence.foregrounds[0].flip_h
	new_grille.flip_v = _sequence.foregrounds[0].flip_v

	var new_jessy = Foreground.new()
	new_jessy.image = "jessy_happy.png"  # Image différente

	_sequence.foregrounds = [new_grille, new_jessy]
	_editor.load_sequence(_sequence)

	# La grille doit être réutilisée
	assert_eq(grille_wrapper.get_instance_id(),
		_editor._fg_visual_map[new_grille.uuid].get_instance_id(),
		"La grille (inchangée) doit garder son wrapper")
	# Jessy doit avoir un nouveau wrapper
	assert_true(_editor._fg_visual_map.has(new_jessy.uuid),
		"Jessy (changée) doit avoir un nouveau wrapper")

# --- Indicateurs d'héritage ---

func test_set_inherited_mode():
	_editor.load_sequence(_sequence)
	assert_false(_editor.is_inherited_mode())
	_editor.set_inherited_mode(true, 2)
	assert_true(_editor.is_inherited_mode())
	assert_eq(_editor._inherited_from_index, 2)

func test_inherited_mode_resets_on_load():
	_editor.set_inherited_mode(true, 1)
	_editor.load_sequence(_sequence)
	assert_false(_editor.is_inherited_mode())

func test_inherited_fg_has_reduced_opacity():
	_editor.load_sequence(_sequence)
	_editor.add_foreground("Hero", "hero.png")
	var uuid = _sequence.foregrounds[0].uuid
	_editor.set_inherited_mode(true, 0)
	var wrapper = _editor.get_foreground_node(uuid)
	assert_almost_eq(wrapper.modulate.a, 0.5, 0.01,
		"Inherited FG should have ~50% opacity")

func test_non_inherited_fg_has_full_opacity():
	_editor.load_sequence(_sequence)
	_editor.add_foreground("Hero", "hero.png")
	var uuid = _sequence.foregrounds[0].uuid
	_editor.set_inherited_mode(false)
	var wrapper = _editor.get_foreground_node(uuid)
	assert_almost_eq(wrapper.modulate.a, 1.0, 0.01,
		"Non-inherited FG should have full opacity")

func test_inherited_fg_shows_inherit_border():
	_editor.load_sequence(_sequence)
	_editor.add_foreground("Hero", "hero.png")
	var uuid = _sequence.foregrounds[0].uuid
	_editor.set_inherited_mode(true, 0)
	var wrapper = _editor.get_foreground_node(uuid)
	var inherit_border = wrapper.get_node_or_null("InheritBorder")
	assert_not_null(inherit_border)
	assert_true(inherit_border.visible, "Inherit border should be visible")

func test_non_inherited_fg_hides_inherit_border():
	_editor.load_sequence(_sequence)
	_editor.add_foreground("Hero", "hero.png")
	var uuid = _sequence.foregrounds[0].uuid
	_editor.set_inherited_mode(false)
	var wrapper = _editor.get_foreground_node(uuid)
	var inherit_border = wrapper.get_node_or_null("InheritBorder")
	assert_not_null(inherit_border)
	assert_false(inherit_border.visible, "Inherit border should be hidden")

func test_inherited_fg_hides_selection_border():
	_editor.load_sequence(_sequence)
	_editor.add_foreground("Hero", "hero.png")
	var uuid = _sequence.foregrounds[0].uuid
	_editor._select_foreground(uuid)
	_editor.set_inherited_mode(true, 0)
	var wrapper = _editor.get_foreground_node(uuid)
	var border = wrapper.get_node("SelectionBorder")
	assert_false(border.visible, "Selection border hidden in inherited mode")

func test_inherited_fg_hides_resize_handle():
	_editor.load_sequence(_sequence)
	_editor.add_foreground("Hero", "hero.png")
	var uuid = _sequence.foregrounds[0].uuid
	_editor._select_foreground(uuid)
	_editor.set_inherited_mode(true, 0)
	var wrapper = _editor.get_foreground_node(uuid)
	var handle = wrapper.get_node("ResizeHandle")
	assert_false(handle.visible, "Resize handle hidden in inherited mode")

func test_inherit_confirm_dialog_exists():
	assert_not_null(_editor._inherit_confirm_dialog)

func test_inherit_confirmed_signal():
	watch_signals(_editor)
	_editor._on_inherit_confirmed()
	assert_signal_emitted(_editor, "inherited_foreground_edit_confirmed")
