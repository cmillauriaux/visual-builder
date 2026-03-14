extends RefCounted

## Utilitaire partagé pour les tests e2e — factories de données.

const StoryScript = preload("res://src/models/story.gd")
const ChapterScript = preload("res://src/models/chapter.gd")
const SceneDataScript = preload("res://src/models/scene_data.gd")
const SequenceScript = preload("res://src/models/sequence.gd")
const EndingScript = preload("res://src/models/ending.gd")
const ConsequenceScript = preload("res://src/models/consequence.gd")
const ChoiceScript = preload("res://src/models/choice.gd")
const VariableDefinitionScript = preload("res://src/models/variable_definition.gd")
const VariableEffectScript = preload("res://src/models/variable_effect.gd")
const ConditionScript = preload("res://src/models/condition.gd")
const ConditionRuleScript = preload("res://src/models/condition_rule.gd")
const ForegroundScript = preload("res://src/models/foreground.gd")


## Crée une story minimale : 1 chapitre, 1 scène, 1 séquence, 1 dialogue.
static func make_minimal_story() -> RefCounted:
	var story = StoryScript.new()
	story.title = "Mon Histoire"
	story.author = "Auteur"

	var chapter = ChapterScript.new()
	chapter.chapter_name = "Chapitre 1"
	chapter.position = Vector2(100, 100)
	story.chapters.append(chapter)

	var scene = SceneDataScript.new()
	scene.scene_name = "Scène 1"
	scene.position = Vector2(100, 100)
	chapter.scenes.append(scene)

	var seq = SequenceScript.new()
	seq.seq_name = "Séquence 1"
	seq.position = Vector2(100, 100)
	scene.sequences.append(seq)

	var dlg = DialogueModel.new()
	dlg.character = "Narrateur"
	dlg.text = "Bienvenue dans votre nouvelle histoire."
	seq.dialogues.append(dlg)

	return story


## Crée une story branchante pour tester le play complet :
## - Chapitre 1 > Scène 1 > Séquence Intro (choix A → Seq A, choix B → game_over)
## - Chapitre 1 > Scène 1 > Séquence A (auto_redirect → Scène 2)
## - Chapitre 1 > Scène 2 > Séquence Finale (to_be_continued)
## - Variable "score" initialisée à "0", incrémentée par choix A
static func make_branching_story() -> RefCounted:
	var story = StoryScript.new()
	story.title = "Histoire Branchante"
	story.author = "Auteur"

	# Variable
	var var_def = VariableDefinitionScript.new()
	var_def.var_name = "score"
	var_def.initial_value = "0"
	story.variables.append(var_def)

	var chapter = ChapterScript.new()
	chapter.chapter_name = "Chapitre 1"
	chapter.position = Vector2(100, 100)
	story.chapters.append(chapter)

	# Scène 1
	var scene1 = SceneDataScript.new()
	scene1.scene_name = "Scène 1"
	scene1.position = Vector2(100, 100)
	chapter.scenes.append(scene1)

	# Séquence Intro — avec choix
	var seq_intro = SequenceScript.new()
	seq_intro.seq_name = "Intro"
	seq_intro.position = Vector2(100, 100)
	var dlg_intro = DialogueModel.new()
	dlg_intro.character = "Narrateur"
	dlg_intro.text = "Bienvenue, que choisissez-vous ?"
	seq_intro.dialogues.append(dlg_intro)
	scene1.sequences.append(seq_intro)

	# Séquence A — auto redirect vers scène 2
	var seq_a = SequenceScript.new()
	seq_a.seq_name = "Séquence A"
	seq_a.position = Vector2(400, 100)
	var dlg_a = DialogueModel.new()
	dlg_a.character = "Narrateur"
	dlg_a.text = "Vous avez choisi le chemin A."
	seq_a.dialogues.append(dlg_a)
	scene1.sequences.append(seq_a)

	# Scène 2
	var scene2 = SceneDataScript.new()
	scene2.scene_name = "Scène 2"
	scene2.position = Vector2(400, 100)
	chapter.scenes.append(scene2)

	# Séquence Finale
	var seq_finale = SequenceScript.new()
	seq_finale.seq_name = "Finale"
	seq_finale.position = Vector2(100, 100)
	var dlg_finale = DialogueModel.new()
	dlg_finale.character = "Narrateur"
	dlg_finale.text = "Fin de l'histoire."
	seq_finale.dialogues.append(dlg_finale)
	scene2.sequences.append(seq_finale)

	# Endings
	# Intro → choices: A (redirect_sequence → seq_a) ou B (game_over)
	var effect_a = VariableEffectScript.new()
	effect_a.variable = "score"
	effect_a.operation = "increment"
	effect_a.value = "10"

	seq_intro.ending = make_ending_choices([
		{"text": "Chemin A", "type": "redirect_sequence", "target": seq_a.uuid, "effects": [effect_a]},
		{"text": "Game Over", "type": "game_over", "target": ""},
	])

	# Seq A → auto redirect vers scène 2
	seq_a.ending = make_ending_auto("redirect_scene", scene2.uuid)

	# Finale → to_be_continued
	seq_finale.ending = make_ending_auto("to_be_continued", "")

	return story


## Story avec foregrounds : 1 ch, 1 sc, 1 seq, 1 dialogue, 2 foregrounds (z_order 0 et 5).
static func make_story_with_foregrounds() -> RefCounted:
	var story = make_minimal_story()
	var seq = story.chapters[0].scenes[0].sequences[0]
	var dlg = seq.dialogues[0]

	var fg1 = ForegroundScript.new()
	fg1.fg_name = "fg_front"
	fg1.image = ""
	fg1.z_order = 0
	fg1.scale = 1.0
	fg1.anchor_bg = Vector2(0.3, 0.5)
	fg1.anchor_fg = Vector2(0.5, 1.0)
	dlg.foregrounds.append(fg1)

	var fg2 = ForegroundScript.new()
	fg2.fg_name = "fg_back"
	fg2.image = ""
	fg2.z_order = 5
	fg2.scale = 0.8
	fg2.anchor_bg = Vector2(0.7, 0.5)
	fg2.anchor_fg = Vector2(0.5, 1.0)
	dlg.foregrounds.append(fg2)

	return story


## Story avec 2 séquences + 1 variable : pour tester l'ending editor avec targets.
static func make_story_with_two_sequences() -> RefCounted:
	var story = make_minimal_story()
	var scene = story.chapters[0].scenes[0]

	var seq2 = SequenceScript.new()
	seq2.seq_name = "Séquence 2"
	seq2.position = Vector2(400, 100)
	var dlg2 = DialogueModel.new()
	dlg2.character = "Bob"
	dlg2.text = "Deuxième séquence."
	seq2.dialogues.append(dlg2)
	scene.sequences.append(seq2)

	# Ending redirect de seq2 vers seq1
	var seq1 = scene.sequences[0]
	seq2.ending = make_ending_auto("redirect_sequence", seq1.uuid)

	# Variable
	var var_def = VariableDefinitionScript.new()
	var_def.var_name = "score"
	var_def.initial_value = "0"
	story.variables.append(var_def)

	return story


## Story avec 3 séquences, seq1 a 2 foregrounds : pour tester graph operations et copy/paste FGs.
static func make_story_with_multiple_sequences() -> RefCounted:
	var story = make_minimal_story()
	var scene = story.chapters[0].scenes[0]

	# Ajouter 2 foregrounds à seq1
	var dlg1 = scene.sequences[0].dialogues[0]
	var fg1 = ForegroundScript.new()
	fg1.fg_name = "fg1"
	fg1.image = ""
	fg1.z_order = 0
	dlg1.foregrounds.append(fg1)
	var fg2 = ForegroundScript.new()
	fg2.fg_name = "fg2"
	fg2.image = ""
	fg2.z_order = 3
	dlg1.foregrounds.append(fg2)

	# Séquence 2
	var seq2 = SequenceScript.new()
	seq2.seq_name = "Séquence 2"
	seq2.position = Vector2(400, 100)
	var dlg2 = DialogueModel.new()
	dlg2.character = "Bob"
	dlg2.text = "Texte 2."
	seq2.dialogues.append(dlg2)
	scene.sequences.append(seq2)

	# Séquence 3
	var seq3 = SequenceScript.new()
	seq3.seq_name = "Séquence 3"
	seq3.position = Vector2(700, 100)
	var dlg3 = DialogueModel.new()
	dlg3.character = "Charlie"
	dlg3.text = "Texte 3."
	seq3.dialogues.append(dlg3)
	scene.sequences.append(seq3)

	return story


## Story avec 3 dialogues distincts : pour tester l'édition de dialogues.
static func make_story_with_multiple_dialogues() -> RefCounted:
	var story = make_minimal_story()
	var seq = story.chapters[0].scenes[0].sequences[0]

	# Remplacer le dialogue par défaut par 3 dialogues
	seq.dialogues.clear()

	var dlg1 = DialogueModel.new()
	dlg1.character = "Alice"
	dlg1.text = "Premier dialogue."
	seq.dialogues.append(dlg1)

	var dlg2 = DialogueModel.new()
	dlg2.character = "Bob"
	dlg2.text = "Deuxième dialogue."
	seq.dialogues.append(dlg2)

	var dlg3 = DialogueModel.new()
	dlg3.character = "Charlie"
	dlg3.text = "Troisième dialogue."
	seq.dialogues.append(dlg3)

	return story


## Story multi-dialogues avec ending to_be_continued : pour tester history et skip.
static func make_multi_dialogue_story() -> RefCounted:
	var story = make_minimal_story()
	var seq = story.chapters[0].scenes[0].sequences[0]

	seq.dialogues.clear()
	for i in 4:
		var dlg = DialogueModel.new()
		dlg.character = "Narrateur"
		dlg.text = "Dialogue %d." % (i + 1)
		seq.dialogues.append(dlg)

	seq.ending = make_ending_auto("to_be_continued", "")
	return story


static func make_ending_auto(type: String, target: String) -> RefCounted:
	var ending = EndingScript.new()
	ending.type = "auto_redirect"
	var cons = ConsequenceScript.new()
	cons.type = type
	cons.target = target
	ending.auto_consequence = cons
	return ending


static func make_ending_choices(choices_data: Array) -> RefCounted:
	var ending = EndingScript.new()
	ending.type = "choices"
	for data in choices_data:
		var choice = ChoiceScript.new()
		choice.text = data["text"]
		var cons = ConsequenceScript.new()
		cons.type = data["type"]
		cons.target = data.get("target", "")
		choice.consequence = cons
		if data.has("effects"):
			choice.effects = data["effects"]
		ending.choices.append(choice)
	return ending
