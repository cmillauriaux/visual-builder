extends GutTest

# Tests pour la vue graphe des chapitres

const ChapterGraphView = preload("res://src/views/chapter_graph_view.gd")
const Story = preload("res://src/models/story.gd")
const Chapter = preload("res://src/models/chapter.gd")

var _view: GraphEdit = null
var _story = null

func before_each():
	_view = GraphEdit.new()
	_view.set_script(ChapterGraphView)
	add_child_autofree(_view)
	_story = Story.new()
	_story.title = "Test"
	_story.author = "Auteur"

func test_load_empty_story():
	_view.load_story(_story)
	assert_eq(_view.get_node_count(), 0)

func test_load_story_with_chapters():
	var ch1 = Chapter.new()
	ch1.chapter_name = "Chapitre 1"
	ch1.position = Vector2(100, 200)
	var ch2 = Chapter.new()
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
	var ch = Chapter.new()
	ch.chapter_name = "À supprimer"
	_story.chapters.append(ch)
	_view.load_story(_story)
	assert_eq(_view.get_node_count(), 1)
	_view.remove_chapter(ch.uuid)
	assert_eq(_story.chapters.size(), 0)
	assert_eq(_view.get_node_count(), 0)

func test_rename_chapter():
	var ch = Chapter.new()
	ch.chapter_name = "Ancien nom"
	_story.chapters.append(ch)
	_view.load_story(_story)
	_view.rename_chapter(ch.uuid, "Nouveau nom")
	assert_eq(_story.chapters[0].chapter_name, "Nouveau nom")

func test_rename_chapter_with_subtitle():
	var ch = Chapter.new()
	ch.chapter_name = "Ancien nom"
	_story.chapters.append(ch)
	_view.load_story(_story)
	_view.rename_chapter(ch.uuid, "Nouveau nom", "La forêt")
	assert_eq(_story.chapters[0].chapter_name, "Nouveau nom")
	assert_eq(_story.chapters[0].subtitle, "La forêt")

func test_add_connection():
	var ch1 = Chapter.new()
	ch1.chapter_name = "Ch1"
	var ch2 = Chapter.new()
	ch2.chapter_name = "Ch2"
	_story.chapters.append(ch1)
	_story.chapters.append(ch2)
	_view.load_story(_story)
	_view.add_story_connection(ch1.uuid, ch2.uuid)
	assert_eq(_story.connections.size(), 1)
	assert_eq(_story.connections[0]["from"], ch1.uuid)
	assert_eq(_story.connections[0]["to"], ch2.uuid)

func test_get_story():
	_view.load_story(_story)
	assert_eq(_view.get_story(), _story)

func test_load_story_with_subtitles():
	var ch = Chapter.new()
	ch.chapter_name = "Chapitre 1"
	ch.subtitle = "Le début"
	ch.position = Vector2(100, 200)
	_story.chapters.append(ch)
	_view.load_story(_story)
	assert_eq(_view.get_node_count(), 1)

func test_chapter_rename_requested_signal():
	var ch = Chapter.new()
	ch.chapter_name = "Chapitre 1"
	_story.chapters.append(ch)
	_view.load_story(_story)
	watch_signals(_view)
	_view._on_node_rename_requested(ch.uuid)
	assert_signal_emitted(_view, "chapter_rename_requested")

func test_node_positions_update_model():
	var ch = Chapter.new()
	ch.chapter_name = "Test"
	ch.position = Vector2(100, 200)
	_story.chapters.append(ch)
	_view.load_story(_story)
	_view.sync_positions_to_model()
	# Les positions dans le modèle doivent refléter les noeuds du graphe
	assert_eq(_story.chapters[0].position, Vector2(100, 200))
