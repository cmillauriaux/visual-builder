extends GutTest

## Tests du bouton de création contextuel (spec 002).

const EditorMainScript = preload("res://src/ui/editor_main.gd")
const StoryScript = preload("res://src/models/story.gd")
const ChapterScript = preload("res://src/models/chapter.gd")
const SceneDataScript = preload("res://src/models/scene_data.gd")
const SequenceScript = preload("res://src/models/sequence.gd")
const ChapterGraphViewScript = preload("res://src/views/chapter_graph_view.gd")
const SceneGraphViewScript = preload("res://src/views/scene_graph_view.gd")
const SequenceGraphViewScript = preload("res://src/views/sequence_graph_view.gd")

var _editor_main: Control
var _story

func before_each():
	_editor_main = Control.new()
	_editor_main.set_script(EditorMainScript)

	_story = StoryScript.new()
	_story.title = "Test"
	_story.author = "Auteur"

func after_each():
	if is_instance_valid(_editor_main):
		_editor_main.free()

# --- Label contextuel ---

func test_label_chapters_level():
	_editor_main.open_story(_story)
	assert_eq(_editor_main.get_create_button_label(), "+ Nouveau chapitre")

func test_label_scenes_level():
	var chapter = ChapterScript.new()
	chapter.chapter_name = "Ch1"
	_story.chapters.append(chapter)
	_editor_main.open_story(_story)
	_editor_main.navigate_to_chapter(chapter.uuid)
	assert_eq(_editor_main.get_create_button_label(), "+ Nouvelle scène")

func test_label_sequences_level():
	var chapter = ChapterScript.new()
	chapter.chapter_name = "Ch1"
	var scene = SceneDataScript.new()
	scene.scene_name = "Sc1"
	chapter.scenes.append(scene)
	_story.chapters.append(chapter)
	_editor_main.open_story(_story)
	_editor_main.navigate_to_chapter(chapter.uuid)
	_editor_main.navigate_to_scene(scene.uuid)
	assert_eq(_editor_main.get_create_button_label(), "+ Nouvelle séquence")

# --- Visibilité ---

func test_hidden_when_no_story():
	assert_false(_editor_main.is_create_button_visible())

func test_visible_at_chapters_level():
	_editor_main.open_story(_story)
	assert_true(_editor_main.is_create_button_visible())

func test_visible_at_scenes_level():
	var chapter = ChapterScript.new()
	_story.chapters.append(chapter)
	_editor_main.open_story(_story)
	_editor_main.navigate_to_chapter(chapter.uuid)
	assert_true(_editor_main.is_create_button_visible())

func test_visible_at_sequences_level():
	var chapter = ChapterScript.new()
	var scene = SceneDataScript.new()
	chapter.scenes.append(scene)
	_story.chapters.append(chapter)
	_editor_main.open_story(_story)
	_editor_main.navigate_to_chapter(chapter.uuid)
	_editor_main.navigate_to_scene(scene.uuid)
	assert_true(_editor_main.is_create_button_visible())

func test_hidden_at_sequence_edit_level():
	var chapter = ChapterScript.new()
	var scene = SceneDataScript.new()
	var seq = SequenceScript.new()
	scene.sequences.append(seq)
	chapter.scenes.append(scene)
	_story.chapters.append(chapter)
	_editor_main.open_story(_story)
	_editor_main.navigate_to_chapter(chapter.uuid)
	_editor_main.navigate_to_scene(scene.uuid)
	_editor_main.navigate_to_sequence(seq.uuid)
	assert_false(_editor_main.is_create_button_visible())

# --- Calcul de position ---

func test_next_position_empty_graph():
	assert_eq(_editor_main.compute_next_position([]), Vector2(100, 100))

func test_next_position_one_item():
	var chapter = ChapterScript.new()
	chapter.position = Vector2(100, 100)
	assert_eq(_editor_main.compute_next_position([chapter]), Vector2(400, 100))

func test_next_position_multiple_items():
	var ch1 = ChapterScript.new()
	ch1.position = Vector2(100, 200)
	var ch2 = ChapterScript.new()
	ch2.position = Vector2(500, 150)
	var ch3 = ChapterScript.new()
	ch3.position = Vector2(300, 100)
	assert_eq(_editor_main.compute_next_position([ch1, ch2, ch3]), Vector2(800, 100))

# --- Calcul de nom auto-incrémenté ---

func test_next_name_chapter_empty():
	_editor_main.open_story(_story)
	assert_eq(_editor_main.get_next_item_name(), "Chapitre 1")

func test_next_name_chapter_with_existing():
	var ch1 = ChapterScript.new()
	var ch2 = ChapterScript.new()
	_story.chapters.append(ch1)
	_story.chapters.append(ch2)
	_editor_main.open_story(_story)
	assert_eq(_editor_main.get_next_item_name(), "Chapitre 3")

func test_next_name_scene_empty():
	var chapter = ChapterScript.new()
	_story.chapters.append(chapter)
	_editor_main.open_story(_story)
	_editor_main.navigate_to_chapter(chapter.uuid)
	assert_eq(_editor_main.get_next_item_name(), "Scène 1")

func test_next_name_scene_with_existing():
	var chapter = ChapterScript.new()
	var sc1 = SceneDataScript.new()
	chapter.scenes.append(sc1)
	_story.chapters.append(chapter)
	_editor_main.open_story(_story)
	_editor_main.navigate_to_chapter(chapter.uuid)
	assert_eq(_editor_main.get_next_item_name(), "Scène 2")

func test_next_name_sequence_empty():
	var chapter = ChapterScript.new()
	var scene = SceneDataScript.new()
	chapter.scenes.append(scene)
	_story.chapters.append(chapter)
	_editor_main.open_story(_story)
	_editor_main.navigate_to_chapter(chapter.uuid)
	_editor_main.navigate_to_scene(scene.uuid)
	assert_eq(_editor_main.get_next_item_name(), "Séquence 1")

func test_next_name_sequence_with_existing():
	var chapter = ChapterScript.new()
	var scene = SceneDataScript.new()
	var seq1 = SequenceScript.new()
	var seq2 = SequenceScript.new()
	scene.sequences.append(seq1)
	scene.sequences.append(seq2)
	chapter.scenes.append(scene)
	_story.chapters.append(chapter)
	_editor_main.open_story(_story)
	_editor_main.navigate_to_chapter(chapter.uuid)
	_editor_main.navigate_to_scene(scene.uuid)
	assert_eq(_editor_main.get_next_item_name(), "Séquence 3")

# --- Label mis à jour lors de la navigation ---

func test_label_updates_on_navigation():
	var chapter = ChapterScript.new()
	var scene = SceneDataScript.new()
	chapter.scenes.append(scene)
	_story.chapters.append(chapter)
	_editor_main.open_story(_story)
	assert_eq(_editor_main.get_create_button_label(), "+ Nouveau chapitre")
	_editor_main.navigate_to_chapter(chapter.uuid)
	assert_eq(_editor_main.get_create_button_label(), "+ Nouvelle scène")
	_editor_main.navigate_to_scene(scene.uuid)
	assert_eq(_editor_main.get_create_button_label(), "+ Nouvelle séquence")
	_editor_main.navigate_back()
	assert_eq(_editor_main.get_create_button_label(), "+ Nouvelle scène")
	_editor_main.navigate_back()
	assert_eq(_editor_main.get_create_button_label(), "+ Nouveau chapitre")

# --- Création effective via les vues graphe ---

func test_create_chapter_in_graph():
	_editor_main.open_story(_story)
	var graph = GraphEdit.new()
	graph.set_script(ChapterGraphViewScript)
	add_child(graph)
	graph.load_story(_story)

	var name = _editor_main.get_next_item_name()
	var pos = _editor_main.compute_next_position(_story.chapters)
	graph.add_new_chapter(name, pos)

	assert_eq(_story.chapters.size(), 1)
	assert_eq(_story.chapters[0].chapter_name, "Chapitre 1")
	assert_eq(_story.chapters[0].position, Vector2(100, 100))
	assert_eq(graph.get_node_count(), 1)

	graph.queue_free()

func test_create_scene_in_graph():
	var chapter = ChapterScript.new()
	_story.chapters.append(chapter)
	_editor_main.open_story(_story)
	_editor_main.navigate_to_chapter(chapter.uuid)

	var graph = GraphEdit.new()
	graph.set_script(SceneGraphViewScript)
	add_child(graph)
	graph.load_chapter(chapter)

	var name = _editor_main.get_next_item_name()
	var pos = _editor_main.compute_next_position(chapter.scenes)
	graph.add_new_scene(name, pos)

	assert_eq(chapter.scenes.size(), 1)
	assert_eq(chapter.scenes[0].scene_name, "Scène 1")
	assert_eq(chapter.scenes[0].position, Vector2(100, 100))
	assert_eq(graph.get_node_count(), 1)

	graph.queue_free()

func test_create_sequence_in_graph():
	var chapter = ChapterScript.new()
	var scene = SceneDataScript.new()
	chapter.scenes.append(scene)
	_story.chapters.append(chapter)
	_editor_main.open_story(_story)
	_editor_main.navigate_to_chapter(chapter.uuid)
	_editor_main.navigate_to_scene(scene.uuid)

	var graph = GraphEdit.new()
	graph.set_script(SequenceGraphViewScript)
	add_child(graph)
	graph.load_scene(scene)

	var name = _editor_main.get_next_item_name()
	var pos = _editor_main.compute_next_position(scene.sequences)
	graph.add_new_sequence(name, pos)

	assert_eq(scene.sequences.size(), 1)
	assert_eq(scene.sequences[0].seq_name, "Séquence 1")
	assert_eq(scene.sequences[0].position, Vector2(100, 100))
	assert_eq(graph.get_node_count(), 1)

	graph.queue_free()

func test_create_second_chapter_offset():
	var ch1 = ChapterScript.new()
	ch1.chapter_name = "Chapitre 1"
	ch1.position = Vector2(100, 100)
	_story.chapters.append(ch1)
	_editor_main.open_story(_story)

	var graph = GraphEdit.new()
	graph.set_script(ChapterGraphViewScript)
	add_child(graph)
	graph.load_story(_story)

	var name = _editor_main.get_next_item_name()
	var pos = _editor_main.compute_next_position(_story.chapters)
	graph.add_new_chapter(name, pos)

	assert_eq(_story.chapters.size(), 2)
	assert_eq(_story.chapters[1].chapter_name, "Chapitre 2")
	assert_eq(_story.chapters[1].position, Vector2(400, 100))

	graph.queue_free()
