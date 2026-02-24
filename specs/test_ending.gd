extends GutTest

const Consequence = preload("res://src/models/consequence.gd")
const Choice = preload("res://src/models/choice.gd")
const Ending = preload("res://src/models/ending.gd")

# Tests pour le modèle Ending (terminaison de séquence)

# --- Tests mode Choix ---

func test_create_choices_ending():
	var e = Ending.new()
	e.type = "choices"
	assert_eq(e.type, "choices")
	assert_eq(e.choices.size(), 0)

func test_add_choice():
	var e = Ending.new()
	e.type = "choices"
	var choice = Choice.new()
	choice.text = "Explorer le chemin"
	choice.consequence = Consequence.new()
	choice.consequence.type = "redirect_sequence"
	choice.consequence.target = "seq-002"
	e.choices.append(choice)
	assert_eq(e.choices.size(), 1)
	assert_eq(e.choices[0].text, "Explorer le chemin")

func test_max_8_choices():
	var e = Ending.new()
	e.type = "choices"
	for i in range(8):
		var choice = Choice.new()
		choice.text = "Choix %d" % (i + 1)
		choice.consequence = Consequence.new()
		choice.consequence.type = "game_over"
		e.choices.append(choice)
	assert_eq(e.choices.size(), 8)
	assert_true(e.is_valid(), "8 choix doit être valide")

func test_more_than_8_choices_invalid():
	var e = Ending.new()
	e.type = "choices"
	for i in range(9):
		var choice = Choice.new()
		choice.text = "Choix %d" % (i + 1)
		choice.consequence = Consequence.new()
		choice.consequence.type = "game_over"
		e.choices.append(choice)
	assert_false(e.is_valid(), "Plus de 8 choix ne doit pas être valide")

func test_zero_choices_invalid():
	var e = Ending.new()
	e.type = "choices"
	assert_false(e.is_valid(), "0 choix ne doit pas être valide")

# --- Tests mode Redirection automatique ---

func test_create_auto_redirect():
	var e = Ending.new()
	e.type = "auto_redirect"
	e.auto_consequence = Consequence.new()
	e.auto_consequence.type = "to_be_continued"
	assert_eq(e.type, "auto_redirect")
	assert_eq(e.auto_consequence.type, "to_be_continued")

func test_auto_redirect_valid():
	var e = Ending.new()
	e.type = "auto_redirect"
	e.auto_consequence = Consequence.new()
	e.auto_consequence.type = "game_over"
	assert_true(e.is_valid())

func test_auto_redirect_without_consequence_invalid():
	var e = Ending.new()
	e.type = "auto_redirect"
	assert_false(e.is_valid(), "auto_redirect sans conséquence ne doit pas être valide")

# --- Tests sérialisation ---

func test_to_dict_choices():
	var e = Ending.new()
	e.type = "choices"
	var choice = Choice.new()
	choice.text = "Abandonner"
	choice.consequence = Consequence.new()
	choice.consequence.type = "game_over"
	e.choices.append(choice)
	var d = e.to_dict()
	assert_eq(d["type"], "choices")
	assert_eq(d["choices"].size(), 1)
	assert_eq(d["choices"][0]["text"], "Abandonner")
	assert_eq(d["choices"][0]["consequence"]["type"], "game_over")
	assert_true(d["choices"][0].has("conditions"), "Le champ conditions doit être présent")

func test_to_dict_auto_redirect():
	var e = Ending.new()
	e.type = "auto_redirect"
	e.auto_consequence = Consequence.new()
	e.auto_consequence.type = "to_be_continued"
	var d = e.to_dict()
	assert_eq(d["type"], "auto_redirect")
	assert_eq(d["consequence"]["type"], "to_be_continued")

func test_from_dict_choices():
	var d = {
		"type": "choices",
		"choices": [
			{
				"text": "Aller à gauche",
				"consequence": {"type": "redirect_sequence", "target": "seq-002"},
				"conditions": {}
			}
		]
	}
	var e = Ending.from_dict(d)
	assert_eq(e.type, "choices")
	assert_eq(e.choices.size(), 1)
	assert_eq(e.choices[0].text, "Aller à gauche")
	assert_eq(e.choices[0].consequence.type, "redirect_sequence")
	assert_eq(e.choices[0].consequence.target, "seq-002")

func test_from_dict_auto_redirect():
	var d = {
		"type": "auto_redirect",
		"consequence": {"type": "to_be_continued"}
	}
	var e = Ending.from_dict(d)
	assert_eq(e.type, "auto_redirect")
	assert_eq(e.auto_consequence.type, "to_be_continued")

# --- Tests par défaut ---

func test_default_values():
	var e = Ending.new()
	assert_eq(e.type, "")
	assert_eq(e.choices.size(), 0)
	assert_null(e.auto_consequence)

func test_empty_ending_invalid():
	var e = Ending.new()
	assert_false(e.is_valid())
