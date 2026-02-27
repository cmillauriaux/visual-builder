extends GutTest

# Test du rechargement des graphes (détection du bug potentiel avec queue_free)

const Sequence = preload("res://src/models/sequence.gd")
const Ending = preload("res://src/models/ending.gd")
const Consequence = preload("res://src/models/consequence.gd")
const SequenceGraphView = preload("res://src/views/sequence_graph_view.gd")
const SceneGraphView = preload("res://src/views/scene_graph_view.gd")
const ChapterGraphView = preload("res://src/views/chapter_graph_view.gd")
const SceneDataScript = preload("res://src/models/scene_data.gd")
const ChapterScript = preload("res://src/models/chapter.gd")
const StoryScript = preload("res://src/models/story.gd")

func _make_redirect_ending(type: String, target: String) -> Ending:
	var ending = Ending.new()
	ending.type = "auto_redirect"
	var cons = Consequence.new()
	cons.type = type
	cons.target = target
	ending.auto_consequence = cons
	return ending

func _has_connection(graph: GraphEdit, from_uuid: String, to_uuid: String) -> bool:
	for conn in graph.get_connection_list():
		if conn["from_node"] == StringName(from_uuid) and conn["to_node"] == StringName(to_uuid):
			return true
	return false

func test_sequence_graph_reload_preserves_connections():
	# Appeler load_scene() deux fois : les connexions doivent toujours être correctes
	var scene = SceneDataScript.new()
	var seq1 = Sequence.new(); seq1.seq_name = "Seq 1"
	var seq2 = Sequence.new(); seq2.seq_name = "Seq 2"
	scene.sequences.append(seq1)
	scene.sequences.append(seq2)
	seq1.ending = _make_redirect_ending("redirect_sequence", seq2.uuid)

	var graph = GraphEdit.new()
	graph.set_script(SequenceGraphView)
	add_child_autofree(graph)

	# Premier chargement
	graph.load_scene(scene)
	assert_true(_has_connection(graph, seq1.uuid, seq2.uuid),
		"Premier chargement : connexion seq1→seq2 doit exister")

	# Deuxième chargement (simule navigation aller-retour)
	graph.load_scene(scene)
	assert_true(_has_connection(graph, seq1.uuid, seq2.uuid),
		"Deuxième chargement : connexion seq1→seq2 doit toujours exister")

func test_scene_graph_reload_preserves_connections():
	# Appeler load_chapter() deux fois : les connexions doivent toujours être correctes
	var chapter = ChapterScript.new()
	var scene1 = SceneDataScript.new(); scene1.scene_name = "Scène 1"
	var scene2 = SceneDataScript.new(); scene2.scene_name = "Scène 2"
	chapter.scenes.append(scene1)
	chapter.scenes.append(scene2)

	var seq = Sequence.new()
	seq.ending = _make_redirect_ending("redirect_scene", scene2.uuid)
	scene1.sequences.append(seq)

	var graph = GraphEdit.new()
	graph.set_script(SceneGraphView)
	add_child_autofree(graph)

	# Premier chargement
	graph.load_chapter(chapter)
	assert_true(_has_connection(graph, scene1.uuid, scene2.uuid),
		"Premier chargement : connexion scene1→scene2 doit exister")

	# Deuxième chargement
	graph.load_chapter(chapter)
	assert_true(_has_connection(graph, scene1.uuid, scene2.uuid),
		"Deuxième chargement : connexion scene1→scene2 doit toujours exister")

func test_chapter_graph_reload_preserves_connections():
	# Appeler load_story() deux fois : les connexions doivent toujours être correctes
	var story = StoryScript.new()
	var ch1 = ChapterScript.new(); ch1.chapter_name = "Chapitre 1"
	var ch2 = ChapterScript.new(); ch2.chapter_name = "Chapitre 2"
	story.chapters.append(ch1)
	story.chapters.append(ch2)

	var scene = SceneDataScript.new()
	ch1.scenes.append(scene)
	var seq = Sequence.new()
	seq.ending = _make_redirect_ending("redirect_chapter", ch2.uuid)
	scene.sequences.append(seq)

	var graph = GraphEdit.new()
	graph.set_script(ChapterGraphView)
	add_child_autofree(graph)

	# Premier chargement
	graph.load_story(story)
	assert_true(_has_connection(graph, ch1.uuid, ch2.uuid),
		"Premier chargement : connexion ch1→ch2 doit exister")

	# Deuxième chargement
	graph.load_story(story)
	assert_true(_has_connection(graph, ch1.uuid, ch2.uuid),
		"Deuxième chargement : connexion ch1→ch2 doit toujours exister")

func test_sequence_graph_triple_reload():
	# Trois chargements consécutifs
	var scene = SceneDataScript.new()
	var seq1 = Sequence.new(); seq1.seq_name = "Seq 1"
	var seq2 = Sequence.new(); seq2.seq_name = "Seq 2"
	scene.sequences.append(seq1)
	scene.sequences.append(seq2)
	seq1.ending = _make_redirect_ending("redirect_sequence", seq2.uuid)

	var graph = GraphEdit.new()
	graph.set_script(SequenceGraphView)
	add_child_autofree(graph)

	graph.load_scene(scene)
	graph.load_scene(scene)
	graph.load_scene(scene)

	assert_true(_has_connection(graph, seq1.uuid, seq2.uuid),
		"Troisième chargement : connexion seq1→seq2 doit toujours exister")
