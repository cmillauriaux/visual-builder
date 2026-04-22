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


# --- Tests champs voice ---

func test_voice_default_empty():
	var d = Dialogue.new()
	assert_eq(d.voice, "")
	assert_true(d.voice_files.is_empty())
	assert_true(d.voice_request_ids.is_empty())


func test_voice_to_dict_omits_when_empty():
	var d = Dialogue.new()
	d.character = "Test"
	d.text = "Hello"
	var dict = d.to_dict()
	assert_false(dict.has("voice"), "voice should be omitted when empty")
	assert_false(dict.has("voice_files"), "voice_files should be omitted when empty")
	assert_false(dict.has("voice_request_ids"), "voice_request_ids should be omitted when empty")


func test_voice_to_dict_includes_when_set():
	var d = Dialogue.new()
	d.character = "Narrateur"
	d.text = "Bienvenue"
	d.voice = "[whispers] Bienvenue dans ce monde..."
	d.voice_id_override = "eleven_voice_id_123"
	d.voice_files = {"fr": "assets/voices/abc_fr.mp3", "en": "assets/voices/abc_en.mp3"}
	d.voice_request_ids = {"fr": "req-fr-123", "en": "req-en-456"}
	var dict = d.to_dict()
	assert_eq(dict["voice"], "[whispers] Bienvenue dans ce monde...")
	assert_eq(dict["voice_id_override"], "eleven_voice_id_123")
	assert_eq(dict["voice_files"]["fr"], "assets/voices/abc_fr.mp3")
	assert_eq(dict["voice_files"]["en"], "assets/voices/abc_en.mp3")
	assert_eq(dict["voice_request_ids"]["fr"], "req-fr-123")


func test_voice_from_dict_multilang():
	var dict = {
		"character": "Héros",
		"text": "En avant !",
		"voice": "[sarcastically] En avant...",
		"voice_id_override": "override_id",
		"voice_files": {"fr": "assets/voices/hero_fr.mp3", "en": "assets/voices/hero_en.mp3"},
		"voice_request_ids": {"fr": "req-fr"}
	}
	var d = Dialogue.from_dict(dict)
	assert_eq(d.voice, "[sarcastically] En avant...")
	assert_eq(d.voice_id_override, "override_id")
	assert_eq(d.get_voice_file("fr"), "assets/voices/hero_fr.mp3")
	assert_eq(d.get_voice_file("en"), "assets/voices/hero_en.mp3")
	assert_eq(d.get_voice_file("de"), "")
	assert_eq(d.get_voice_request_id("fr"), "req-fr")


func test_voice_from_dict_retrocompat_old_format():
	# Ancien format voice_file (String) → migré vers voice_files dict
	var dict = {"character": "Test", "text": "Hello", "voice_file": "assets/voices/old.mp3", "voice_request_id": "old-req"}
	var d = Dialogue.from_dict(dict)
	assert_eq(d.get_voice_file("default"), "assets/voices/old.mp3")
	assert_eq(d.get_voice_request_id("default"), "old-req")


func test_voice_from_dict_backwards_compatible():
	# Ancien format sans voice
	var dict = {"character": "Test", "text": "Hello"}
	var d = Dialogue.from_dict(dict)
	assert_eq(d.voice, "")
	assert_true(d.voice_files.is_empty())
