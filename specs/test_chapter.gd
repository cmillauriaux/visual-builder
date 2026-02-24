extends GutTest

const SceneData = preload("res://src/models/scene_data.gd")
const Chapter = preload("res://src/models/chapter.gd")

# Tests pour le modèle Chapter

func test_create_chapter():
	var ch = Chapter.new()
	ch.chapter_name = "Chapitre 1 — Le début"
	assert_eq(ch.chapter_name, "Chapitre 1 — Le début")

func test_default_values():
	var ch = Chapter.new()
	assert_ne(ch.uuid, "")
	assert_eq(ch.chapter_name, "")
	assert_eq(ch.position, Vector2.ZERO)
	assert_eq(ch.scenes.size(), 0)
	assert_eq(ch.connections.size(), 0)

func test_uuid_unique():
	var c1 = Chapter.new()
	var c2 = Chapter.new()
	assert_ne(c1.uuid, c2.uuid)

func test_add_scene():
	var ch = Chapter.new()
	var scene = SceneData.new()
	scene.scene_name = "Arrivée en forêt"
	ch.scenes.append(scene)
	assert_eq(ch.scenes.size(), 1)

func test_add_connection():
	var ch = Chapter.new()
	ch.connections.append({"from": "scene-001", "to": "scene-002"})
	assert_eq(ch.connections.size(), 1)

func test_to_dict_header():
	var ch = Chapter.new()
	ch.uuid = "abc-123"
	ch.chapter_name = "Chapitre 1"
	ch.position = Vector2(100, 200)
	var d = ch.to_dict_header()
	assert_eq(d["uuid"], "abc-123")
	assert_eq(d["name"], "Chapitre 1")
	assert_eq(d["position"]["x"], 100.0)
	assert_eq(d["position"]["y"], 200.0)

func test_to_dict_full():
	var ch = Chapter.new()
	ch.uuid = "abc-123"
	ch.chapter_name = "Chapitre 1"
	var scene = SceneData.new()
	scene.uuid = "scene-001"
	scene.scene_name = "Scène 1"
	scene.position = Vector2(50, 100)
	ch.scenes.append(scene)
	ch.connections.append({"from": "scene-001", "to": "scene-002"})
	var d = ch.to_dict()
	assert_eq(d["uuid"], "abc-123")
	assert_eq(d["name"], "Chapitre 1")
	assert_eq(d["scenes"].size(), 1)
	assert_eq(d["scenes"][0]["uuid"], "scene-001")
	assert_eq(d["connections"].size(), 1)

func test_from_dict_header():
	var d = {"uuid": "abc-123", "name": "Chapitre 1", "position": {"x": 100, "y": 200}}
	var ch = Chapter.from_dict_header(d)
	assert_eq(ch.uuid, "abc-123")
	assert_eq(ch.chapter_name, "Chapitre 1")
	assert_eq(ch.position, Vector2(100, 200))
	assert_eq(ch.scenes.size(), 0)

func test_from_dict():
	var d = {
		"uuid": "abc-123",
		"name": "Chapitre 1",
		"scenes": [
			{"uuid": "scene-001", "name": "Scène 1", "position": {"x": 50, "y": 100}}
		],
		"connections": [
			{"from": "scene-001", "to": "scene-002"}
		]
	}
	var ch = Chapter.from_dict(d)
	assert_eq(ch.uuid, "abc-123")
	assert_eq(ch.chapter_name, "Chapitre 1")
	assert_eq(ch.scenes.size(), 1)
	assert_eq(ch.connections.size(), 1)

func test_find_scene_by_uuid():
	var ch = Chapter.new()
	var s1 = SceneData.new()
	s1.uuid = "scene-001"
	s1.scene_name = "Première"
	var s2 = SceneData.new()
	s2.uuid = "scene-002"
	s2.scene_name = "Deuxième"
	ch.scenes.append(s1)
	ch.scenes.append(s2)
	var found = ch.find_scene("scene-002")
	assert_not_null(found)
	assert_eq(found.scene_name, "Deuxième")

func test_find_scene_not_found():
	var ch = Chapter.new()
	assert_null(ch.find_scene("nonexistent"))
