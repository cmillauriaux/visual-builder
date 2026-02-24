extends GutTest

# Tests pour la vue graphe des séquences

const SequenceGraphView = preload("res://src/views/sequence_graph_view.gd")
const SceneData = preload("res://src/models/scene_data.gd")
const Sequence = preload("res://src/models/sequence.gd")

var _view: GraphEdit = null
var _scene_data = null

func before_each():
	_view = GraphEdit.new()
	_view.set_script(SequenceGraphView)
	add_child_autofree(_view)
	_scene_data = SceneData.new()
	_scene_data.scene_name = "Scène Test"

func test_load_empty_scene():
	_view.load_scene(_scene_data)
	assert_eq(_view.get_node_count(), 0)

func test_load_scene_with_sequences():
	var s1 = Sequence.new()
	s1.seq_name = "Séq 1"
	var s2 = Sequence.new()
	s2.seq_name = "Séq 2"
	_scene_data.sequences.append(s1)
	_scene_data.sequences.append(s2)
	_view.load_scene(_scene_data)
	assert_eq(_view.get_node_count(), 2)

func test_add_sequence():
	_view.load_scene(_scene_data)
	_view.add_new_sequence("Nouvelle Séquence", Vector2(100, 50))
	assert_eq(_scene_data.sequences.size(), 1)
	assert_eq(_scene_data.sequences[0].seq_name, "Nouvelle Séquence")

func test_remove_sequence():
	var s = Sequence.new()
	s.seq_name = "À supprimer"
	_scene_data.sequences.append(s)
	_view.load_scene(_scene_data)
	_view.remove_sequence(s.uuid)
	assert_eq(_scene_data.sequences.size(), 0)

func test_rename_sequence():
	var s = Sequence.new()
	s.seq_name = "Ancien"
	_scene_data.sequences.append(s)
	_view.load_scene(_scene_data)
	_view.rename_sequence(s.uuid, "Nouveau")
	assert_eq(_scene_data.sequences[0].seq_name, "Nouveau")

func test_get_scene_data():
	_view.load_scene(_scene_data)
	assert_eq(_view.get_scene_data(), _scene_data)
