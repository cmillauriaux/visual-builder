extends GutTest

# Tests pour copier/coller les foregrounds entre séquences

const SequenceGraphView = preload("res://src/views/sequence_graph_view.gd")
const GraphNodeItem = preload("res://src/views/graph_node_item.gd")
const SceneData = preload("res://src/models/scene_data.gd")
const Sequence = preload("res://src/models/sequence.gd")
const Foreground = preload("res://src/models/foreground.gd")
const Dialogue = preload("res://src/models/dialogue.gd")

var _view: GraphEdit = null
var _scene_data = null

func before_each():
	_view = GraphEdit.new()
	_view.set_script(SequenceGraphView)
	add_child_autofree(_view)
	_scene_data = SceneData.new()

func _make_foreground(name: String, img: String = "test.png") -> RefCounted:
	var fg = Foreground.new()
	fg.fg_name = name
	fg.image = img
	fg.scale = 1.5
	fg.anchor_bg = Vector2(0.3, 0.4)
	fg.anchor_fg = Vector2(0.5, 0.5)
	fg.flip_h = true
	fg.flip_v = false
	fg.opacity = 0.8
	fg.z_order = 2
	fg.transition_type = "fade"
	fg.transition_duration = 1.0
	return fg

func _make_sequence_with_foregrounds() -> RefCounted:
	var seq = Sequence.new()
	seq.seq_name = "Source"
	seq.foregrounds.append(_make_foreground("Hero", "hero.png"))
	seq.foregrounds.append(_make_foreground("Enemy", "enemy.png"))

	var dlg1 = Dialogue.new()
	dlg1.character = "Hero"
	dlg1.text = "Hello"
	dlg1.foregrounds.append(_make_foreground("Hero Close", "hero_close.png"))
	seq.dialogues.append(dlg1)

	var dlg2 = Dialogue.new()
	dlg2.character = "Enemy"
	dlg2.text = "Fight!"
	dlg2.foregrounds.append(_make_foreground("Enemy Close", "enemy_close.png"))
	dlg2.foregrounds.append(_make_foreground("Hero Far", "hero_far.png"))
	seq.dialogues.append(dlg2)

	return seq


# --- Tests du menu contextuel ---

func test_context_menu_has_copy_foregrounds():
	var node = GraphNode.new()
	node.set_script(GraphNodeItem)
	node.setup("uuid-1", "Seq 1", Vector2.ZERO)
	node.setup_sequence_options()
	add_child_autofree(node)
	var menu = node.get_node("ContextMenu")
	var copy_idx = menu.get_item_index(3)
	assert_true(copy_idx >= 0, "Le menu doit contenir 'Copier les foregrounds'")
	assert_eq(menu.get_item_text(copy_idx), "Copier les foregrounds")

func test_context_menu_has_paste_foregrounds():
	var node = GraphNode.new()
	node.set_script(GraphNodeItem)
	node.setup("uuid-1", "Seq 1", Vector2.ZERO)
	node.setup_sequence_options()
	add_child_autofree(node)
	var menu = node.get_node("ContextMenu")
	var paste_idx = menu.get_item_index(4)
	assert_true(paste_idx >= 0, "Le menu doit contenir 'Coller les foregrounds'")
	assert_eq(menu.get_item_text(paste_idx), "Coller les foregrounds")

func test_copy_signal_emitted():
	var node = GraphNode.new()
	node.set_script(GraphNodeItem)
	node.setup("uuid-copy", "Seq", Vector2.ZERO)
	node.setup_sequence_options()
	add_child_autofree(node)
	watch_signals(node)
	node._on_popup_id_pressed(3)
	assert_signal_emitted(node, "foregrounds_copy_requested")

func test_paste_signal_emitted():
	var node = GraphNode.new()
	node.set_script(GraphNodeItem)
	node.setup("uuid-paste", "Seq", Vector2.ZERO)
	node.setup_sequence_options()
	add_child_autofree(node)
	watch_signals(node)
	node._on_popup_id_pressed(4)
	assert_signal_emitted(node, "foregrounds_paste_requested")

func test_set_paste_foregrounds_enabled():
	var node = GraphNode.new()
	node.set_script(GraphNodeItem)
	node.setup("uuid-1", "Seq", Vector2.ZERO)
	node.setup_sequence_options()
	add_child_autofree(node)
	var menu = node.get_node("ContextMenu")
	var paste_idx = menu.get_item_index(4)

	node.set_paste_foregrounds_enabled(false)
	assert_true(menu.is_item_disabled(paste_idx), "Coller doit etre desactive")

	node.set_paste_foregrounds_enabled(true)
	assert_false(menu.is_item_disabled(paste_idx), "Coller doit etre active")

func test_set_copy_foregrounds_enabled():
	var node = GraphNode.new()
	node.set_script(GraphNodeItem)
	node.setup("uuid-1", "Seq", Vector2.ZERO)
	node.setup_sequence_options()
	add_child_autofree(node)
	var menu = node.get_node("ContextMenu")
	var copy_idx = menu.get_item_index(3)

	node.set_copy_foregrounds_enabled(false)
	assert_true(menu.is_item_disabled(copy_idx), "Copier doit etre desactive")

	node.set_copy_foregrounds_enabled(true)
	assert_false(menu.is_item_disabled(copy_idx), "Copier doit etre active")


# --- Tests clipboard dans SequenceGraphView ---

func test_copy_stores_clipboard():
	var seq = _make_sequence_with_foregrounds()
	_scene_data.sequences.append(seq)
	_view.load_scene(_scene_data)

	_view._on_foregrounds_copy_requested(seq.uuid)

	assert_false(_view._fg_clipboard.is_empty(), "Le clipboard ne doit pas etre vide apres copie")
	assert_eq(_view._fg_clipboard["sequence_foregrounds"].size(), 2, "2 foregrounds de sequence")
	assert_eq(_view._fg_clipboard["dialogue_foregrounds"].size(), 2, "2 dialogues")
	assert_eq(_view._fg_clipboard["dialogue_foregrounds"][0].size(), 1, "1 fg dans dialogue 0")
	assert_eq(_view._fg_clipboard["dialogue_foregrounds"][1].size(), 2, "2 fg dans dialogue 1")

func test_copy_preserves_properties():
	var seq = _make_sequence_with_foregrounds()
	_scene_data.sequences.append(seq)
	_view.load_scene(_scene_data)

	_view._on_foregrounds_copy_requested(seq.uuid)

	var fg_data = _view._fg_clipboard["sequence_foregrounds"][0]
	assert_eq(fg_data["name"], "Hero")
	assert_eq(fg_data["image"], "hero.png")
	assert_eq(fg_data["scale"], 1.5)
	assert_eq(fg_data["flip_h"], true)
	assert_eq(fg_data["opacity"], 0.8)
	assert_eq(fg_data["z_order"], 2)
	assert_eq(fg_data["transition_type"], "fade")
	assert_eq(fg_data["transition_duration"], 1.0)

func test_copy_empty_sequence_has_empty_clipboard():
	var seq = Sequence.new()
	seq.seq_name = "Vide"
	_scene_data.sequences.append(seq)
	_view.load_scene(_scene_data)

	_view._on_foregrounds_copy_requested(seq.uuid)

	assert_eq(_view._fg_clipboard["sequence_foregrounds"].size(), 0)
	assert_eq(_view._fg_clipboard["dialogue_foregrounds"].size(), 0)

func test_paste_emits_signal():
	var source = _make_sequence_with_foregrounds()
	var target = Sequence.new()
	target.seq_name = "Target"
	_scene_data.sequences.append(source)
	_scene_data.sequences.append(target)
	_view.load_scene(_scene_data)

	_view._on_foregrounds_copy_requested(source.uuid)
	watch_signals(_view)
	_view._on_foregrounds_paste_requested(target.uuid)

	assert_signal_emitted(_view, "sequence_foregrounds_paste_requested")

func test_paste_without_clipboard_does_nothing():
	var target = Sequence.new()
	target.seq_name = "Target"
	_scene_data.sequences.append(target)
	_view.load_scene(_scene_data)

	watch_signals(_view)
	_view._on_foregrounds_paste_requested(target.uuid)

	assert_signal_not_emitted(_view, "sequence_foregrounds_paste_requested")

func test_sequence_has_foregrounds_true():
	var seq = _make_sequence_with_foregrounds()
	_scene_data.sequences.append(seq)
	_view.load_scene(_scene_data)

	assert_true(_view._sequence_has_foregrounds(seq.uuid))

func test_sequence_has_foregrounds_false():
	var seq = Sequence.new()
	seq.seq_name = "Vide"
	_scene_data.sequences.append(seq)
	_view.load_scene(_scene_data)

	assert_false(_view._sequence_has_foregrounds(seq.uuid))

func test_sequence_has_foregrounds_only_in_dialogue():
	var seq = Sequence.new()
	seq.seq_name = "DlgOnly"
	var dlg = Dialogue.new()
	dlg.foregrounds.append(_make_foreground("Test"))
	seq.dialogues.append(dlg)
	_scene_data.sequences.append(seq)
	_view.load_scene(_scene_data)

	assert_true(_view._sequence_has_foregrounds(seq.uuid))

func test_copy_enables_paste_on_all_nodes():
	var source = _make_sequence_with_foregrounds()
	var target = Sequence.new()
	target.seq_name = "Target"
	_scene_data.sequences.append(source)
	_scene_data.sequences.append(target)
	_view.load_scene(_scene_data)

	# Avant copie, le paste doit etre desactive
	var target_node = _view._node_map[target.uuid]
	var menu = target_node.get_node("ContextMenu")
	var paste_idx = menu.get_item_index(4)
	assert_true(menu.is_item_disabled(paste_idx), "Paste doit etre desactive avant copie")

	_view._on_foregrounds_copy_requested(source.uuid)

	# Apres copie, le paste doit etre active
	assert_false(menu.is_item_disabled(paste_idx), "Paste doit etre active apres copie")

func test_copy_disables_on_empty_source():
	var seq = Sequence.new()
	seq.seq_name = "Vide"
	_scene_data.sequences.append(seq)
	_view.load_scene(_scene_data)

	var node = _view._node_map[seq.uuid]
	var menu = node.get_node("ContextMenu")
	var copy_idx = menu.get_item_index(3)
	assert_true(menu.is_item_disabled(copy_idx), "Copier doit etre desactive pour sequence sans foregrounds")


# --- Tests de la logique de collage (transformation des données) ---

func _apply_paste(target: RefCounted, clipboard_data: Dictionary) -> void:
	var new_seq_fgs := []
	for fg_dict in clipboard_data.get("sequence_foregrounds", []):
		var fg = Foreground.from_dict(fg_dict)
		fg.uuid = Foreground._generate_uuid()
		new_seq_fgs.append(fg)
	target.foregrounds = new_seq_fgs

	var dlg_fgs_data: Array = clipboard_data.get("dialogue_foregrounds", [])
	for i in range(mini(target.dialogues.size(), dlg_fgs_data.size())):
		var new_dlg_fgs := []
		for fg_dict in dlg_fgs_data[i]:
			var fg = Foreground.from_dict(fg_dict)
			fg.uuid = Foreground._generate_uuid()
			new_dlg_fgs.append(fg)
		target.dialogues[i].foregrounds = new_dlg_fgs

func test_paste_replaces_sequence_foregrounds():
	var source = _make_sequence_with_foregrounds()
	_scene_data.sequences.append(source)
	_view.load_scene(_scene_data)
	_view._on_foregrounds_copy_requested(source.uuid)

	var target = Sequence.new()
	target.seq_name = "Target"
	var dlg = Dialogue.new()
	dlg.character = "X"
	target.dialogues.append(dlg)

	_apply_paste(target, _view._fg_clipboard)

	assert_eq(target.foregrounds.size(), 2, "La cible doit avoir 2 foregrounds de sequence")
	assert_eq(target.foregrounds[0].fg_name, "Hero")
	assert_eq(target.foregrounds[1].fg_name, "Enemy")

func test_paste_applies_dialogue_foregrounds_by_index():
	var source = _make_sequence_with_foregrounds()
	_scene_data.sequences.append(source)
	_view.load_scene(_scene_data)
	_view._on_foregrounds_copy_requested(source.uuid)

	var target = Sequence.new()
	target.seq_name = "Target"
	var dlg1 = Dialogue.new()
	dlg1.character = "A"
	target.dialogues.append(dlg1)
	var dlg2 = Dialogue.new()
	dlg2.character = "B"
	target.dialogues.append(dlg2)

	_apply_paste(target, _view._fg_clipboard)

	assert_eq(target.dialogues[0].foregrounds.size(), 1, "Dialogue 0 doit avoir 1 fg")
	assert_eq(target.dialogues[0].foregrounds[0].fg_name, "Hero Close")
	assert_eq(target.dialogues[1].foregrounds.size(), 2, "Dialogue 1 doit avoir 2 fg")
	assert_eq(target.dialogues[1].foregrounds[0].fg_name, "Enemy Close")
	assert_eq(target.dialogues[1].foregrounds[1].fg_name, "Hero Far")

func test_paste_generates_new_uuids():
	var source = _make_sequence_with_foregrounds()
	_scene_data.sequences.append(source)
	_view.load_scene(_scene_data)
	_view._on_foregrounds_copy_requested(source.uuid)

	var target = Sequence.new()
	target.seq_name = "Target"
	_apply_paste(target, _view._fg_clipboard)

	for i in range(target.foregrounds.size()):
		assert_ne(target.foregrounds[i].uuid, source.foregrounds[i].uuid,
			"Les UUIDs des foregrounds colles doivent etre differents des originaux")

func test_paste_preserves_all_properties():
	var source = _make_sequence_with_foregrounds()
	_scene_data.sequences.append(source)
	_view.load_scene(_scene_data)
	_view._on_foregrounds_copy_requested(source.uuid)

	var target = Sequence.new()
	target.seq_name = "Target"
	_apply_paste(target, _view._fg_clipboard)

	var pasted = target.foregrounds[0]
	assert_eq(pasted.fg_name, "Hero")
	assert_eq(pasted.image, "hero.png")
	assert_eq(pasted.scale, 1.5)
	assert_eq(pasted.anchor_bg, Vector2(0.3, 0.4))
	assert_eq(pasted.anchor_fg, Vector2(0.5, 0.5))
	assert_eq(pasted.flip_h, true)
	assert_eq(pasted.flip_v, false)
	assert_eq(pasted.opacity, 0.8)
	assert_eq(pasted.z_order, 2)
	assert_eq(pasted.transition_type, "fade")
	assert_eq(pasted.transition_duration, 1.0)

func test_paste_does_not_modify_extra_target_dialogues():
	var source = Sequence.new()
	source.seq_name = "Source"
	source.foregrounds.append(_make_foreground("A"))
	var src_dlg = Dialogue.new()
	src_dlg.foregrounds.append(_make_foreground("B"))
	source.dialogues.append(src_dlg)
	_scene_data.sequences.append(source)
	_view.load_scene(_scene_data)
	_view._on_foregrounds_copy_requested(source.uuid)

	var target = Sequence.new()
	target.seq_name = "Target"
	var dlg1 = Dialogue.new()
	target.dialogues.append(dlg1)
	var dlg2 = Dialogue.new()
	var original_fg = _make_foreground("Original")
	dlg2.foregrounds.append(original_fg)
	target.dialogues.append(dlg2)

	_apply_paste(target, _view._fg_clipboard)

	# Dialogue 0 gets source's dialogue 0 foregrounds
	assert_eq(target.dialogues[0].foregrounds.size(), 1)
	assert_eq(target.dialogues[0].foregrounds[0].fg_name, "B")
	# Dialogue 1 (beyond source count) remains unchanged
	assert_eq(target.dialogues[1].foregrounds.size(), 1)
	assert_eq(target.dialogues[1].foregrounds[0].fg_name, "Original")

func test_paste_does_not_modify_non_foreground_properties():
	var source = _make_sequence_with_foregrounds()
	_scene_data.sequences.append(source)
	_view.load_scene(_scene_data)
	_view._on_foregrounds_copy_requested(source.uuid)

	var target = Sequence.new()
	target.seq_name = "Target Seq"
	target.background = "bg.png"
	target.music = "music.ogg"
	var dlg = Dialogue.new()
	dlg.character = "Narrateur"
	dlg.text = "Bonjour"
	target.dialogues.append(dlg)

	_apply_paste(target, _view._fg_clipboard)

	assert_eq(target.seq_name, "Target Seq")
	assert_eq(target.background, "bg.png")
	assert_eq(target.music, "music.ogg")
	assert_eq(target.dialogues[0].character, "Narrateur")
	assert_eq(target.dialogues[0].text, "Bonjour")
