extends GutTest

const Consequence = preload("res://src/models/consequence.gd")
const Dialogue = preload("res://src/models/dialogue.gd")
const Foreground = preload("res://src/models/foreground.gd")
const Ending = preload("res://src/models/ending.gd")
const Sequence = preload("res://src/models/sequence.gd")
const SequenceFx = preload("res://src/models/sequence_fx.gd")

# Tests pour le modèle Sequence

func test_create_sequence():
	var seq = Sequence.new()
	seq.seq_name = "Exploration"
	assert_eq(seq.seq_name, "Exploration")

func test_default_values():
	var seq = Sequence.new()
	assert_ne(seq.uuid, "", "UUID doit être généré automatiquement")
	assert_eq(seq.seq_name, "")
	assert_eq(seq.position, Vector2.ZERO)
	assert_eq(seq.background, "")
	assert_eq(seq.foregrounds.size(), 0)
	assert_eq(seq.dialogues.size(), 0)
	assert_null(seq.ending)
	assert_eq(seq.fx.size(), 0)

func test_uuid_is_unique():
	var s1 = Sequence.new()
	var s2 = Sequence.new()
	assert_ne(s1.uuid, s2.uuid)

func test_add_foreground():
	var seq = Sequence.new()
	var fg = Foreground.new()
	fg.fg_name = "Héros"
	seq.foregrounds.append(fg)
	assert_eq(seq.foregrounds.size(), 1)
	assert_eq(seq.foregrounds[0].fg_name, "Héros")

func test_add_dialogue():
	var seq = Sequence.new()
	var d = Dialogue.new()
	d.character = "Héros"
	d.text = "Où suis-je ?"
	seq.dialogues.append(d)
	assert_eq(seq.dialogues.size(), 1)
	assert_eq(seq.dialogues[0].character, "Héros")

func test_set_ending():
	var seq = Sequence.new()
	var e = Ending.new()
	e.type = "auto_redirect"
	e.auto_consequence = Consequence.new()
	e.auto_consequence.type = "to_be_continued"
	seq.ending = e
	assert_eq(seq.ending.type, "auto_redirect")

func test_to_dict():
	var seq = Sequence.new()
	seq.uuid = "seq-001"
	seq.seq_name = "Exploration"
	seq.position = Vector2(100, 200)
	seq.background = "foret.png"

	var fg = Foreground.new()
	fg.uuid = "fg-001"
	fg.fg_name = "Héros"
	fg.image = "personnage-a.png"
	fg.z_order = 1
	seq.foregrounds.append(fg)

	var d = Dialogue.new()
	d.character = "Héros"
	d.text = "Où suis-je ?"
	seq.dialogues.append(d)

	var e = Ending.new()
	e.type = "auto_redirect"
	e.auto_consequence = Consequence.new()
	e.auto_consequence.type = "to_be_continued"
	seq.ending = e

	var dict = seq.to_dict()
	assert_eq(dict["uuid"], "seq-001")
	assert_eq(dict["name"], "Exploration")
	assert_eq(dict["position"]["x"], 100.0)
	assert_eq(dict["position"]["y"], 200.0)
	assert_eq(dict["background"], "foret.png")
	assert_eq(dict["foregrounds"].size(), 1)
	assert_eq(dict["dialogues"].size(), 1)
	assert_eq(dict["ending"]["type"], "auto_redirect")

func test_from_dict():
	var dict = {
		"uuid": "seq-001",
		"name": "Exploration",
		"position": {"x": 100, "y": 200},
		"background": "foret.png",
		"foregrounds": [
			{
				"uuid": "fg-001",
				"name": "Héros",
				"image": "personnage-a.png",
				"z_order": 1,
				"opacity": 1.0,
				"flip_h": false,
				"flip_v": false,
				"scale": 1.0,
				"anchor_bg": {"x": 0.5, "y": 0.8},
				"anchor_fg": {"x": 0.5, "y": 1.0}
			}
		],
		"dialogues": [
			{"character": "Héros", "text": "Où suis-je ?"}
		],
		"ending": {
			"type": "auto_redirect",
			"consequence": {"type": "to_be_continued"}
		}
	}
	var seq = Sequence.from_dict(dict)
	assert_eq(seq.uuid, "seq-001")
	assert_eq(seq.seq_name, "Exploration")
	assert_eq(seq.position, Vector2(100, 200))
	assert_eq(seq.background, "foret.png")
	assert_eq(seq.foregrounds.size(), 1)
	assert_eq(seq.foregrounds[0].fg_name, "Héros")
	assert_eq(seq.dialogues.size(), 1)
	assert_eq(seq.dialogues[0].character, "Héros")
	assert_eq(seq.ending.type, "auto_redirect")

func test_from_dict_minimal():
	var dict = {"uuid": "seq-002", "name": "Vide", "position": {"x": 0, "y": 0}}
	var seq = Sequence.from_dict(dict)
	assert_eq(seq.uuid, "seq-002")
	assert_eq(seq.seq_name, "Vide")
	assert_eq(seq.foregrounds.size(), 0)
	assert_eq(seq.dialogues.size(), 0)
	assert_null(seq.ending)

func test_dialogues_order_preserved():
	var seq = Sequence.new()
	for i in range(5):
		var d = Dialogue.new()
		d.character = "Personnage"
		d.text = "Ligne %d" % i
		seq.dialogues.append(d)
	var dict = seq.to_dict()
	var restored = Sequence.from_dict(dict)
	for i in range(5):
		assert_eq(restored.dialogues[i].text, "Ligne %d" % i)

# --- Tests subtitle ---

func test_subtitle_default_empty():
	var seq = Sequence.new()
	assert_eq(seq.subtitle, "")

func test_subtitle_to_dict():
	var seq = Sequence.new()
	seq.uuid = "seq-001"
	seq.seq_name = "Exploration"
	seq.subtitle = "Premier pas"
	seq.position = Vector2(0, 0)
	var dict = seq.to_dict()
	assert_eq(dict["subtitle"], "Premier pas")

func test_subtitle_from_dict():
	var dict = {
		"uuid": "seq-001",
		"name": "Exploration",
		"subtitle": "Premier pas",
		"position": {"x": 0, "y": 0},
		"background": "",
		"foregrounds": [],
		"dialogues": []
	}
	var seq = Sequence.from_dict(dict)
	assert_eq(seq.subtitle, "Premier pas")

func test_subtitle_retrocompat():
	var dict = {"uuid": "seq-002", "name": "Vide", "position": {"x": 0, "y": 0}}
	var seq = Sequence.from_dict(dict)
	assert_eq(seq.subtitle, "")

# --- Tests fx ---

func test_fx_default_empty():
	var seq = Sequence.new()
	assert_eq(seq.fx.size(), 0)

func test_fx_to_dict():
	var seq = Sequence.new()
	seq.uuid = "seq-fx-001"
	seq.seq_name = "FX Test"
	seq.position = Vector2(0, 0)
	var fx = SequenceFx.new()
	fx.uuid = "fx-001"
	fx.fx_type = "screen_shake"
	fx.duration = 1.0
	fx.intensity = 2.0
	seq.fx.append(fx)
	var dict = seq.to_dict()
	assert_eq(dict["fx"].size(), 1)
	assert_eq(dict["fx"][0]["uuid"], "fx-001")
	assert_eq(dict["fx"][0]["fx_type"], "screen_shake")

func test_fx_from_dict():
	var dict = {
		"uuid": "seq-fx-002",
		"name": "FX Test",
		"position": {"x": 0, "y": 0},
		"fx": [
			{"uuid": "fx-001", "fx_type": "fade_in", "duration": 0.8, "intensity": 1.0},
			{"uuid": "fx-002", "fx_type": "eyes_blink", "duration": 1.5, "intensity": 0.5},
		]
	}
	var seq = Sequence.from_dict(dict)
	assert_eq(seq.fx.size(), 2)
	assert_eq(seq.fx[0].fx_type, "fade_in")
	assert_eq(seq.fx[0].duration, 0.8)
	assert_eq(seq.fx[1].fx_type, "eyes_blink")
	assert_eq(seq.fx[1].intensity, 0.5)

func test_fx_retrocompat():
	var dict = {"uuid": "seq-old", "name": "Old", "position": {"x": 0, "y": 0}}
	var seq = Sequence.from_dict(dict)
	assert_eq(seq.fx.size(), 0)

func test_fx_roundtrip():
	var seq = Sequence.new()
	var fx1 = SequenceFx.new()
	fx1.fx_type = "screen_shake"
	fx1.duration = 0.3
	fx1.intensity = 2.5
	var fx2 = SequenceFx.new()
	fx2.fx_type = "eyes_blink"
	fx2.duration = 1.2
	seq.fx.append(fx1)
	seq.fx.append(fx2)
	var dict = seq.to_dict()
	var restored = Sequence.from_dict(dict)
	assert_eq(restored.fx.size(), 2)
	assert_eq(restored.fx[0].fx_type, "screen_shake")
	assert_eq(restored.fx[0].duration, 0.3)
	assert_eq(restored.fx[0].intensity, 2.5)
	assert_eq(restored.fx[1].fx_type, "eyes_blink")
	assert_eq(restored.fx[1].duration, 1.2)
