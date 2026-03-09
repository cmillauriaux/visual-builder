extends GutTest

var SceneGraphViewScript
var ChapterScript
var SceneDataScript

var _view
var _chapter

func before_each():
	SceneGraphViewScript = load("res://src/views/scene_graph_view.gd")
	ChapterScript = load("res://src/models/chapter.gd")
	SceneDataScript = load("res://src/models/scene_data.gd")
	
	_view = GraphEdit.new()
	_view.set_script(SceneGraphViewScript)
	add_child_autofree(_view)
	_chapter = ChapterScript.new()

func test_load_chapter_empty():
	_view.load_chapter(_chapter)
	assert_eq(_view.get_node_count(), 0)

func test_load_chapter_with_scenes():
	var s1 = SceneDataScript.new()
	s1.scene_name = "S1"
	var s2 = SceneDataScript.new()
	s2.scene_name = "S2"
	_chapter.scenes.append(s1)
	_chapter.scenes.append(s2)
	_view.load_chapter(_chapter)
	assert_eq(_view.get_node_count(), 2)

func test_add_new_scene():
	_view.load_chapter(_chapter)
	_view.add_new_scene("New Scene", Vector2(100, 100))
	assert_eq(_chapter.scenes.size(), 1)
	assert_eq(_view.get_node_count(), 1)

func test_remove_scene():
	var s1 = SceneDataScript.new()
	_chapter.scenes.append(s1)
	_view.load_chapter(_chapter)
	assert_eq(_view.get_node_count(), 1)
	_view.remove_scene(s1.uuid)
	assert_eq(_chapter.scenes.size(), 0)
	assert_eq(_view.get_node_count(), 0)

func test_connection_type_transition():
	var s1 = SceneDataScript.new()
	var s2 = SceneDataScript.new()
	_chapter.scenes.append(s1)
	_chapter.scenes.append(s2)
	_chapter.connections.append({"from": s1.uuid, "to": s2.uuid})
	_view.load_chapter(_chapter)
	assert_eq(_view.get_connection_type(s1.uuid, s2.uuid), "transition")

func test_entry_point_toggle():
	var s1 = SceneDataScript.new()
	_chapter.scenes.append(s1)
	_view.load_chapter(_chapter)
	_view._on_entry_point_toggled(s1.uuid, true)
	assert_eq(_chapter.entry_point_uuid, s1.uuid)
	_view._on_entry_point_toggled(s1.uuid, false)
	assert_eq(_chapter.entry_point_uuid, "")

func test_merge_connection_type():
	_view._merge_connection_type("key", "transition")
	assert_eq(_view._connection_type_map["key"], "transition")
	_view._merge_connection_type("key", "choice")
	assert_eq(_view._connection_type_map["key"], "both")

func test_compute_colors():
	var s1 = SceneDataScript.new()
	var s2 = SceneDataScript.new()
	_chapter.scenes.append(s1)
	_chapter.scenes.append(s2)
	_view.load_chapter(_chapter)
	
	_view._connection_type_map[s1.uuid + "→" + s2.uuid] = "transition"
	var color = _view._compute_outgoing_color(s1.uuid)
	assert_eq(color, _view.COLOR_TRANSITION)
	
	_view._connection_type_map[s1.uuid + "→" + s2.uuid] = "choice"
	color = _view._compute_outgoing_color(s1.uuid)
	assert_eq(color, _view.COLOR_CHOICE)
	
	_view._connection_type_map[s1.uuid + "→" + s2.uuid] = "both"
	color = _view._compute_outgoing_color(s1.uuid)
	assert_eq(color, _view.COLOR_BOTH)
