extends GutTest

# Tests pour la fonctionnalité "Point d'entrée par niveau" (009)

const StoryScript = preload("res://src/models/story.gd")
const ChapterScript = preload("res://src/models/chapter.gd")
const SceneDataScript = preload("res://src/models/scene_data.gd")
const SequenceScript = preload("res://src/models/sequence.gd")
const DialogueScript = preload("res://src/models/dialogue.gd")
const GraphNodeItem = preload("res://src/views/graph_node_item.gd")
const ChapterGraphView = preload("res://src/views/chapter_graph_view.gd")
const SceneGraphView = preload("res://src/views/scene_graph_view.gd")
const SequenceGraphView = preload("res://src/views/sequence_graph_view.gd")
const StoryPlayController = preload("res://src/ui/story_play_controller.gd")

# === Helpers ===

func _make_story() -> RefCounted:
	var story = StoryScript.new()
	story.title = "Test Story"
	return story

func _make_chapter(ch_name: String, pos: Vector2 = Vector2(100, 100)) -> RefCounted:
	var ch = ChapterScript.new()
	ch.chapter_name = ch_name
	ch.position = pos
	return ch

func _make_scene(sc_name: String, pos: Vector2 = Vector2(100, 100)) -> RefCounted:
	var sc = SceneDataScript.new()
	sc.scene_name = sc_name
	sc.position = pos
	return sc

func _make_sequence(seq_name: String, pos: Vector2 = Vector2(100, 100)) -> RefCounted:
	var seq = SequenceScript.new()
	seq.seq_name = seq_name
	seq.position = pos
	var dlg = DialogueScript.new()
	dlg.character = "Narrator"
	dlg.text = "Hello"
	seq.dialogues.append(dlg)
	return seq

# =======================================================
# MODÈLES — entry_point_uuid
# =======================================================

# --- Story ---

func test_story_entry_point_default():
	var story = StoryScript.new()
	assert_eq(story.entry_point_uuid, "")

func test_story_entry_point_to_dict():
	var story = StoryScript.new()
	story.entry_point_uuid = "ch-001"
	var d = story.to_dict()
	assert_eq(d["entry_point"], "ch-001")

func test_story_entry_point_from_dict():
	var d = {
		"title": "Test",
		"author": "A",
		"entry_point": "ch-001",
	}
	var story = StoryScript.from_dict(d)
	assert_eq(story.entry_point_uuid, "ch-001")

func test_story_entry_point_retrocompat():
	var d = {"title": "Test", "author": "A"}
	var story = StoryScript.from_dict(d)
	assert_eq(story.entry_point_uuid, "")

# --- Chapter ---

func test_chapter_entry_point_default():
	var ch = ChapterScript.new()
	assert_eq(ch.entry_point_uuid, "")

func test_chapter_entry_point_to_dict_header():
	var ch = ChapterScript.new()
	ch.uuid = "abc"
	ch.chapter_name = "Ch1"
	ch.entry_point_uuid = "sc-001"
	var d = ch.to_dict_header()
	assert_eq(d["entry_point"], "sc-001")

func test_chapter_entry_point_to_dict():
	var ch = ChapterScript.new()
	ch.uuid = "abc"
	ch.chapter_name = "Ch1"
	ch.entry_point_uuid = "sc-001"
	var d = ch.to_dict()
	assert_eq(d["entry_point"], "sc-001")

func test_chapter_entry_point_from_dict_header():
	var d = {"uuid": "abc", "name": "Ch1", "position": {"x": 0, "y": 0}, "entry_point": "sc-001"}
	var ch = ChapterScript.from_dict_header(d)
	assert_eq(ch.entry_point_uuid, "sc-001")

func test_chapter_entry_point_from_dict():
	var d = {"uuid": "abc", "name": "Ch1", "scenes": [], "connections": [], "entry_point": "sc-001"}
	var ch = ChapterScript.from_dict(d)
	assert_eq(ch.entry_point_uuid, "sc-001")

func test_chapter_entry_point_retrocompat_header():
	var d = {"uuid": "abc", "name": "Ch1", "position": {"x": 0, "y": 0}}
	var ch = ChapterScript.from_dict_header(d)
	assert_eq(ch.entry_point_uuid, "")

func test_chapter_entry_point_retrocompat():
	var d = {"uuid": "abc", "name": "Ch1", "scenes": [], "connections": []}
	var ch = ChapterScript.from_dict(d)
	assert_eq(ch.entry_point_uuid, "")

# --- SceneData ---

func test_scene_data_entry_point_default():
	var sc = SceneDataScript.new()
	assert_eq(sc.entry_point_uuid, "")

func test_scene_data_entry_point_to_dict():
	var sc = SceneDataScript.new()
	sc.uuid = "scene-001"
	sc.scene_name = "Sc1"
	sc.entry_point_uuid = "seq-001"
	var d = sc.to_dict()
	assert_eq(d["entry_point"], "seq-001")

func test_scene_data_entry_point_from_dict():
	var d = {"uuid": "scene-001", "name": "Sc1", "sequences": [], "connections": [], "entry_point": "seq-001"}
	var sc = SceneDataScript.from_dict(d)
	assert_eq(sc.entry_point_uuid, "seq-001")

func test_scene_data_entry_point_retrocompat():
	var d = {"uuid": "scene-001", "name": "Sc1"}
	var sc = SceneDataScript.from_dict(d)
	assert_eq(sc.entry_point_uuid, "")

# =======================================================
# PERSISTANCE — Roundtrip save/load
# =======================================================

func test_story_roundtrip_entry_point():
	var story = StoryScript.new()
	story.title = "RT"
	story.entry_point_uuid = "ch-entry"
	var d = story.to_dict()
	var restored = StoryScript.from_dict(d)
	assert_eq(restored.entry_point_uuid, "ch-entry")

func test_chapter_roundtrip_entry_point():
	var ch = ChapterScript.new()
	ch.chapter_name = "RT"
	ch.entry_point_uuid = "sc-entry"
	var d = ch.to_dict()
	var restored = ChapterScript.from_dict(d)
	assert_eq(restored.entry_point_uuid, "sc-entry")

func test_scene_data_roundtrip_entry_point():
	var sc = SceneDataScript.new()
	sc.scene_name = "RT"
	sc.entry_point_uuid = "seq-entry"
	var d = sc.to_dict()
	var restored = SceneDataScript.from_dict(d)
	assert_eq(restored.entry_point_uuid, "seq-entry")

# =======================================================
# GRAPH NODE ITEM — checkbox, signal, visuel
# =======================================================

func test_graph_node_item_signal_exists():
	var node = GraphNode.new()
	node.set_script(GraphNodeItem)
	node.setup("uuid-1", "Noeud", Vector2.ZERO)
	add_child_autofree(node)
	assert_has_signal(node, "entry_point_toggled")

func test_graph_node_item_check_item_exists():
	var node = GraphNode.new()
	node.set_script(GraphNodeItem)
	node.setup("uuid-1", "Noeud", Vector2.ZERO)
	add_child_autofree(node)
	var popup = node.get_node("ContextMenu")
	# id 1 = "Point d'entrée" check item
	var idx = popup.get_item_index(1)
	assert_true(idx >= 0, "L'item id=1 doit exister")
	assert_true(popup.is_item_checkable(idx), "L'item doit être une checkbox")

func test_graph_node_item_toggle_entry_point():
	var node = GraphNode.new()
	node.set_script(GraphNodeItem)
	node.setup("uuid-1", "Noeud", Vector2.ZERO)
	add_child_autofree(node)
	watch_signals(node)
	# Simuler clic sur "Point d'entrée"
	node._on_popup_id_pressed(1)
	assert_signal_emitted(node, "entry_point_toggled")
	assert_true(node.is_entry_point())
	assert_eq(node.title, "▶ Noeud")

func test_graph_node_item_untoggle_entry_point():
	var node = GraphNode.new()
	node.set_script(GraphNodeItem)
	node.setup("uuid-1", "Noeud", Vector2.ZERO)
	add_child_autofree(node)
	node._on_popup_id_pressed(1)  # check
	watch_signals(node)
	node._on_popup_id_pressed(1)  # uncheck
	assert_signal_emitted(node, "entry_point_toggled")
	assert_false(node.is_entry_point())
	assert_eq(node.title, "Noeud")

func test_graph_node_item_set_entry_point_true():
	var node = GraphNode.new()
	node.set_script(GraphNodeItem)
	node.setup("uuid-1", "Noeud", Vector2.ZERO)
	add_child_autofree(node)
	node.set_entry_point(true)
	assert_true(node.is_entry_point())
	assert_eq(node.title, "▶ Noeud")

func test_graph_node_item_set_entry_point_false():
	var node = GraphNode.new()
	node.set_script(GraphNodeItem)
	node.setup("uuid-1", "Noeud", Vector2.ZERO)
	add_child_autofree(node)
	node.set_entry_point(true)
	node.set_entry_point(false)
	assert_false(node.is_entry_point())
	assert_eq(node.title, "Noeud")

func test_graph_node_item_entry_point_preserves_on_rename():
	var node = GraphNode.new()
	node.set_script(GraphNodeItem)
	node.setup("uuid-1", "Noeud", Vector2.ZERO)
	add_child_autofree(node)
	node.set_entry_point(true)
	node.set_item_name("Nouveau")
	assert_eq(node.title, "▶ Nouveau")

func test_graph_node_item_entry_point_preserves_on_rename_subtitle():
	var node = GraphNode.new()
	node.set_script(GraphNodeItem)
	node.setup("uuid-1", "Noeud", Vector2.ZERO)
	add_child_autofree(node)
	node.set_entry_point(true)
	node.set_item_name_and_subtitle("Nouveau", "Sous-titre")
	assert_eq(node.title, "▶ Nouveau")

# =======================================================
# VUES GRAPHE — unicité et propagation
# =======================================================

# --- Chapter graph view ---

func test_chapter_view_entry_point_signal():
	var view = GraphEdit.new()
	view.set_script(ChapterGraphView)
	add_child_autofree(view)
	assert_has_signal(view, "entry_point_changed")

func test_chapter_view_toggle_sets_model():
	var view = GraphEdit.new()
	view.set_script(ChapterGraphView)
	add_child_autofree(view)
	var story = _make_story()
	var ch1 = _make_chapter("Ch1")
	story.chapters.append(ch1)
	view.load_story(story)
	view._on_entry_point_toggled(ch1.uuid, true)
	assert_eq(story.entry_point_uuid, ch1.uuid)

func test_chapter_view_toggle_unsets_model():
	var view = GraphEdit.new()
	view.set_script(ChapterGraphView)
	add_child_autofree(view)
	var story = _make_story()
	var ch1 = _make_chapter("Ch1")
	story.chapters.append(ch1)
	view.load_story(story)
	view._on_entry_point_toggled(ch1.uuid, true)
	view._on_entry_point_toggled(ch1.uuid, false)
	assert_eq(story.entry_point_uuid, "")

func test_chapter_view_uniqueness():
	var view = GraphEdit.new()
	view.set_script(ChapterGraphView)
	add_child_autofree(view)
	var story = _make_story()
	var ch1 = _make_chapter("Ch1", Vector2(100, 100))
	var ch2 = _make_chapter("Ch2", Vector2(400, 100))
	story.chapters.append(ch1)
	story.chapters.append(ch2)
	view.load_story(story)
	view._on_entry_point_toggled(ch1.uuid, true)
	assert_eq(story.entry_point_uuid, ch1.uuid)
	view._on_entry_point_toggled(ch2.uuid, true)
	assert_eq(story.entry_point_uuid, ch2.uuid)

func test_chapter_view_load_marks_entry_point():
	var view = GraphEdit.new()
	view.set_script(ChapterGraphView)
	add_child_autofree(view)
	var story = _make_story()
	var ch1 = _make_chapter("Ch1")
	story.chapters.append(ch1)
	story.entry_point_uuid = ch1.uuid
	view.load_story(story)
	var node = view._node_map[ch1.uuid]
	assert_true(node.is_entry_point())

# --- Scene graph view ---

func test_scene_view_entry_point_signal():
	var view = GraphEdit.new()
	view.set_script(SceneGraphView)
	add_child_autofree(view)
	assert_has_signal(view, "entry_point_changed")

func test_scene_view_toggle_sets_model():
	var view = GraphEdit.new()
	view.set_script(SceneGraphView)
	add_child_autofree(view)
	var ch = _make_chapter("Ch1")
	var sc1 = _make_scene("Sc1")
	ch.scenes.append(sc1)
	view.load_chapter(ch)
	view._on_entry_point_toggled(sc1.uuid, true)
	assert_eq(ch.entry_point_uuid, sc1.uuid)

func test_scene_view_uniqueness():
	var view = GraphEdit.new()
	view.set_script(SceneGraphView)
	add_child_autofree(view)
	var ch = _make_chapter("Ch1")
	var sc1 = _make_scene("Sc1", Vector2(100, 100))
	var sc2 = _make_scene("Sc2", Vector2(400, 100))
	ch.scenes.append(sc1)
	ch.scenes.append(sc2)
	view.load_chapter(ch)
	view._on_entry_point_toggled(sc1.uuid, true)
	view._on_entry_point_toggled(sc2.uuid, true)
	assert_eq(ch.entry_point_uuid, sc2.uuid)

func test_scene_view_load_marks_entry_point():
	var view = GraphEdit.new()
	view.set_script(SceneGraphView)
	add_child_autofree(view)
	var ch = _make_chapter("Ch1")
	var sc1 = _make_scene("Sc1")
	ch.scenes.append(sc1)
	ch.entry_point_uuid = sc1.uuid
	view.load_chapter(ch)
	var node = view._node_map[sc1.uuid]
	assert_true(node.is_entry_point())

# --- Sequence graph view ---

func test_sequence_view_entry_point_signal():
	var view = GraphEdit.new()
	view.set_script(SequenceGraphView)
	add_child_autofree(view)
	assert_has_signal(view, "entry_point_changed")

func test_sequence_view_toggle_sets_model():
	var view = GraphEdit.new()
	view.set_script(SequenceGraphView)
	add_child_autofree(view)
	var sc = _make_scene("Sc1")
	var seq1 = _make_sequence("Seq1")
	sc.sequences.append(seq1)
	view.load_scene(sc)
	view._on_entry_point_toggled(seq1.uuid, true)
	assert_eq(sc.entry_point_uuid, seq1.uuid)

func test_sequence_view_uniqueness():
	var view = GraphEdit.new()
	view.set_script(SequenceGraphView)
	add_child_autofree(view)
	var sc = _make_scene("Sc1")
	var seq1 = _make_sequence("Seq1", Vector2(100, 100))
	var seq2 = _make_sequence("Seq2", Vector2(400, 100))
	sc.sequences.append(seq1)
	sc.sequences.append(seq2)
	view.load_scene(sc)
	view._on_entry_point_toggled(seq1.uuid, true)
	view._on_entry_point_toggled(seq2.uuid, true)
	assert_eq(sc.entry_point_uuid, seq2.uuid)

func test_sequence_view_load_marks_entry_point():
	var view = GraphEdit.new()
	view.set_script(SequenceGraphView)
	add_child_autofree(view)
	var sc = _make_scene("Sc1")
	var seq1 = _make_sequence("Seq1")
	sc.sequences.append(seq1)
	sc.entry_point_uuid = seq1.uuid
	view.load_scene(sc)
	var node = view._node_map[seq1.uuid]
	assert_true(node.is_entry_point())

# =======================================================
# PLAY CONTROLLER — _find_entry()
# =======================================================

func test_play_controller_uses_entry_point_uuid():
	var ctrl = Node.new()
	ctrl.set_script(StoryPlayController)
	add_child_autofree(ctrl)
	var story = _make_story()
	var ch_left = _make_chapter("Left", Vector2(100, 100))
	var ch_right = _make_chapter("Right", Vector2(500, 100))
	story.chapters.append(ch_left)
	story.chapters.append(ch_right)
	var sc_l = _make_scene("Sc L")
	ch_left.scenes.append(sc_l)
	sc_l.sequences.append(_make_sequence("Seq L"))
	var sc_r = _make_scene("Sc R")
	ch_right.scenes.append(sc_r)
	sc_r.sequences.append(_make_sequence("Seq R"))
	# Marquer ch_right comme point d'entrée (pas le plus à gauche)
	story.entry_point_uuid = ch_right.uuid
	ctrl.start_play_story(story)
	assert_eq(ctrl.get_current_chapter(), ch_right)

func test_play_controller_entry_point_scene():
	var ctrl = Node.new()
	ctrl.set_script(StoryPlayController)
	add_child_autofree(ctrl)
	var story = _make_story()
	var ch = _make_chapter("Ch1")
	story.chapters.append(ch)
	var sc_left = _make_scene("Left", Vector2(100, 100))
	var sc_right = _make_scene("Right", Vector2(500, 100))
	ch.scenes.append(sc_left)
	ch.scenes.append(sc_right)
	sc_left.sequences.append(_make_sequence("Seq L"))
	sc_right.sequences.append(_make_sequence("Seq R"))
	ch.entry_point_uuid = sc_right.uuid
	ctrl.start_play_story(story)
	assert_eq(ctrl.get_current_scene(), sc_right)

func test_play_controller_entry_point_sequence():
	var ctrl = Node.new()
	ctrl.set_script(StoryPlayController)
	add_child_autofree(ctrl)
	var story = _make_story()
	var ch = _make_chapter("Ch1")
	story.chapters.append(ch)
	var sc = _make_scene("Sc1")
	ch.scenes.append(sc)
	var seq_left = _make_sequence("Left", Vector2(100, 100))
	var seq_right = _make_sequence("Right", Vector2(500, 100))
	sc.sequences.append(seq_left)
	sc.sequences.append(seq_right)
	sc.entry_point_uuid = seq_right.uuid
	ctrl.start_play_story(story)
	assert_eq(ctrl.get_current_sequence(), seq_right)

func test_play_controller_fallback_empty_uuid():
	var ctrl = Node.new()
	ctrl.set_script(StoryPlayController)
	add_child_autofree(ctrl)
	var story = _make_story()
	var ch_left = _make_chapter("Left", Vector2(100, 100))
	var ch_right = _make_chapter("Right", Vector2(500, 100))
	story.chapters.append(ch_right)
	story.chapters.append(ch_left)
	var sc_l = _make_scene("Sc L")
	ch_left.scenes.append(sc_l)
	sc_l.sequences.append(_make_sequence("Seq L"))
	var sc_r = _make_scene("Sc R")
	ch_right.scenes.append(sc_r)
	sc_r.sequences.append(_make_sequence("Seq R"))
	# Pas de point d'entrée explicite → fallback position
	ctrl.start_play_story(story)
	assert_eq(ctrl.get_current_chapter(), ch_left)

func test_play_controller_fallback_invalid_uuid():
	var ctrl = Node.new()
	ctrl.set_script(StoryPlayController)
	add_child_autofree(ctrl)
	var story = _make_story()
	var ch = _make_chapter("Ch1")
	story.chapters.append(ch)
	var sc = _make_scene("Sc1")
	ch.scenes.append(sc)
	sc.sequences.append(_make_sequence("Seq1"))
	# UUID invalide → doit fallback
	story.entry_point_uuid = "nonexistent-uuid"
	watch_signals(ctrl)
	ctrl.start_play_story(story)
	assert_eq(ctrl.get_state(), StoryPlayController.State.PLAYING_SEQUENCE)
	assert_eq(ctrl.get_current_chapter(), ch)

func test_play_controller_start_chapter_with_entry_point():
	var ctrl = Node.new()
	ctrl.set_script(StoryPlayController)
	add_child_autofree(ctrl)
	var story = _make_story()
	var ch = _make_chapter("Ch1")
	story.chapters.append(ch)
	var sc_left = _make_scene("Left", Vector2(100, 100))
	var sc_right = _make_scene("Right", Vector2(500, 100))
	ch.scenes.append(sc_left)
	ch.scenes.append(sc_right)
	sc_left.sequences.append(_make_sequence("Seq L"))
	sc_right.sequences.append(_make_sequence("Seq R"))
	ch.entry_point_uuid = sc_right.uuid
	ctrl.start_play_chapter(story, ch)
	assert_eq(ctrl.get_current_scene(), sc_right)

func test_play_controller_start_scene_with_entry_point():
	var ctrl = Node.new()
	ctrl.set_script(StoryPlayController)
	add_child_autofree(ctrl)
	var story = _make_story()
	var ch = _make_chapter("Ch1")
	story.chapters.append(ch)
	var sc = _make_scene("Sc1")
	ch.scenes.append(sc)
	var seq_left = _make_sequence("Left", Vector2(100, 100))
	var seq_right = _make_sequence("Right", Vector2(500, 100))
	sc.sequences.append(seq_left)
	sc.sequences.append(seq_right)
	sc.entry_point_uuid = seq_right.uuid
	ctrl.start_play_scene(story, ch, sc)
	assert_eq(ctrl.get_current_sequence(), seq_right)
