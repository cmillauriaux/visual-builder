extends GutTest

# Tests pour la colorisation des connexions selon leur type

const Sequence = preload("res://src/models/sequence.gd")
const Ending = preload("res://src/models/ending.gd")
const Consequence = preload("res://src/models/consequence.gd")
const ChoiceScript = preload("res://src/models/choice.gd")
const SequenceGraphView = preload("res://src/views/sequence_graph_view.gd")
const SceneGraphView = preload("res://src/views/scene_graph_view.gd")
const ChapterGraphView = preload("res://src/views/chapter_graph_view.gd")
const SceneDataScript = preload("res://src/models/scene_data.gd")
const ChapterScript = preload("res://src/models/chapter.gd")
const StoryScript = preload("res://src/models/story.gd")

const COLOR_TRANSITION = Color.WHITE
const COLOR_CHOICE = Color(0.0, 0.9, 0.2)
const COLOR_BOTH = Color(1.0, 0.85, 0.0)

# --- Helpers ---

func _make_redirect_ending(type: String, target: String) -> Ending:
	var ending = Ending.new()
	ending.type = "auto_redirect"
	var cons = Consequence.new()
	cons.type = type
	cons.target = target
	ending.auto_consequence = cons
	return ending

func _make_choices_ending(targets: Array) -> Ending:
	var ending = Ending.new()
	ending.type = "choices"
	for t in targets:
		var cons = Consequence.new()
		cons.type = t["type"]
		cons.target = t["target"]
		var choice = ChoiceScript.new()
		choice.text = "Choix"
		choice.consequence = cons
		ending.choices.append(choice)
	return ending

func _make_seq_graph(scene) -> GraphEdit:
	var graph = GraphEdit.new()
	graph.set_script(SequenceGraphView)
	add_child_autofree(graph)
	graph.load_scene(scene)
	return graph

func _make_scene_graph(chapter) -> GraphEdit:
	var graph = GraphEdit.new()
	graph.set_script(SceneGraphView)
	add_child_autofree(graph)
	graph.load_chapter(chapter)
	return graph

func _make_chapter_graph(story) -> GraphEdit:
	var graph = GraphEdit.new()
	graph.set_script(ChapterGraphView)
	add_child_autofree(graph)
	graph.load_story(story)
	return graph

# ============================================================
# Tests get_connection_type — niveau SÉQUENCES
# ============================================================

func test_seq_transition_type():
	var scene = SceneDataScript.new()
	var seq1 = Sequence.new(); seq1.seq_name = "Seq 1"
	var seq2 = Sequence.new(); seq2.seq_name = "Seq 2"
	scene.sequences.append(seq1)
	scene.sequences.append(seq2)
	seq1.ending = _make_redirect_ending("redirect_sequence", seq2.uuid)

	var graph = _make_seq_graph(scene)

	assert_eq(graph.get_connection_type(seq1.uuid, seq2.uuid), "transition",
		"auto_redirect → type transition")

func test_seq_choice_type():
	var scene = SceneDataScript.new()
	var seq1 = Sequence.new(); seq1.seq_name = "Seq 1"
	var seq2 = Sequence.new(); seq2.seq_name = "Seq 2"
	scene.sequences.append(seq1)
	scene.sequences.append(seq2)
	seq1.ending = _make_choices_ending([{"type": "redirect_sequence", "target": seq2.uuid}])

	var graph = _make_seq_graph(scene)

	assert_eq(graph.get_connection_type(seq1.uuid, seq2.uuid), "choice",
		"choices → type choice")

func test_seq_manual_connection_is_transition():
	var scene = SceneDataScript.new()
	var seq1 = Sequence.new(); seq1.seq_name = "Seq 1"
	var seq2 = Sequence.new(); seq2.seq_name = "Seq 2"
	scene.sequences.append(seq1)
	scene.sequences.append(seq2)
	scene.connections.append({"from": seq1.uuid, "to": seq2.uuid})

	var graph = _make_seq_graph(scene)

	assert_eq(graph.get_connection_type(seq1.uuid, seq2.uuid), "transition",
		"connexion manuelle → type transition")

func test_seq_manual_plus_choice_is_both():
	# Connexion manuelle (transition) + ending choices vers la même cible → both
	var scene = SceneDataScript.new()
	var seq1 = Sequence.new(); seq1.seq_name = "Seq 1"
	var seq2 = Sequence.new(); seq2.seq_name = "Seq 2"
	scene.sequences.append(seq1)
	scene.sequences.append(seq2)
	scene.connections.append({"from": seq1.uuid, "to": seq2.uuid})
	seq1.ending = _make_choices_ending([{"type": "redirect_sequence", "target": seq2.uuid}])

	var graph = _make_seq_graph(scene)

	assert_eq(graph.get_connection_type(seq1.uuid, seq2.uuid), "both",
		"connexion manuelle + choices vers même cible → type both")

func test_seq_unknown_connection_returns_empty():
	var scene = SceneDataScript.new()
	var seq1 = Sequence.new(); seq1.seq_name = "Seq 1"
	var seq2 = Sequence.new(); seq2.seq_name = "Seq 2"
	scene.sequences.append(seq1)
	scene.sequences.append(seq2)

	var graph = _make_seq_graph(scene)

	assert_eq(graph.get_connection_type(seq1.uuid, seq2.uuid), "",
		"paire non connectée → chaîne vide")

# ============================================================
# Tests get_connection_type — niveau SCÈNES
# ============================================================

func test_scene_auto_redirect_is_transition():
	var chapter = ChapterScript.new()
	var scene1 = SceneDataScript.new(); scene1.scene_name = "Scene 1"
	var scene2 = SceneDataScript.new(); scene2.scene_name = "Scene 2"
	chapter.scenes.append(scene1)
	chapter.scenes.append(scene2)
	var seq = Sequence.new()
	seq.ending = _make_redirect_ending("redirect_scene", scene2.uuid)
	scene1.sequences.append(seq)

	var graph = _make_scene_graph(chapter)

	assert_eq(graph.get_connection_type(scene1.uuid, scene2.uuid), "transition",
		"auto_redirect → type transition au niveau scène")

func test_scene_choices_is_choice():
	var chapter = ChapterScript.new()
	var scene1 = SceneDataScript.new(); scene1.scene_name = "Scene 1"
	var scene2 = SceneDataScript.new(); scene2.scene_name = "Scene 2"
	chapter.scenes.append(scene1)
	chapter.scenes.append(scene2)
	var seq = Sequence.new()
	seq.ending = _make_choices_ending([{"type": "redirect_scene", "target": scene2.uuid}])
	scene1.sequences.append(seq)

	var graph = _make_scene_graph(chapter)

	assert_eq(graph.get_connection_type(scene1.uuid, scene2.uuid), "choice",
		"choices → type choice au niveau scène")

func test_scene_mixed_endings_is_both():
	# seq1=auto_redirect et seq2=choices → même paire (scene1→scene2) → both
	var chapter = ChapterScript.new()
	var scene1 = SceneDataScript.new(); scene1.scene_name = "Scene 1"
	var scene2 = SceneDataScript.new(); scene2.scene_name = "Scene 2"
	chapter.scenes.append(scene1)
	chapter.scenes.append(scene2)

	var seq1 = Sequence.new()
	seq1.ending = _make_redirect_ending("redirect_scene", scene2.uuid)
	scene1.sequences.append(seq1)

	var seq2 = Sequence.new()
	seq2.ending = _make_choices_ending([{"type": "redirect_scene", "target": scene2.uuid}])
	scene1.sequences.append(seq2)

	var graph = _make_scene_graph(chapter)

	assert_eq(graph.get_connection_type(scene1.uuid, scene2.uuid), "both",
		"séquences mixtes (auto_redirect + choices) vers même scène → type both")
	# Un seul lien malgré les deux sources
	var count = 0
	for conn in graph.get_connection_list():
		if conn["from_node"] == StringName(scene1.uuid) and conn["to_node"] == StringName(scene2.uuid):
			count += 1
	assert_eq(count, 1, "un seul lien graphique malgré les deux sources")

func test_scene_manual_plus_choices_is_both():
	var chapter = ChapterScript.new()
	var scene1 = SceneDataScript.new(); scene1.scene_name = "Scene 1"
	var scene2 = SceneDataScript.new(); scene2.scene_name = "Scene 2"
	chapter.scenes.append(scene1)
	chapter.scenes.append(scene2)
	chapter.connections.append({"from": scene1.uuid, "to": scene2.uuid})

	var seq = Sequence.new()
	seq.ending = _make_choices_ending([{"type": "redirect_scene", "target": scene2.uuid}])
	scene1.sequences.append(seq)

	var graph = _make_scene_graph(chapter)

	assert_eq(graph.get_connection_type(scene1.uuid, scene2.uuid), "both",
		"connexion manuelle + choices → type both au niveau scène")

# ============================================================
# Tests get_connection_type — niveau CHAPITRES
# ============================================================

func test_chapter_auto_redirect_is_transition():
	var story = StoryScript.new()
	var ch1 = ChapterScript.new(); ch1.chapter_name = "Chap 1"
	var ch2 = ChapterScript.new(); ch2.chapter_name = "Chap 2"
	story.chapters.append(ch1)
	story.chapters.append(ch2)
	var scene = SceneDataScript.new()
	ch1.scenes.append(scene)
	var seq = Sequence.new()
	seq.ending = _make_redirect_ending("redirect_chapter", ch2.uuid)
	scene.sequences.append(seq)

	var graph = _make_chapter_graph(story)

	assert_eq(graph.get_connection_type(ch1.uuid, ch2.uuid), "transition",
		"auto_redirect → type transition au niveau chapitre")

func test_chapter_choices_is_choice():
	var story = StoryScript.new()
	var ch1 = ChapterScript.new(); ch1.chapter_name = "Chap 1"
	var ch2 = ChapterScript.new(); ch2.chapter_name = "Chap 2"
	story.chapters.append(ch1)
	story.chapters.append(ch2)
	var scene = SceneDataScript.new()
	ch1.scenes.append(scene)
	var seq = Sequence.new()
	seq.ending = _make_choices_ending([{"type": "redirect_chapter", "target": ch2.uuid}])
	scene.sequences.append(seq)

	var graph = _make_chapter_graph(story)

	assert_eq(graph.get_connection_type(ch1.uuid, ch2.uuid), "choice",
		"choices → type choice au niveau chapitre")

func test_chapter_mixed_endings_is_both():
	var story = StoryScript.new()
	var ch1 = ChapterScript.new(); ch1.chapter_name = "Chap 1"
	var ch2 = ChapterScript.new(); ch2.chapter_name = "Chap 2"
	story.chapters.append(ch1)
	story.chapters.append(ch2)

	var scene1 = SceneDataScript.new()
	ch1.scenes.append(scene1)
	var seq1 = Sequence.new()
	seq1.ending = _make_redirect_ending("redirect_chapter", ch2.uuid)
	scene1.sequences.append(seq1)

	var scene2 = SceneDataScript.new()
	ch1.scenes.append(scene2)
	var seq2 = Sequence.new()
	seq2.ending = _make_choices_ending([{"type": "redirect_chapter", "target": ch2.uuid}])
	scene2.sequences.append(seq2)

	var graph = _make_chapter_graph(story)

	assert_eq(graph.get_connection_type(ch1.uuid, ch2.uuid), "both",
		"séquences mixtes → type both au niveau chapitre")

# ============================================================
# Tests couleurs des ports — niveau SÉQUENCES
# ============================================================

func _get_node_by_uuid(graph: GraphEdit, uuid: String) -> GraphNode:
	for child in graph.get_children():
		if child is GraphNode and child.name == StringName(uuid):
			return child
	return null

func test_seq_transition_right_port_is_white():
	var scene = SceneDataScript.new()
	var seq1 = Sequence.new(); seq1.seq_name = "Seq 1"
	var seq2 = Sequence.new(); seq2.seq_name = "Seq 2"
	scene.sequences.append(seq1)
	scene.sequences.append(seq2)
	seq1.ending = _make_redirect_ending("redirect_sequence", seq2.uuid)

	var graph = _make_seq_graph(scene)
	var node1 = _get_node_by_uuid(graph, seq1.uuid)

	assert_not_null(node1, "nœud seq1 existe")
	assert_eq(node1.get_slot_color_right(0), COLOR_TRANSITION,
		"port droit blanc pour connexion de type transition")

func test_seq_choice_right_port_is_green():
	var scene = SceneDataScript.new()
	var seq1 = Sequence.new(); seq1.seq_name = "Seq 1"
	var seq2 = Sequence.new(); seq2.seq_name = "Seq 2"
	scene.sequences.append(seq1)
	scene.sequences.append(seq2)
	seq1.ending = _make_choices_ending([{"type": "redirect_sequence", "target": seq2.uuid}])

	var graph = _make_seq_graph(scene)
	var node1 = _get_node_by_uuid(graph, seq1.uuid)

	assert_not_null(node1, "nœud seq1 existe")
	assert_eq(node1.get_slot_color_right(0), COLOR_CHOICE,
		"port droit vert pour connexion de type choice")

func test_seq_both_right_port_is_yellow():
	var scene = SceneDataScript.new()
	var seq1 = Sequence.new(); seq1.seq_name = "Seq 1"
	var seq2 = Sequence.new(); seq2.seq_name = "Seq 2"
	scene.sequences.append(seq1)
	scene.sequences.append(seq2)
	scene.connections.append({"from": seq1.uuid, "to": seq2.uuid})
	seq1.ending = _make_choices_ending([{"type": "redirect_sequence", "target": seq2.uuid}])

	var graph = _make_seq_graph(scene)
	var node1 = _get_node_by_uuid(graph, seq1.uuid)

	assert_not_null(node1, "nœud seq1 existe")
	assert_eq(node1.get_slot_color_right(0), COLOR_BOTH,
		"port droit jaune pour connexion de type both")

func test_seq_no_outgoing_port_is_white():
	var scene = SceneDataScript.new()
	var seq1 = Sequence.new(); seq1.seq_name = "Seq 1"
	scene.sequences.append(seq1)

	var graph = _make_seq_graph(scene)
	var node1 = _get_node_by_uuid(graph, seq1.uuid)

	assert_not_null(node1, "nœud seq1 existe")
	assert_eq(node1.get_slot_color_right(0), COLOR_TRANSITION,
		"port droit blanc si aucune connexion sortante")

func test_seq_choice_incoming_left_port_is_green():
	var scene = SceneDataScript.new()
	var seq1 = Sequence.new(); seq1.seq_name = "Seq 1"
	var seq2 = Sequence.new(); seq2.seq_name = "Seq 2"
	scene.sequences.append(seq1)
	scene.sequences.append(seq2)
	seq1.ending = _make_choices_ending([{"type": "redirect_sequence", "target": seq2.uuid}])

	var graph = _make_seq_graph(scene)
	var node2 = _get_node_by_uuid(graph, seq2.uuid)

	assert_not_null(node2, "nœud seq2 existe")
	assert_eq(node2.get_slot_color_left(0), COLOR_CHOICE,
		"port gauche vert si connexion entrante de type choice")

func test_seq_mixed_incoming_left_port_is_yellow():
	# seq1 (auto_redirect) → seq3 et seq2 (choices) → seq3 → left port de seq3 = yellow
	var scene = SceneDataScript.new()
	var seq1 = Sequence.new(); seq1.seq_name = "Seq 1"
	var seq2 = Sequence.new(); seq2.seq_name = "Seq 2"
	var seq3 = Sequence.new(); seq3.seq_name = "Seq 3"
	scene.sequences.append(seq1)
	scene.sequences.append(seq2)
	scene.sequences.append(seq3)
	seq1.ending = _make_redirect_ending("redirect_sequence", seq3.uuid)
	seq2.ending = _make_choices_ending([{"type": "redirect_sequence", "target": seq3.uuid}])

	var graph = _make_seq_graph(scene)
	var node3 = _get_node_by_uuid(graph, seq3.uuid)

	assert_not_null(node3, "nœud seq3 existe")
	assert_eq(node3.get_slot_color_left(0), COLOR_BOTH,
		"port gauche jaune si connexions entrantes mixtes (transition + choice)")

# ============================================================
# Tests couleurs des ports — niveau SCÈNES
# ============================================================

func test_scene_both_right_port_is_yellow():
	var chapter = ChapterScript.new()
	var scene1 = SceneDataScript.new(); scene1.scene_name = "Scene 1"
	var scene2 = SceneDataScript.new(); scene2.scene_name = "Scene 2"
	chapter.scenes.append(scene1)
	chapter.scenes.append(scene2)

	var seq1 = Sequence.new()
	seq1.ending = _make_redirect_ending("redirect_scene", scene2.uuid)
	scene1.sequences.append(seq1)

	var seq2 = Sequence.new()
	seq2.ending = _make_choices_ending([{"type": "redirect_scene", "target": scene2.uuid}])
	scene1.sequences.append(seq2)

	var graph = _make_scene_graph(chapter)
	var node1 = _get_node_by_uuid(graph, scene1.uuid)

	assert_not_null(node1, "nœud scene1 existe")
	assert_eq(node1.get_slot_color_right(0), COLOR_BOTH,
		"port droit jaune pour connexion de type both au niveau scène")
