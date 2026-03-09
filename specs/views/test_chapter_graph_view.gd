extends GutTest

# Tests pour la vue graphe des chapitres

var ChapterGraphViewScript
var StoryScript
var ChapterScript

var _view: GraphEdit = null
var _story = null

func before_each():
	ChapterGraphViewScript = load("res://src/views/chapter_graph_view.gd")
	StoryScript = load("res://src/models/story.gd")
	ChapterScript = load("res://src/models/chapter.gd")
	
	_view = GraphEdit.new()
	_view.set_script(ChapterGraphViewScript)
	add_child_autofree(_view)
	_story = StoryScript.new()
	_story.title = "Test"
	_story.author = "Auteur"

func test_load_empty_story():
	_view.load_story(_story)
	assert_eq(_view.get_node_count(), 0)

func test_load_story_with_chapters():
	var ch1 = ChapterScript.new()
	ch1.chapter_name = "Chapitre 1"
	ch1.position = Vector2(100, 200)
	var ch2 = ChapterScript.new()
	ch2.chapter_name = "Chapitre 2"
	ch2.position = Vector2(400, 200)
	_story.chapters.append(ch1)
	_story.chapters.append(ch2)
	_view.load_story(_story)
	assert_eq(_view.get_node_count(), 2)

func test_add_chapter():
	_view.load_story(_story)
	_view.add_new_chapter("Nouveau Chapitre", Vector2(300, 100))
	assert_eq(_story.chapters.size(), 1)
	assert_eq(_story.chapters[0].chapter_name, "Nouveau Chapitre")
	assert_eq(_view.get_node_count(), 1)

func test_remove_chapter():
	var ch = ChapterScript.new()
	ch.chapter_name = "À supprimer"
	_story.chapters.append(ch)
	_view.load_story(_story)
	assert_eq(_view.get_node_count(), 1)
	_view.remove_chapter(ch.uuid)
	assert_eq(_story.chapters.size(), 0)
	assert_eq(_view.get_node_count(), 0)

func test_rename_chapter():
	var ch = ChapterScript.new()
	ch.chapter_name = "Ancien nom"
	_story.chapters.append(ch)
	_view.load_story(_story)
	_view.rename_chapter(ch.uuid, "Nouveau nom")
	assert_eq(_story.chapters[0].chapter_name, "Nouveau nom")

func test_add_connection():
	var ch1 = ChapterScript.new()
	var ch2 = ChapterScript.new()
	_story.chapters.append(ch1)
	_story.chapters.append(ch2)
	_view.load_story(_story)
	_view.add_story_connection(ch1.uuid, ch2.uuid)
	assert_eq(_story.connections.size(), 1)
	assert_eq(_story.connections[0]["from"], ch1.uuid)
	assert_eq(_story.connections[0]["to"], ch2.uuid)

func test_remove_connection():
	var ch1 = ChapterScript.new()
	var ch2 = ChapterScript.new()
	_story.chapters.append(ch1)
	_story.chapters.append(ch2)
	_story.connections.append({"from": ch1.uuid, "to": ch2.uuid})
	_view.load_story(_story)
	_view.remove_story_connection(ch1.uuid, ch2.uuid)
	assert_eq(_story.connections.size(), 0)

func test_clear_graph():
	var ch1 = ChapterScript.new()
	_story.chapters.append(ch1)
	_view.load_story(_story)
	assert_eq(_view.get_node_count(), 1)
	_view.clear_graph()
	assert_eq(_view.get_node_count(), 0)

func test_get_chapter_by_uuid():
	var ch = ChapterScript.new()
	_story.chapters.append(ch)
	_view.load_story(_story)
	var found = _view.get_chapter_by_uuid(ch.uuid)
	assert_eq(found, ch)
	assert_null(_view.get_chapter_by_uuid("invalid"))
