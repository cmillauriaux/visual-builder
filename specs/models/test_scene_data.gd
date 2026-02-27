extends GutTest

const Sequence = preload("res://src/models/sequence.gd")
const SceneData = preload("res://src/models/scene_data.gd")

# Tests pour le modèle SceneData

func test_create_scene():
	var scene = SceneData.new()
	scene.scene_name = "Arrivée en forêt"
	assert_eq(scene.scene_name, "Arrivée en forêt")

func test_default_values():
	var scene = SceneData.new()
	assert_ne(scene.uuid, "")
	assert_eq(scene.scene_name, "")
	assert_eq(scene.position, Vector2.ZERO)
	assert_eq(scene.sequences.size(), 0)
	assert_eq(scene.connections.size(), 0)

func test_uuid_unique():
	var s1 = SceneData.new()
	var s2 = SceneData.new()
	assert_ne(s1.uuid, s2.uuid)

func test_add_sequence():
	var scene = SceneData.new()
	var seq = Sequence.new()
	seq.seq_name = "Exploration"
	scene.sequences.append(seq)
	assert_eq(scene.sequences.size(), 1)

func test_add_connection():
	var scene = SceneData.new()
	scene.connections.append({"from": "seq-001", "to": "seq-002"})
	assert_eq(scene.connections.size(), 1)
	assert_eq(scene.connections[0]["from"], "seq-001")
	assert_eq(scene.connections[0]["to"], "seq-002")

func test_to_dict():
	var scene = SceneData.new()
	scene.uuid = "scene-001"
	scene.scene_name = "Arrivée en forêt"
	scene.position = Vector2(50, 100)

	var seq = Sequence.new()
	seq.uuid = "seq-001"
	seq.seq_name = "Exploration"
	scene.sequences.append(seq)

	scene.connections.append({"from": "seq-001", "to": "seq-002"})

	var d = scene.to_dict()
	assert_eq(d["uuid"], "scene-001")
	assert_eq(d["name"], "Arrivée en forêt")
	assert_eq(d["sequences"].size(), 1)
	assert_eq(d["connections"].size(), 1)

func test_from_dict():
	var d = {
		"uuid": "scene-001",
		"name": "Arrivée en forêt",
		"sequences": [
			{
				"uuid": "seq-001",
				"name": "Exploration",
				"position": {"x": 0, "y": 0},
				"background": "foret.png",
				"foregrounds": [],
				"dialogues": [],
			}
		],
		"connections": [
			{"from": "seq-001", "to": "seq-002"}
		]
	}
	var scene = SceneData.from_dict(d)
	assert_eq(scene.uuid, "scene-001")
	assert_eq(scene.scene_name, "Arrivée en forêt")
	assert_eq(scene.sequences.size(), 1)
	assert_eq(scene.sequences[0].seq_name, "Exploration")
	assert_eq(scene.connections.size(), 1)

func test_from_dict_minimal():
	var d = {"uuid": "scene-002", "name": "Vide"}
	var scene = SceneData.from_dict(d)
	assert_eq(scene.uuid, "scene-002")
	assert_eq(scene.scene_name, "Vide")
	assert_eq(scene.sequences.size(), 0)
	assert_eq(scene.connections.size(), 0)

func test_find_sequence_by_uuid():
	var scene = SceneData.new()
	var seq1 = Sequence.new()
	seq1.uuid = "seq-001"
	seq1.seq_name = "Première"
	var seq2 = Sequence.new()
	seq2.uuid = "seq-002"
	seq2.seq_name = "Deuxième"
	scene.sequences.append(seq1)
	scene.sequences.append(seq2)
	var found = scene.find_sequence("seq-002")
	assert_not_null(found)
	assert_eq(found.seq_name, "Deuxième")

func test_find_sequence_not_found():
	var scene = SceneData.new()
	var found = scene.find_sequence("nonexistent")
	assert_null(found)

# --- Tests subtitle ---

func test_subtitle_default_empty():
	var scene = SceneData.new()
	assert_eq(scene.subtitle, "")

func test_subtitle_to_dict():
	var scene = SceneData.new()
	scene.uuid = "scene-001"
	scene.scene_name = "Scène 1"
	scene.subtitle = "Arrivée en forêt"
	var d = scene.to_dict()
	assert_eq(d["subtitle"], "Arrivée en forêt")

func test_subtitle_from_dict():
	var d = {
		"uuid": "scene-001",
		"name": "Scène 1",
		"subtitle": "Arrivée en forêt",
		"sequences": [],
		"connections": []
	}
	var scene = SceneData.from_dict(d)
	assert_eq(scene.subtitle, "Arrivée en forêt")

func test_subtitle_retrocompat():
	var d = {"uuid": "scene-002", "name": "Vide"}
	var scene = SceneData.from_dict(d)
	assert_eq(scene.subtitle, "")
