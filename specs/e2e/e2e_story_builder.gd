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
