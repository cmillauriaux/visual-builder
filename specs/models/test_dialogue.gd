extends GutTest

const Dialogue = preload("res://src/models/dialogue.gd")
const Foreground = preload("res://src/models/foreground.gd")

# Tests pour le modèle Dialogue

func test_create_dialogue():
	var d = Dialogue.new()
	d.character = "Héros"
	d.text = "Où suis-je ?"
	assert_eq(d.character, "Héros")
	assert_eq(d.text, "Où suis-je ?")

func test_default_values():
	var d = Dialogue.new()
	assert_eq(d.character, "")
	assert_eq(d.text, "")
	assert_ne(d.uuid, "", "UUID doit être généré automatiquement")
	assert_eq(d.foregrounds.size(), 0)

func test_to_dict():
	var d = Dialogue.new()
	d.character = "Narrateur"
	d.text = "Il était une fois..."
	var dict = d.to_dict()
	assert_eq(dict["character"], "Narrateur")
	assert_eq(dict["text"], "Il était une fois...")

func test_from_dict():
	var dict = {"character": "Héros", "text": "Bonjour !"}
	var d = Dialogue.from_dict(dict)
	assert_eq(d.character, "Héros")
	assert_eq(d.text, "Bonjour !")

func test_from_dict_with_missing_fields():
	var dict = {}
	var d = Dialogue.from_dict(dict)
	assert_eq(d.character, "")
	assert_eq(d.text, "")

func test_empty_character_and_text():
	var d = Dialogue.new()
	d.character = ""
	d.text = ""
	assert_eq(d.character, "")
	assert_eq(d.text, "")

func test_unicode_support():
	var d = Dialogue.new()
	d.character = "日本語キャラ"
	d.text = "こんにちは世界！"
	assert_eq(d.character, "日本語キャラ")
	assert_eq(d.text, "こんにちは世界！")

# --- Tests UUID ---

func test_uuid_generated():
	var d = Dialogue.new()
	assert_ne(d.uuid, "")

func test_uuid_unique():
	var d1 = Dialogue.new()
	var d2 = Dialogue.new()
	assert_ne(d1.uuid, d2.uuid)

# --- Tests foregrounds ---

func test_foregrounds_empty_by_default():
	var d = Dialogue.new()
	assert_eq(d.foregrounds.size(), 0)

func test_add_foreground_to_dialogue():
	var d = Dialogue.new()
	var fg = Foreground.new()
	fg.fg_name = "Héros"
	fg.image = "hero.png"
	d.foregrounds.append(fg)
	assert_eq(d.foregrounds.size(), 1)
	assert_eq(d.foregrounds[0].fg_name, "Héros")

# --- Tests sérialisation avec nouveaux champs ---

func test_to_dict_includes_uuid_and_foregrounds():
	var d = Dialogue.new()
	d.uuid = "dlg-001"
	d.character = "Héros"
	d.text = "Bonjour"
	var fg = Foreground.new()
	fg.uuid = "fg-100"
	fg.fg_name = "Perso"
	fg.image = "perso.png"
	fg.transition_type = "fade"
	fg.transition_duration = 1.0
	d.foregrounds.append(fg)
	var dict = d.to_dict()
	assert_eq(dict["uuid"], "dlg-001")
	assert_eq(dict["character"], "Héros")
	assert_eq(dict["text"], "Bonjour")
	assert_eq(dict["foregrounds"].size(), 1)
	assert_eq(dict["foregrounds"][0]["uuid"], "fg-100")
	assert_eq(dict["foregrounds"][0]["transition_type"], "fade")

func test_to_dict_empty_foregrounds():
	var d = Dialogue.new()
	d.character = "Test"
	d.text = "Hello"
	var dict = d.to_dict()
	assert_eq(dict["foregrounds"].size(), 0)

func test_from_dict_with_uuid_and_foregrounds():
	var dict = {
		"uuid": "dlg-002",
		"character": "Narrateur",
		"text": "Il pleut.",
		"foregrounds": [
			{
				"uuid": "fg-200",
				"name": "Pluie",
				"image": "rain.png",
				"z_order": 0,
				"opacity": 0.5,
				"flip_h": false,
				"flip_v": false,
				"scale": 1.0,
				"anchor_bg": {"x": 0.5, "y": 0.5},
				"anchor_fg": {"x": 0.5, "y": 0.5},
				"transition_type": "fade",
				"transition_duration": 2.0
			}
		]
	}
	var d = Dialogue.from_dict(dict)
	assert_eq(d.uuid, "dlg-002")
	assert_eq(d.character, "Narrateur")
	assert_eq(d.foregrounds.size(), 1)
	assert_eq(d.foregrounds[0].uuid, "fg-200")
	assert_eq(d.foregrounds[0].transition_type, "fade")

func test_from_dict_backwards_compatible():
	# Ancien format sans uuid ni foregrounds
	var dict = {"character": "Héros", "text": "Bonjour !"}
	var d = Dialogue.from_dict(dict)
	assert_eq(d.character, "Héros")
	assert_eq(d.text, "Bonjour !")
	assert_ne(d.uuid, "", "UUID doit être généré si absent")
	assert_eq(d.foregrounds.size(), 0)
