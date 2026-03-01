extends GutTest

# Tests complets pour l'affichage des liens dans les graphes

const Sequence = preload("res://src/models/sequence.gd")
const Ending = preload("res://src/models/ending.gd")
const Consequence = preload("res://src/models/consequence.gd")
const ChoiceScript = preload("res://src/models/choice.gd")
const ConditionScript = preload("res://src/models/condition.gd")
const ConditionRuleScript = preload("res://src/models/condition_rule.gd")
const SequenceGraphView = preload("res://src/views/sequence_graph_view.gd")
const SceneGraphView = preload("res://src/views/scene_graph_view.gd")
const ChapterGraphView = preload("res://src/views/chapter_graph_view.gd")
const SceneDataScript = preload("res://src/models/scene_data.gd")
const ChapterScript = preload("res://src/models/chapter.gd")
const StoryScript = preload("res://src/models/story.gd")

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
	# targets: Array of {type, target}
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

func _has_connection(graph: GraphEdit, from_uuid: String, to_uuid: String) -> bool:
	for conn in graph.get_connection_list():
		if conn["from_node"] == StringName(from_uuid) and conn["to_node"] == StringName(to_uuid):
			return true
	return false

func _count_connections(graph: GraphEdit, from_uuid: String, to_uuid: String) -> int:
	var count = 0
	for conn in graph.get_connection_list():
		if conn["from_node"] == StringName(from_uuid) and conn["to_node"] == StringName(to_uuid):
			count += 1
	return count

func _make_condition_with_rule(consequence_type: String, target: String) -> ConditionScript:
	var cond = ConditionScript.new()
	var rule = ConditionRuleScript.new()
	rule.variable = "x"
	rule.operator = "equal"
	rule.value = "1"
	var cons = Consequence.new()
	cons.type = consequence_type
	cons.target = target
	rule.consequence = cons
	cond.rules.append(rule)
	return cond

# ============================================================
# Tests du graphe de SÉQUENCES
# ============================================================

func test_seq_graph_redirect_sequence_shows_connection():
	# Une terminaison redirect_sequence doit créer un lien dans le graphe de séquences
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

	assert_true(_has_connection(graph, seq1.uuid, seq2.uuid),
		"redirect_sequence doit créer un lien seq1→seq2 dans le graphe de séquences")

func test_seq_graph_redirect_scene_shows_terminal_node():
	# Une terminaison redirect_scene doit créer un lien vers un nœud terminal dans le graphe
	var scene = SceneDataScript.new()
	var seq1 = Sequence.new(); seq1.seq_name = "Seq 1"
	var seq2 = Sequence.new(); seq2.seq_name = "Seq 2"
	scene.sequences.append(seq1)
	scene.sequences.append(seq2)
	seq1.ending = _make_redirect_ending("redirect_scene", "fake-scene-uuid")

	var graph = GraphEdit.new()
	graph.set_script(SequenceGraphView)
	add_child_autofree(graph)
	graph.load_scene(scene)

	assert_eq(graph.get_connection_list().size(), 1,
		"redirect_scene doit créer un lien vers le nœud terminal dans le graphe de séquences")
	assert_true(_has_connection(graph, seq1.uuid, "terminal_redirect_scene"),
		"redirect_scene doit connecter seq1 au nœud terminal 'redirect_scene'")

func test_seq_graph_redirect_chapter_shows_terminal_node():
	# Une terminaison redirect_chapter doit créer un lien vers un nœud terminal dans le graphe
	var scene = SceneDataScript.new()
	var seq1 = Sequence.new(); seq1.seq_name = "Seq 1"
	scene.sequences.append(seq1)
	seq1.ending = _make_redirect_ending("redirect_chapter", "fake-chapter-uuid")

	var graph = GraphEdit.new()
	graph.set_script(SequenceGraphView)
	add_child_autofree(graph)
	graph.load_scene(scene)

	assert_eq(graph.get_connection_list().size(), 1,
		"redirect_chapter doit créer un lien vers le nœud terminal dans le graphe de séquences")
	assert_true(_has_connection(graph, seq1.uuid, "terminal_redirect_chapter"),
		"redirect_chapter doit connecter seq1 au nœud terminal 'redirect_chapter'")

func test_seq_graph_no_duplicate_when_two_seqs_redirect_to_same():
	# Deux séquences qui redirigent vers la même ne doivent créer qu'un seul lien
	var scene = SceneDataScript.new()
	var seq1 = Sequence.new(); seq1.seq_name = "Seq 1"
	var seq2 = Sequence.new(); seq2.seq_name = "Seq 2"
	var seq3 = Sequence.new(); seq3.seq_name = "Seq 3"
	scene.sequences.append(seq1)
	scene.sequences.append(seq2)
	scene.sequences.append(seq3)
	seq1.ending = _make_redirect_ending("redirect_sequence", seq3.uuid)
	seq2.ending = _make_redirect_ending("redirect_sequence", seq3.uuid)

	var graph = GraphEdit.new()
	graph.set_script(SequenceGraphView)
	add_child_autofree(graph)
	graph.load_scene(scene)

	assert_eq(_count_connections(graph, seq1.uuid, seq3.uuid), 1,
		"seq1→seq3 ne doit apparaître qu'une fois")
	assert_eq(_count_connections(graph, seq2.uuid, seq3.uuid), 1,
		"seq2→seq3 ne doit apparaître qu'une fois")

func test_seq_graph_bidirectional_connections():
	# seq1→seq2 et seq2→seq1 doivent apparaître tous les deux
	var scene = SceneDataScript.new()
	var seq1 = Sequence.new(); seq1.seq_name = "Seq 1"
	var seq2 = Sequence.new(); seq2.seq_name = "Seq 2"
	scene.sequences.append(seq1)
	scene.sequences.append(seq2)
	seq1.ending = _make_redirect_ending("redirect_sequence", seq2.uuid)
	seq2.ending = _make_redirect_ending("redirect_sequence", seq1.uuid)

	var graph = GraphEdit.new()
	graph.set_script(SequenceGraphView)
	add_child_autofree(graph)
	graph.load_scene(scene)

	assert_true(_has_connection(graph, seq1.uuid, seq2.uuid),
		"seq1→seq2 doit exister")
	assert_true(_has_connection(graph, seq2.uuid, seq1.uuid),
		"seq2→seq1 doit exister")

func test_seq_graph_choices_redirect_sequence():
	# Un choix avec redirect_sequence doit créer un lien
	var scene = SceneDataScript.new()
	var seq1 = Sequence.new(); seq1.seq_name = "Seq 1"
	var seq2 = Sequence.new(); seq2.seq_name = "Seq 2"
	scene.sequences.append(seq1)
	scene.sequences.append(seq2)
	seq1.ending = _make_choices_ending([
		{"type": "redirect_sequence", "target": seq2.uuid}
	])

	var graph = GraphEdit.new()
	graph.set_script(SequenceGraphView)
	add_child_autofree(graph)
	graph.load_scene(scene)

	assert_true(_has_connection(graph, seq1.uuid, seq2.uuid),
		"choix redirect_sequence doit créer un lien seq1→seq2")

func test_seq_graph_choices_mixed_types_redirect_sequence_and_terminal():
	# Un choix avec redirect_sequence ET redirect_scene : les deux créent un lien
	# (redirect_sequence → seq2, redirect_scene → nœud terminal)
	var scene = SceneDataScript.new()
	var seq1 = Sequence.new(); seq1.seq_name = "Seq 1"
	var seq2 = Sequence.new(); seq2.seq_name = "Seq 2"
	scene.sequences.append(seq1)
	scene.sequences.append(seq2)
	seq1.ending = _make_choices_ending([
		{"type": "redirect_sequence", "target": seq2.uuid},
		{"type": "redirect_scene", "target": "scene-uuid-outside"}
	])

	var graph = GraphEdit.new()
	graph.set_script(SequenceGraphView)
	add_child_autofree(graph)
	graph.load_scene(scene)

	assert_true(_has_connection(graph, seq1.uuid, seq2.uuid),
		"redirect_sequence doit apparaître dans le graphe séquence")
	assert_true(_has_connection(graph, seq1.uuid, "terminal_redirect_scene"),
		"redirect_scene doit créer un lien vers le nœud terminal")
	assert_eq(graph.get_connection_list().size(), 2,
		"deux liens : un vers seq2 et un vers le terminal redirect_scene")

func test_seq_graph_choice_node_multiport_3_choices_2_same_target_1_game_over():
	# Scénario "Épreuve 1" : 3 choix — 2 redirigent vers la même séquence, 1 est game_over
	# Le nœud doit avoir 3 ports de sortie (un par choix) avec les bons labels
	var scene = SceneDataScript.new()
	var seq1 = Sequence.new(); seq1.seq_name = "Épreuve 1"
	var seq2 = Sequence.new(); seq2.seq_name = "Épreuve 2"
	scene.sequences.append(seq1)
	scene.sequences.append(seq2)
	seq1.ending = _make_choices_ending([
		{"type": "redirect_sequence", "target": seq2.uuid},
		{"type": "redirect_sequence", "target": seq2.uuid},
		{"type": "game_over", "target": ""}
	])

	var graph = GraphEdit.new()
	graph.set_script(SequenceGraphView)
	add_child_autofree(graph)
	graph.load_scene(scene)

	# Le nœud séquence-choix a 3 ports de sortie (slots 1, 2, 3)
	var node1 = null
	for child in graph.get_children():
		if child is GraphNode and child.name == StringName(seq1.uuid):
			node1 = child
			break
	assert_not_null(node1, "nœud Épreuve 1 existe")
	assert_true(node1.is_choice_sequence_node(), "nœud est de type séquence-choix")
	assert_eq(node1.get_choice_count(), 3, "nœud a 3 choix")

	# Slot 0 n'a PAS de sortie (entrée seulement)
	assert_false(node1.is_slot_enabled_right(0), "slot 0 n'a pas de port de sortie")

	# Slots 1, 2, 3 sont des sorties
	assert_true(node1.is_slot_enabled_right(1), "slot 1 (choix 1) a un port de sortie")
	assert_true(node1.is_slot_enabled_right(2), "slot 2 (choix 2) a un port de sortie")
	assert_true(node1.is_slot_enabled_right(3), "slot 3 (choix 3) a un port de sortie")

	# 3 connexions : port 1→seq2, port 2→seq2, port 3→terminal:game_over
	assert_eq(graph.get_connection_list().size(), 3,
		"3 connexions : 2 vers seq2 + 1 vers terminal game_over")
	assert_true(_has_connection(graph, seq1.uuid, seq2.uuid),
		"connexion vers seq2 existe")
	assert_true(_has_connection(graph, seq1.uuid, "terminal_game_over"),
		"connexion vers terminal game_over existe")

# ============================================================
# Tests du graphe de SCÈNES
# ============================================================

func test_scene_graph_redirect_scene_shows_connection():
	# Une terminaison redirect_scene doit créer un lien dans le graphe de scènes
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
	graph.load_chapter(chapter)

	assert_true(_has_connection(graph, scene1.uuid, scene2.uuid),
		"redirect_scene doit créer un lien scene1→scene2")

func test_scene_graph_redirect_sequence_does_not_show_connection():
	# Une terminaison redirect_sequence ne doit PAS créer de lien dans le graphe de scènes
	var chapter = ChapterScript.new()
	var scene1 = SceneDataScript.new(); scene1.scene_name = "Scène 1"
	var scene2 = SceneDataScript.new(); scene2.scene_name = "Scène 2"
	chapter.scenes.append(scene1)
	chapter.scenes.append(scene2)

	var seq1 = Sequence.new()
	var seq2 = Sequence.new()
	seq1.ending = _make_redirect_ending("redirect_sequence", seq2.uuid)
	scene1.sequences.append(seq1)
	scene1.sequences.append(seq2)

	var graph = GraphEdit.new()
	graph.set_script(SceneGraphView)
	add_child_autofree(graph)
	graph.load_chapter(chapter)

	# Aucun lien scène→scène ne doit apparaître pour redirect_sequence
	assert_eq(graph.get_connection_list().size(), 0,
		"redirect_sequence ne doit pas créer de lien dans le graphe de scènes")

func test_scene_graph_redirect_chapter_does_not_show_connection():
	# Une terminaison redirect_chapter ne doit PAS créer de lien dans le graphe de scènes
	var chapter = ChapterScript.new()
	var scene1 = SceneDataScript.new(); scene1.scene_name = "Scène 1"
	chapter.scenes.append(scene1)

	var seq = Sequence.new()
	seq.ending = _make_redirect_ending("redirect_chapter", "fake-chapter-uuid")
	scene1.sequences.append(seq)

	var graph = GraphEdit.new()
	graph.set_script(SceneGraphView)
	add_child_autofree(graph)
	graph.load_chapter(chapter)

	assert_eq(graph.get_connection_list().size(), 0,
		"redirect_chapter ne doit pas créer de lien dans le graphe de scènes")

func test_scene_graph_multiple_seqs_same_target_one_connection():
	# Plusieurs séquences dans la même scène pointant vers la même scène cible
	var chapter = ChapterScript.new()
	var scene1 = SceneDataScript.new(); scene1.scene_name = "Scène 1"
	var scene2 = SceneDataScript.new(); scene2.scene_name = "Scène 2"
	chapter.scenes.append(scene1)
	chapter.scenes.append(scene2)

	var seq1 = Sequence.new()
	var seq2 = Sequence.new()
	seq1.ending = _make_redirect_ending("redirect_scene", scene2.uuid)
	seq2.ending = _make_redirect_ending("redirect_scene", scene2.uuid)
	scene1.sequences.append(seq1)
	scene1.sequences.append(seq2)

	var graph = GraphEdit.new()
	graph.set_script(SceneGraphView)
	add_child_autofree(graph)
	graph.load_chapter(chapter)

	assert_eq(_count_connections(graph, scene1.uuid, scene2.uuid), 1,
		"Deux séquences vers la même scène ne doivent créer qu'un seul lien")

func test_scene_graph_seqs_in_different_scenes_to_same_target():
	# Séquences dans des scènes DIFFÉRENTES pointant vers la même scène cible
	var chapter = ChapterScript.new()
	var scene1 = SceneDataScript.new(); scene1.scene_name = "Scène 1"
	var scene2 = SceneDataScript.new(); scene2.scene_name = "Scène 2"
	var scene3 = SceneDataScript.new(); scene3.scene_name = "Scène 3"
	chapter.scenes.append(scene1)
	chapter.scenes.append(scene2)
	chapter.scenes.append(scene3)

	var seq1 = Sequence.new()
	seq1.ending = _make_redirect_ending("redirect_scene", scene3.uuid)
	scene1.sequences.append(seq1)

	var seq2 = Sequence.new()
	seq2.ending = _make_redirect_ending("redirect_scene", scene3.uuid)
	scene2.sequences.append(seq2)

	var graph = GraphEdit.new()
	graph.set_script(SceneGraphView)
	add_child_autofree(graph)
	graph.load_chapter(chapter)

	# Deux connexions distinctes : scene1→scene3 et scene2→scene3
	assert_true(_has_connection(graph, scene1.uuid, scene3.uuid),
		"scene1→scene3 doit exister")
	assert_true(_has_connection(graph, scene2.uuid, scene3.uuid),
		"scene2→scene3 doit exister")
	assert_eq(_count_connections(graph, scene1.uuid, scene3.uuid), 1,
		"scene1→scene3 ne doit apparaître qu'une fois")
	assert_eq(_count_connections(graph, scene2.uuid, scene3.uuid), 1,
		"scene2→scene3 ne doit apparaître qu'une fois")

func test_scene_graph_bidirectional_connections():
	# scene1→scene2 et scene2→scene1 doivent tous deux apparaître
	var chapter = ChapterScript.new()
	var scene1 = SceneDataScript.new(); scene1.scene_name = "Scène 1"
	var scene2 = SceneDataScript.new(); scene2.scene_name = "Scène 2"
	chapter.scenes.append(scene1)
	chapter.scenes.append(scene2)

	var seq1 = Sequence.new()
	seq1.ending = _make_redirect_ending("redirect_scene", scene2.uuid)
	scene1.sequences.append(seq1)

	var seq2 = Sequence.new()
	seq2.ending = _make_redirect_ending("redirect_scene", scene1.uuid)
	scene2.sequences.append(seq2)

	var graph = GraphEdit.new()
	graph.set_script(SceneGraphView)
	add_child_autofree(graph)
	graph.load_chapter(chapter)

	assert_true(_has_connection(graph, scene1.uuid, scene2.uuid),
		"scene1→scene2 doit exister")
	assert_true(_has_connection(graph, scene2.uuid, scene1.uuid),
		"scene2→scene1 doit exister")

func test_scene_graph_choices_mixed_shows_only_redirect_scene():
	# Choix avec redirect_scene ET redirect_sequence : seul redirect_scene apparaît au niveau scène
	var chapter = ChapterScript.new()
	var scene1 = SceneDataScript.new(); scene1.scene_name = "Scène 1"
	var scene2 = SceneDataScript.new(); scene2.scene_name = "Scène 2"
	chapter.scenes.append(scene1)
	chapter.scenes.append(scene2)

	var seq1 = Sequence.new()
	var seq2 = Sequence.new()
	scene1.sequences.append(seq1)
	scene1.sequences.append(seq2)

	seq1.ending = _make_choices_ending([
		{"type": "redirect_scene", "target": scene2.uuid},
		{"type": "redirect_sequence", "target": seq2.uuid}
	])

	var graph = GraphEdit.new()
	graph.set_script(SceneGraphView)
	add_child_autofree(graph)
	graph.load_chapter(chapter)

	assert_true(_has_connection(graph, scene1.uuid, scene2.uuid),
		"redirect_scene doit apparaître dans le graphe de scènes")
	assert_eq(graph.get_connection_list().size(), 1,
		"redirect_sequence ne doit pas créer de lien dans le graphe de scènes")

func test_scene_graph_no_duplicate_manual_plus_ending():
	# Un lien manuel + terminaison redirect_scene vers la même cible → un seul lien
	var chapter = ChapterScript.new()
	var scene1 = SceneDataScript.new(); scene1.scene_name = "Scène 1"
	var scene2 = SceneDataScript.new(); scene2.scene_name = "Scène 2"
	chapter.scenes.append(scene1)
	chapter.scenes.append(scene2)

	# Connexion manuelle
	chapter.connections.append({"from": scene1.uuid, "to": scene2.uuid})

	# Terminaison qui pointe aussi vers scene2
	var seq = Sequence.new()
	seq.ending = _make_redirect_ending("redirect_scene", scene2.uuid)
	scene1.sequences.append(seq)

	var graph = GraphEdit.new()
	graph.set_script(SceneGraphView)
	add_child_autofree(graph)
	graph.load_chapter(chapter)

	assert_eq(_count_connections(graph, scene1.uuid, scene2.uuid), 1,
		"Connexion manuelle + terminaison vers même cible → un seul lien")

func test_scene_graph_condition_redirect_scene_shows_connection():
	# Une condition avec redirect_scene doit créer un lien dans le graphe de scènes
	var chapter = ChapterScript.new()
	var scene1 = SceneDataScript.new(); scene1.scene_name = "Scène 1"
	var scene2 = SceneDataScript.new(); scene2.scene_name = "Scène 2"
	chapter.scenes.append(scene1)
	chapter.scenes.append(scene2)

	var cond = _make_condition_with_rule("redirect_scene", scene2.uuid)
	scene1.conditions.append(cond)

	var graph = GraphEdit.new()
	graph.set_script(SceneGraphView)
	add_child_autofree(graph)
	graph.load_chapter(chapter)

	assert_true(_has_connection(graph, scene1.uuid, scene2.uuid),
		"condition redirect_scene doit créer un lien scene1→scene2")

func test_scene_graph_condition_default_redirect_scene_shows_connection():
	# Une default_consequence avec redirect_scene doit créer un lien
	var chapter = ChapterScript.new()
	var scene1 = SceneDataScript.new(); scene1.scene_name = "Scène 1"
	var scene2 = SceneDataScript.new(); scene2.scene_name = "Scène 2"
	chapter.scenes.append(scene1)
	chapter.scenes.append(scene2)

	var cond = ConditionScript.new()
	var default_cons = Consequence.new()
	default_cons.type = "redirect_scene"
	default_cons.target = scene2.uuid
	cond.default_consequence = default_cons
	scene1.conditions.append(cond)

	var graph = GraphEdit.new()
	graph.set_script(SceneGraphView)
	add_child_autofree(graph)
	graph.load_chapter(chapter)

	assert_true(_has_connection(graph, scene1.uuid, scene2.uuid),
		"condition default_consequence redirect_scene doit créer un lien scene1→scene2")

func test_scene_graph_condition_no_duplicate_with_seq_redirect():
	# Condition + séquence pointant vers la même scène cible → un seul lien
	var chapter = ChapterScript.new()
	var scene1 = SceneDataScript.new(); scene1.scene_name = "Scène 1"
	var scene2 = SceneDataScript.new(); scene2.scene_name = "Scène 2"
	chapter.scenes.append(scene1)
	chapter.scenes.append(scene2)

	var seq = Sequence.new()
	seq.ending = _make_redirect_ending("redirect_scene", scene2.uuid)
	scene1.sequences.append(seq)

	var cond = _make_condition_with_rule("redirect_scene", scene2.uuid)
	scene1.conditions.append(cond)

	var graph = GraphEdit.new()
	graph.set_script(SceneGraphView)
	add_child_autofree(graph)
	graph.load_chapter(chapter)

	assert_eq(_count_connections(graph, scene1.uuid, scene2.uuid), 1,
		"Condition + séquence vers même cible → un seul lien")

# ============================================================
# Tests du graphe de CHAPITRES
# ============================================================

func test_chapter_graph_redirect_chapter_shows_connection():
	# Une terminaison redirect_chapter doit créer un lien dans le graphe de chapitres
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
	graph.load_story(story)

	assert_true(_has_connection(graph, ch1.uuid, ch2.uuid),
		"redirect_chapter doit créer un lien ch1→ch2")

func test_chapter_graph_redirect_scene_does_not_show_connection():
	# Une terminaison redirect_scene ne doit PAS créer de lien dans le graphe de chapitres
	var story = StoryScript.new()
	var ch1 = ChapterScript.new(); ch1.chapter_name = "Chapitre 1"
	var ch2 = ChapterScript.new(); ch2.chapter_name = "Chapitre 2"
	story.chapters.append(ch1)
	story.chapters.append(ch2)

	var scene = SceneDataScript.new()
	ch1.scenes.append(scene)
	var seq = Sequence.new()
	seq.ending = _make_redirect_ending("redirect_scene", "fake-scene-uuid")
	scene.sequences.append(seq)

	var graph = GraphEdit.new()
	graph.set_script(ChapterGraphView)
	add_child_autofree(graph)
	graph.load_story(story)

	assert_eq(graph.get_connection_list().size(), 0,
		"redirect_scene ne doit pas créer de lien dans le graphe de chapitres")

func test_chapter_graph_redirect_sequence_does_not_show_connection():
	# Une terminaison redirect_sequence ne doit PAS créer de lien dans le graphe de chapitres
	var story = StoryScript.new()
	var ch1 = ChapterScript.new(); ch1.chapter_name = "Chapitre 1"
	story.chapters.append(ch1)

	var scene = SceneDataScript.new()
	ch1.scenes.append(scene)
	var seq1 = Sequence.new()
	var seq2 = Sequence.new()
	seq1.ending = _make_redirect_ending("redirect_sequence", seq2.uuid)
	scene.sequences.append(seq1)
	scene.sequences.append(seq2)

	var graph = GraphEdit.new()
	graph.set_script(ChapterGraphView)
	add_child_autofree(graph)
	graph.load_story(story)

	assert_eq(graph.get_connection_list().size(), 0,
		"redirect_sequence ne doit pas créer de lien dans le graphe de chapitres")

func test_chapter_graph_multiple_scenes_same_target_chapter():
	# Plusieurs scènes dans le même chapitre pointant vers le même chapitre cible
	var story = StoryScript.new()
	var ch1 = ChapterScript.new(); ch1.chapter_name = "Chapitre 1"
	var ch2 = ChapterScript.new(); ch2.chapter_name = "Chapitre 2"
	story.chapters.append(ch1)
	story.chapters.append(ch2)

	var scene1 = SceneDataScript.new()
	var scene2 = SceneDataScript.new()
	ch1.scenes.append(scene1)
	ch1.scenes.append(scene2)

	var seq1 = Sequence.new()
	seq1.ending = _make_redirect_ending("redirect_chapter", ch2.uuid)
	scene1.sequences.append(seq1)

	var seq2 = Sequence.new()
	seq2.ending = _make_redirect_ending("redirect_chapter", ch2.uuid)
	scene2.sequences.append(seq2)

	var graph = GraphEdit.new()
	graph.set_script(ChapterGraphView)
	add_child_autofree(graph)
	graph.load_story(story)

	assert_eq(_count_connections(graph, ch1.uuid, ch2.uuid), 1,
		"Plusieurs séquences vers le même chapitre → un seul lien")

func test_chapter_graph_bidirectional():
	# ch1→ch2 et ch2→ch1 doivent tous deux apparaître
	var story = StoryScript.new()
	var ch1 = ChapterScript.new(); ch1.chapter_name = "Chapitre 1"
	var ch2 = ChapterScript.new(); ch2.chapter_name = "Chapitre 2"
	story.chapters.append(ch1)
	story.chapters.append(ch2)

	var scene1 = SceneDataScript.new()
	ch1.scenes.append(scene1)
	var seq1 = Sequence.new()
	seq1.ending = _make_redirect_ending("redirect_chapter", ch2.uuid)
	scene1.sequences.append(seq1)

	var scene2 = SceneDataScript.new()
	ch2.scenes.append(scene2)
	var seq2 = Sequence.new()
	seq2.ending = _make_redirect_ending("redirect_chapter", ch1.uuid)
	scene2.sequences.append(seq2)

	var graph = GraphEdit.new()
	graph.set_script(ChapterGraphView)
	add_child_autofree(graph)
	graph.load_story(story)

	assert_true(_has_connection(graph, ch1.uuid, ch2.uuid),
		"ch1→ch2 doit exister")
	assert_true(_has_connection(graph, ch2.uuid, ch1.uuid),
		"ch2→ch1 doit exister")

func test_chapter_graph_choices_mixed_shows_only_redirect_chapter():
	# Choix avec redirect_chapter et redirect_scene : seul redirect_chapter au niveau chapitre
	var story = StoryScript.new()
	var ch1 = ChapterScript.new(); ch1.chapter_name = "Chapitre 1"
	var ch2 = ChapterScript.new(); ch2.chapter_name = "Chapitre 2"
	story.chapters.append(ch1)
	story.chapters.append(ch2)

	var scene = SceneDataScript.new()
	ch1.scenes.append(scene)
	var seq = Sequence.new()
	seq.ending = _make_choices_ending([
		{"type": "redirect_chapter", "target": ch2.uuid},
		{"type": "redirect_scene", "target": "scene-uuid"}
	])
	scene.sequences.append(seq)

	var graph = GraphEdit.new()
	graph.set_script(ChapterGraphView)
	add_child_autofree(graph)
	graph.load_story(story)

	assert_true(_has_connection(graph, ch1.uuid, ch2.uuid),
		"redirect_chapter doit apparaître dans le graphe de chapitres")
	assert_eq(graph.get_connection_list().size(), 1,
		"redirect_scene ne doit pas créer de lien dans le graphe de chapitres")

func test_chapter_graph_no_duplicate_manual_plus_ending():
	# Un lien manuel + terminaison redirect_chapter vers la même cible → un seul lien
	var story = StoryScript.new()
	var ch1 = ChapterScript.new(); ch1.chapter_name = "Chapitre 1"
	var ch2 = ChapterScript.new(); ch2.chapter_name = "Chapitre 2"
	story.chapters.append(ch1)
	story.chapters.append(ch2)

	# Connexion manuelle
	story.connections.append({"from": ch1.uuid, "to": ch2.uuid})

	var scene = SceneDataScript.new()
	ch1.scenes.append(scene)
	var seq = Sequence.new()
	seq.ending = _make_redirect_ending("redirect_chapter", ch2.uuid)
	scene.sequences.append(seq)

	var graph = GraphEdit.new()
	graph.set_script(ChapterGraphView)
	add_child_autofree(graph)
	graph.load_story(story)

	assert_eq(_count_connections(graph, ch1.uuid, ch2.uuid), 1,
		"Connexion manuelle + terminaison vers même chapitre → un seul lien")

func test_chapter_graph_condition_redirect_chapter_shows_connection():
	# Une condition avec redirect_chapter doit créer un lien dans le graphe de chapitres
	var story = StoryScript.new()
	var ch1 = ChapterScript.new(); ch1.chapter_name = "Chapitre 1"
	var ch2 = ChapterScript.new(); ch2.chapter_name = "Chapitre 2"
	story.chapters.append(ch1)
	story.chapters.append(ch2)

	var scene = SceneDataScript.new()
	ch1.scenes.append(scene)
	var cond = _make_condition_with_rule("redirect_chapter", ch2.uuid)
	scene.conditions.append(cond)

	var graph = GraphEdit.new()
	graph.set_script(ChapterGraphView)
	add_child_autofree(graph)
	graph.load_story(story)

	assert_true(_has_connection(graph, ch1.uuid, ch2.uuid),
		"condition redirect_chapter doit créer un lien ch1→ch2")

func test_chapter_graph_condition_default_redirect_chapter_shows_connection():
	# Une default_consequence avec redirect_chapter doit créer un lien
	var story = StoryScript.new()
	var ch1 = ChapterScript.new(); ch1.chapter_name = "Chapitre 1"
	var ch2 = ChapterScript.new(); ch2.chapter_name = "Chapitre 2"
	story.chapters.append(ch1)
	story.chapters.append(ch2)

	var scene = SceneDataScript.new()
	ch1.scenes.append(scene)
	var cond = ConditionScript.new()
	var default_cons = Consequence.new()
	default_cons.type = "redirect_chapter"
	default_cons.target = ch2.uuid
	cond.default_consequence = default_cons
	scene.conditions.append(cond)

	var graph = GraphEdit.new()
	graph.set_script(ChapterGraphView)
	add_child_autofree(graph)
	graph.load_story(story)

	assert_true(_has_connection(graph, ch1.uuid, ch2.uuid),
		"condition default_consequence redirect_chapter doit créer un lien ch1→ch2")
