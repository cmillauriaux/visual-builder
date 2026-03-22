extends GutTest

## Tests unitaires pour StoryMapView (GraphEdit-based).
## On teste la création des nœuds, les métadonnées et les signaux de navigation.

var StoryMapViewScript = load("res://src/views/story_map_view.gd")
var StoryScript = load("res://src/models/story.gd")
var ChapterScript = load("res://src/models/chapter.gd")
var SceneDataScript = load("res://src/models/scene_data.gd")
var SequenceScript = load("res://src/models/sequence.gd")
var ConditionScript = load("res://src/models/condition.gd")
var EndingScript = load("res://src/models/ending.gd")
var ConsequenceScript = load("res://src/models/consequence.gd")

var _view  # GraphEdit avec StoryMapViewScript
var _story: Object
var _chapter1: Object
var _chapter2: Object
var _scene1: Object
var _scene2: Object
var _seq1: Object
var _seq2: Object
var _seq3: Object
var _cond1: Object


func _make_story() -> Object:
	var story = StoryScript.new()
	story.title = "Test Story"

	var ch1 = ChapterScript.new()
	ch1.chapter_name = "Chapitre 1"
	story.chapters.append(ch1)

	var sc1 = SceneDataScript.new()
	sc1.scene_name = "Scène A"
	ch1.scenes.append(sc1)

	var seq1 = SequenceScript.new()
	seq1.seq_name = "Séquence 1"
	sc1.sequences.append(seq1)

	var seq2 = SequenceScript.new()
	seq2.seq_name = "Séquence 2"
	sc1.sequences.append(seq2)

	var cond1 = ConditionScript.new()
	cond1.condition_name = "Condition A"
	sc1.conditions.append(cond1)

	var ch2 = ChapterScript.new()
	ch2.chapter_name = "Chapitre 2"
	story.chapters.append(ch2)

	var sc2 = SceneDataScript.new()
	sc2.scene_name = "Scène B"
	ch2.scenes.append(sc2)

	var seq3 = SequenceScript.new()
	seq3.seq_name = "Séquence 3"
	sc2.sequences.append(seq3)

	_chapter1 = ch1
	_chapter2 = ch2
	_scene1 = sc1
	_scene2 = sc2
	_seq1 = seq1
	_seq2 = seq2
	_seq3 = seq3
	_cond1 = cond1
	return story


func before_each() -> void:
	_view = GraphEdit.new()
	_view.set_script(StoryMapViewScript)
	_view.size = Vector2(1200, 800)
	add_child_autofree(_view)
	_story = _make_story()


# --- Création des nœuds ---

func test_load_story_creates_all_nodes() -> void:
	_view.load_story(_story)
	# 2 chapitres + 2 scènes + 3 séquences + 1 condition = 8 nœuds
	assert_eq(_view.get_node_count(), 8)


func test_node_map_has_all_chapter_uuids() -> void:
	_view.load_story(_story)
	assert_true(_view._node_map.has(_chapter1.uuid))
	assert_true(_view._node_map.has(_chapter2.uuid))


func test_node_map_has_all_scene_uuids() -> void:
	_view.load_story(_story)
	assert_true(_view._node_map.has(_scene1.uuid))
	assert_true(_view._node_map.has(_scene2.uuid))


func test_node_map_has_all_sequence_uuids() -> void:
	_view.load_story(_story)
	assert_true(_view._node_map.has(_seq1.uuid))
	assert_true(_view._node_map.has(_seq2.uuid))
	assert_true(_view._node_map.has(_seq3.uuid))


func test_node_map_has_condition_uuid() -> void:
	_view.load_story(_story)
	assert_true(_view._node_map.has(_cond1.uuid))


func test_load_story_clears_previous_nodes() -> void:
	_view.load_story(_story)
	var story2 = StoryScript.new()
	story2.title = "Story 2"
	var ch = ChapterScript.new()
	ch.chapter_name = "Ch"
	story2.chapters.append(ch)
	_view.load_story(story2)
	assert_eq(_view.get_node_count(), 1)
	assert_false(_view._node_map.has(_chapter1.uuid))


func test_empty_story_no_nodes() -> void:
	var empty = StoryScript.new()
	empty.title = "Vide"
	_view.load_story(empty)
	assert_eq(_view.get_node_count(), 0)


# --- Métadonnées des nœuds ---

func test_node_meta_type_chapter() -> void:
	_view.load_story(_story)
	assert_eq(_view._node_meta[_chapter1.uuid]["type"], "chapter")


func test_node_meta_type_scene() -> void:
	_view.load_story(_story)
	assert_eq(_view._node_meta[_scene1.uuid]["type"], "scene")


func test_node_meta_type_sequence() -> void:
	_view.load_story(_story)
	assert_eq(_view._node_meta[_seq1.uuid]["type"], "sequence")


func test_node_meta_type_condition() -> void:
	_view.load_story(_story)
	assert_eq(_view._node_meta[_cond1.uuid]["type"], "condition")


func test_node_meta_scene_has_chapter_uuid() -> void:
	_view.load_story(_story)
	assert_eq(_view._node_meta[_scene1.uuid]["chapter_uuid"], _chapter1.uuid)


func test_node_meta_sequence_has_chapter_and_scene_uuid() -> void:
	_view.load_story(_story)
	assert_eq(_view._node_meta[_seq1.uuid]["chapter_uuid"], _chapter1.uuid)
	assert_eq(_view._node_meta[_seq1.uuid]["scene_uuid"], _scene1.uuid)


func test_node_meta_condition_has_chapter_and_scene_uuid() -> void:
	_view.load_story(_story)
	assert_eq(_view._node_meta[_cond1.uuid]["chapter_uuid"], _chapter1.uuid)
	assert_eq(_view._node_meta[_cond1.uuid]["scene_uuid"], _scene1.uuid)


func test_node_meta_seq_in_chapter2_has_correct_chapter_uuid() -> void:
	_view.load_story(_story)
	assert_eq(_view._node_meta[_seq3.uuid]["chapter_uuid"], _chapter2.uuid)
	assert_eq(_view._node_meta[_seq3.uuid]["scene_uuid"], _scene2.uuid)


# --- Signaux de navigation ---

func test_chapter_double_click_emits_chapter_clicked() -> void:
	_view.load_story(_story)
	watch_signals(_view)
	_view._on_node_double_clicked(_chapter1.uuid)
	assert_signal_emitted(_view, "chapter_clicked")


func test_chapter_clicked_has_correct_uuid() -> void:
	_view.load_story(_story)
	watch_signals(_view)
	_view._on_node_double_clicked(_chapter1.uuid)
	var args = get_signal_parameters(_view, "chapter_clicked", 0)
	assert_eq(args[0], _chapter1.uuid)


func test_scene_double_click_emits_scene_clicked() -> void:
	_view.load_story(_story)
	watch_signals(_view)
	_view._on_node_double_clicked(_scene1.uuid)
	assert_signal_emitted(_view, "scene_clicked")


func test_scene_clicked_has_correct_args() -> void:
	_view.load_story(_story)
	watch_signals(_view)
	_view._on_node_double_clicked(_scene1.uuid)
	var args = get_signal_parameters(_view, "scene_clicked", 0)
	assert_eq(args[0], _chapter1.uuid)
	assert_eq(args[1], _scene1.uuid)


func test_sequence_double_click_emits_sequence_clicked() -> void:
	_view.load_story(_story)
	watch_signals(_view)
	_view._on_node_double_clicked(_seq1.uuid)
	assert_signal_emitted(_view, "sequence_clicked")


func test_sequence_clicked_has_correct_args() -> void:
	_view.load_story(_story)
	watch_signals(_view)
	_view._on_node_double_clicked(_seq1.uuid)
	var args = get_signal_parameters(_view, "sequence_clicked", 0)
	assert_eq(args[0], _chapter1.uuid)
	assert_eq(args[1], _scene1.uuid)
	assert_eq(args[2], _seq1.uuid)


func test_condition_double_click_emits_condition_clicked() -> void:
	_view.load_story(_story)
	watch_signals(_view)
	_view._on_node_double_clicked(_cond1.uuid)
	assert_signal_emitted(_view, "condition_clicked")


func test_condition_clicked_has_correct_args() -> void:
	_view.load_story(_story)
	watch_signals(_view)
	_view._on_node_double_clicked(_cond1.uuid)
	var args = get_signal_parameters(_view, "condition_clicked", 0)
	assert_eq(args[0], _chapter1.uuid)
	assert_eq(args[1], _scene1.uuid)
	assert_eq(args[2], _cond1.uuid)


func test_unknown_uuid_emits_no_signal() -> void:
	_view.load_story(_story)
	watch_signals(_view)
	_view._on_node_double_clicked("non-existent-uuid")
	assert_signal_not_emitted(_view, "chapter_clicked")
	assert_signal_not_emitted(_view, "scene_clicked")
	assert_signal_not_emitted(_view, "sequence_clicked")
	assert_signal_not_emitted(_view, "condition_clicked")


func test_chapter2_double_click_emits_correct_uuid() -> void:
	_view.load_story(_story)
	watch_signals(_view)
	_view._on_node_double_clicked(_chapter2.uuid)
	var args = get_signal_parameters(_view, "chapter_clicked", 0)
	assert_eq(args[0], _chapter2.uuid)


# --- Connexions entre nœuds ---

func _make_ending_redirect_chapter(target_uuid: String) -> Object:
	var e = EndingScript.new()
	e.type = "auto_redirect"
	var cons = ConsequenceScript.new()
	cons.type = "redirect_chapter"
	cons.target = target_uuid
	e.auto_consequence = cons
	return e

func _make_ending_redirect_scene(target_uuid: String) -> Object:
	var e = EndingScript.new()
	e.type = "auto_redirect"
	var cons = ConsequenceScript.new()
	cons.type = "redirect_scene"
	cons.target = target_uuid
	e.auto_consequence = cons
	return e

func _make_ending_redirect_sequence(target_uuid: String) -> Object:
	var e = EndingScript.new()
	e.type = "auto_redirect"
	var cons = ConsequenceScript.new()
	cons.type = "redirect_sequence"
	cons.target = target_uuid
	e.auto_consequence = cons
	return e


func _has_connection(from_uuid: String, to_uuid: String) -> bool:
	for conn in _view.get_connection_list():
		if str(conn["from_node"]) == from_uuid and str(conn["to_node"]) == to_uuid:
			return true
	return false


func test_redirect_chapter_creates_chapter_to_chapter_connection() -> void:
	_seq3.ending = _make_ending_redirect_chapter(_chapter1.uuid)
	_view.load_story(_story)
	assert_true(_has_connection(_chapter2.uuid, _chapter1.uuid))


func test_redirect_scene_creates_scene_to_scene_connection() -> void:
	_seq1.ending = _make_ending_redirect_scene(_scene2.uuid)
	_view.load_story(_story)
	assert_true(_has_connection(_scene1.uuid, _scene2.uuid))


func test_redirect_sequence_creates_seq_to_seq_connection() -> void:
	_seq1.ending = _make_ending_redirect_sequence(_seq2.uuid)
	_view.load_story(_story)
	assert_true(_has_connection(_seq1.uuid, _seq2.uuid))


func test_cross_scene_redirect_sequence_creates_connection() -> void:
	_seq1.ending = _make_ending_redirect_sequence(_seq3.uuid)
	_view.load_story(_story)
	assert_true(_has_connection(_seq1.uuid, _seq3.uuid))
