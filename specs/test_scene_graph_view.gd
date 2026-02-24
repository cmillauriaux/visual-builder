extends GutTest

# Tests pour la vue graphe des scènes

const SceneGraphView = preload("res://src/views/scene_graph_view.gd")
const Chapter = preload("res://src/models/chapter.gd")
const SceneData = preload("res://src/models/scene_data.gd")

var _view: GraphEdit = null
var _chapter = null

func before_each():
	_view = GraphEdit.new()
	_view.set_script(SceneGraphView)
	add_child_autofree(_view)
	_chapter = Chapter.new()
	_chapter.chapter_name = "Chapitre Test"

func test_load_empty_chapter():
	_view.load_chapter(_chapter)
	assert_eq(_view.get_node_count(), 0)

func test_load_chapter_with_scenes():
	var s1 = SceneData.new()
	s1.scene_name = "Scène 1"
	var s2 = SceneData.new()
	s2.scene_name = "Scène 2"
	_chapter.scenes.append(s1)
	_chapter.scenes.append(s2)
	_view.load_chapter(_chapter)
	assert_eq(_view.get_node_count(), 2)

func test_add_scene():
	_view.load_chapter(_chapter)
	_view.add_new_scene("Nouvelle Scène", Vector2(200, 100))
	assert_eq(_chapter.scenes.size(), 1)
	assert_eq(_chapter.scenes[0].scene_name, "Nouvelle Scène")

func test_remove_scene():
	var s = SceneData.new()
	s.scene_name = "À supprimer"
	_chapter.scenes.append(s)
	_view.load_chapter(_chapter)
	_view.remove_scene(s.uuid)
	assert_eq(_chapter.scenes.size(), 0)

func test_rename_scene():
	var s = SceneData.new()
	s.scene_name = "Ancien"
	_chapter.scenes.append(s)
	_view.load_chapter(_chapter)
	_view.rename_scene(s.uuid, "Nouveau")
	assert_eq(_chapter.scenes[0].scene_name, "Nouveau")

func test_get_chapter():
	_view.load_chapter(_chapter)
	assert_eq(_view.get_chapter(), _chapter)
