extends GutTest

# Tests pour le parser YAML simplifié

const YamlParser = preload("res://src/persistence/yaml_parser.gd")

# --- Tests d'écriture (dict → YAML string) ---

func test_write_simple_string():
	var d = {"title": "Mon Histoire"}
	var yaml = YamlParser.dict_to_yaml(d)
	assert_true(yaml.find("title: \"Mon Histoire\"") >= 0)

func test_write_integer():
	var d = {"count": 42}
	var yaml = YamlParser.dict_to_yaml(d)
	assert_true(yaml.find("count: 42") >= 0)

func test_write_float():
	var d = {"opacity": 0.5}
	var yaml = YamlParser.dict_to_yaml(d)
	assert_true(yaml.find("opacity: 0.5") >= 0)

func test_write_boolean():
	var d = {"flip_h": true, "flip_v": false}
	var yaml = YamlParser.dict_to_yaml(d)
	assert_true(yaml.find("flip_h: true") >= 0)
	assert_true(yaml.find("flip_v: false") >= 0)

func test_write_inline_dict():
	var d = {"position": {"x": 100, "y": 200}}
	var yaml = YamlParser.dict_to_yaml(d)
	# Le format attendu est inline pour les petits dicts comme position
	assert_true(yaml.find("position:") >= 0)

func test_write_array_of_dicts():
	var d = {
		"chapters": [
			{"uuid": "abc-123", "name": "Chapitre 1"},
			{"uuid": "def-456", "name": "Chapitre 2"}
		]
	}
	var yaml = YamlParser.dict_to_yaml(d)
	assert_true(yaml.find("chapters:") >= 0)
	assert_true(yaml.find("uuid: \"abc-123\"") >= 0)

func test_write_empty_array():
	var d = {"foregrounds": []}
	var yaml = YamlParser.dict_to_yaml(d)
	assert_true(yaml.find("foregrounds: []") >= 0)

func test_write_empty_dict():
	var d = {"conditions": {}}
	var yaml = YamlParser.dict_to_yaml(d)
	assert_true(yaml.find("conditions: {}") >= 0)

# --- Tests de lecture (YAML string → dict) ---

func test_read_simple_string():
	var yaml = 'title: "Mon Histoire"\nauthor: "Auteur"'
	var d = YamlParser.yaml_to_dict(yaml)
	assert_eq(d["title"], "Mon Histoire")
	assert_eq(d["author"], "Auteur")

func test_read_unquoted_string():
	var yaml = "version: 1.0.0"
	var d = YamlParser.yaml_to_dict(yaml)
	assert_eq(d["version"], "1.0.0")

func test_read_integer():
	var yaml = "z_order: 1"
	var d = YamlParser.yaml_to_dict(yaml)
	assert_eq(d["z_order"], 1)

func test_read_float():
	var yaml = "opacity: 0.5"
	var d = YamlParser.yaml_to_dict(yaml)
	assert_almost_eq(float(d["opacity"]), 0.5, 0.001)

func test_read_boolean():
	var yaml = "flip_h: true\nflip_v: false"
	var d = YamlParser.yaml_to_dict(yaml)
	assert_eq(d["flip_h"], true)
	assert_eq(d["flip_v"], false)

func test_read_inline_dict():
	var yaml = 'position: { x: 100, y: 200 }'
	var d = YamlParser.yaml_to_dict(yaml)
	assert_eq(d["position"]["x"], 100)
	assert_eq(d["position"]["y"], 200)

func test_read_array_of_dicts():
	var yaml = "chapters:\n  - uuid: \"abc-123\"\n    name: \"Chapitre 1\"\n  - uuid: \"def-456\"\n    name: \"Chapitre 2\""
	var d = YamlParser.yaml_to_dict(yaml)
	assert_eq(d["chapters"].size(), 2)
	assert_eq(d["chapters"][0]["uuid"], "abc-123")
	assert_eq(d["chapters"][1]["name"], "Chapitre 2")

func test_read_empty_array():
	var yaml = "foregrounds: []"
	var d = YamlParser.yaml_to_dict(yaml)
	assert_eq(d["foregrounds"], [])

func test_read_empty_dict():
	var yaml = "conditions: {}"
	var d = YamlParser.yaml_to_dict(yaml)
	assert_eq(d["conditions"], {})

# --- Tests aller-retour (dict → YAML → dict) ---

func test_roundtrip_simple():
	var original = {
		"title": "Mon Histoire",
		"author": "Auteur",
		"version": "1.0.0",
	}
	var yaml = YamlParser.dict_to_yaml(original)
	var restored = YamlParser.yaml_to_dict(yaml)
	assert_eq(restored["title"], "Mon Histoire")
	assert_eq(restored["author"], "Auteur")
	assert_eq(restored["version"], "1.0.0")

func test_roundtrip_nested():
	var original = {
		"uuid": "seq-001",
		"name": "Exploration",
		"position": {"x": 100, "y": 200},
		"background": "foret.png",
		"foregrounds": [],
		"dialogues": [
			{"character": "Héros", "text": "Où suis-je ?"}
		],
	}
	var yaml = YamlParser.dict_to_yaml(original)
	var restored = YamlParser.yaml_to_dict(yaml)
	assert_eq(restored["uuid"], "seq-001")
	assert_eq(restored["name"], "Exploration")
	assert_eq(restored["position"]["x"], 100)
	assert_eq(restored["dialogues"].size(), 1)
	assert_eq(restored["dialogues"][0]["character"], "Héros")

func test_roundtrip_story_yaml():
	# Reproduit le format exact de story.yaml de la spec
	var original = {
		"title": "Mon Histoire",
		"author": "Auteur",
		"description": "Une aventure interactive...",
		"version": "1.0.0",
		"created_at": "2026-02-21T10:00:00Z",
		"updated_at": "2026-02-21T15:30:00Z",
		"chapters": [
			{"uuid": "abc-123", "name": "Chapitre 1 — Le début", "position": {"x": 100, "y": 200}},
			{"uuid": "def-456", "name": "Chapitre 2 — La rencontre", "position": {"x": 400, "y": 200}},
		],
		"connections": [
			{"from": "abc-123", "to": "def-456"}
		]
	}
	var yaml = YamlParser.dict_to_yaml(original)
	var restored = YamlParser.yaml_to_dict(yaml)
	assert_eq(restored["title"], "Mon Histoire")
	assert_eq(restored["chapters"].size(), 2)
	assert_eq(restored["chapters"][0]["uuid"], "abc-123")
	assert_eq(restored["connections"].size(), 1)
	assert_eq(restored["connections"][0]["from"], "abc-123")
