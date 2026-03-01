## Script de génération de l'histoire "L'Épreuve du Héros"
## Usage: godot --headless --path . -s tools/generate_epreuve_du_heros.gd
## Génère les fichiers YAML dans stories/epreuve-du-heros/

extends SceneTree

const StoryScript = preload("res://src/models/story.gd")
const ChapterScript = preload("res://src/models/chapter.gd")
const SceneDataScript = preload("res://src/models/scene_data.gd")
const SequenceScript = preload("res://src/models/sequence.gd")
const EndingScript = preload("res://src/models/ending.gd")
const ConsequenceScript = preload("res://src/models/consequence.gd")
const ChoiceScript = preload("res://src/models/choice.gd")
const DialogueScript = preload("res://src/models/dialogue.gd")
const ConditionModelScript = preload("res://src/models/condition.gd")
const ConditionRuleScript = preload("res://src/models/condition_rule.gd")
const VariableDefinitionScript = preload("res://src/models/variable_definition.gd")
const VariableEffectScript = preload("res://src/models/variable_effect.gd")
const StorySaver = preload("res://src/persistence/story_saver.gd")


func _init():
	var story = _build_epreuve_du_heros()
	var output_path = ProjectSettings.globalize_path("res://stories/epreuve-du-heros")
	print("Sauvegarde de l'histoire dans : " + output_path)
	StorySaver.save_story(story, output_path)
	print("✅ Histoire générée avec succès!")
	print("   Chapitres : " + str(story.chapters.size()))
	var total_scenes := 0
	for ch in story.chapters:
		total_scenes += ch.scenes.size()
	print("   Scènes    : " + str(total_scenes))
	print("   Variables : " + str(story.variables.size()))
	quit()


# ==============================================================================
# HELPERS
# ==============================================================================

func _dlg(character: String, text: String) -> RefCounted:
	var d = DialogueScript.new()
	d.character = character
	d.text = text
	return d


func _var(name: String, initial: String) -> RefCounted:
	var v = VariableDefinitionScript.new()
	v.var_name = name
	v.initial_value = initial
	return v


func _effect(variable: String, operation: String, value: String = "") -> RefCounted:
	var e = VariableEffectScript.new()
	e.variable = variable
	e.operation = operation
	e.value = value
	return e


func _cons(type: String, target: String = "") -> RefCounted:
	var c = ConsequenceScript.new()
	c.type = type
	c.target = target
	return c


func _cons_fx(type: String, target: String, effects: Array) -> RefCounted:
	var c = _cons(type, target)
	for e in effects:
		c.effects.append(e)
	return c


func _auto(consequence: RefCounted) -> RefCounted:
	var e = EndingScript.new()
	e.type = "auto_redirect"
	e.auto_consequence = consequence
	return e


func _choices(choices: Array) -> RefCounted:
	var e = EndingScript.new()
	e.type = "choices"
	e.choices = choices
	return e


func _choice(text: String, consequence: RefCounted, effects: Array = []) -> RefCounted:
	var c = ChoiceScript.new()
	c.text = text
	c.consequence = consequence
	for e in effects:
		c.effects.append(e)
	return c


func _rule(variable: String, operator: String, value: String, consequence: RefCounted) -> RefCounted:
	var r = ConditionRuleScript.new()
	r.variable = variable
	r.operator = operator
	r.value = value
	r.consequence = consequence
	return r


# ==============================================================================
# CONSTRUCTION DE L'HISTOIRE
# ==============================================================================

func _build_epreuve_du_heros() -> RefCounted:
	var story = StoryScript.new()
	story.title = "L'Épreuve du Héros"
	story.author = "Test Intégration"
	story.description = "Histoire de test d'intégration — 2 chapitres, 6 scènes, variables, conditions, choix."
	story.menu_title = "L'Épreuve du Héros"
	story.menu_subtitle = "Un voyage vers la gloire"
	story.variables.append(_var("force", "0"))
	story.variables.append(_var("sagesse", "0"))
	story.variables.append(_var("cristaux", "0"))

	# ==============================
	# CHAPITRE 1 : Les Épreuves de la Cité
	# ==============================
	var ch1 = ChapterScript.new()
	ch1.chapter_name = "Les Épreuves de la Cité"
	ch1.position = Vector2(100, 100)
	story.chapters.append(ch1)
	story.entry_point_uuid = ch1.uuid

	var sc1_defis = SceneDataScript.new()
	sc1_defis.scene_name = "La Salle des Défis"
	sc1_defis.position = Vector2(100, 100)

	var sc2_guerriere = SceneDataScript.new()
	sc2_guerriere.scene_name = "Victoire Guerrière"
	sc2_guerriere.position = Vector2(500, 100)

	var sc3_sage = SceneDataScript.new()
	sc3_sage.scene_name = "Victoire Sage"
	sc3_sage.position = Vector2(500, 300)

	ch1.scenes.append(sc1_defis)
	ch1.scenes.append(sc2_guerriere)
	ch1.scenes.append(sc3_sage)
	ch1.entry_point_uuid = sc1_defis.uuid

	# ==============================
	# CHAPITRE 2 : La Forêt Enchantée
	# ==============================
	var ch2 = ChapterScript.new()
	ch2.chapter_name = "La Forêt Enchantée"
	ch2.position = Vector2(700, 100)
	story.chapters.append(ch2)

	var sc4_foret = SceneDataScript.new()
	sc4_foret.scene_name = "L'Entrée de la Forêt"
	sc4_foret.position = Vector2(100, 100)

	var sc5_totale = SceneDataScript.new()
	sc5_totale.scene_name = "Victoire Totale"
	sc5_totale.position = Vector2(400, 100)

	var sc6_combat = SceneDataScript.new()
	sc6_combat.scene_name = "Combat Final"
	sc6_combat.position = Vector2(400, 300)

	ch2.scenes.append(sc4_foret)
	ch2.scenes.append(sc5_totale)
	ch2.scenes.append(sc6_combat)
	ch2.entry_point_uuid = sc4_foret.uuid

	# ==============================
	# SCÈNE 1 : La Salle des Défis
	# ==============================

	var seq_accueil = SequenceScript.new()
	seq_accueil.seq_name = "Accueil du Tournoi"
	seq_accueil.position = Vector2(0, 100)
	seq_accueil.dialogues.append(_dlg("Héraut Royal", "Bienvenue au Grand Tournoi des Héros!"))
	seq_accueil.dialogues.append(_dlg("Héraut Royal", "Trois épreuves vous attendent. Montrez votre valeur!"))
	seq_accueil.dialogues.append(_dlg("Héraut Royal", "Que le meilleur triomphe!"))

	var seq_ep1 = SequenceScript.new()
	seq_ep1.seq_name = "Épreuve 1 - Le Choix de la Voie"
	seq_ep1.position = Vector2(250, 100)
	seq_ep1.dialogues.append(_dlg("Maître du Tournoi", "Quelle voie choisissez-vous, valeureux héros?"))
	seq_ep1.dialogues.append(_dlg("Maître du Tournoi", "La force brute, la sagesse arcanique... ou la retraite?"))

	var seq_ep2 = SequenceScript.new()
	seq_ep2.seq_name = "Épreuve 2 - La Quête des Cristaux"
	seq_ep2.position = Vector2(500, 100)
	seq_ep2.dialogues.append(_dlg("Gardien des Cristaux", "La deuxième épreuve commence."))
	seq_ep2.dialogues.append(_dlg("Gardien des Cristaux", "Ces cristaux magiques augmenteront vos chances lors du jugement."))

	var seq_porte = SequenceScript.new()
	seq_porte.seq_name = "La Porte du Jugement"
	seq_porte.position = Vector2(750, 100)
	seq_porte.dialogues.append(_dlg("Voix Mystérieuse", "Approchez... Le jugement va commencer."))
	seq_porte.dialogues.append(_dlg("Voix Mystérieuse", "Vos choix ont forgé votre destin."))

	var cond_jugement = ConditionModelScript.new()
	cond_jugement.condition_name = "Jugement du Tournoi"
	cond_jugement.position = Vector2(1000, 100)

	sc1_defis.sequences.append(seq_accueil)
	sc1_defis.sequences.append(seq_ep1)
	sc1_defis.sequences.append(seq_ep2)
	sc1_defis.sequences.append(seq_porte)
	sc1_defis.conditions.append(cond_jugement)
	sc1_defis.entry_point_uuid = seq_accueil.uuid

	# Connexions visuelles dans la scène
	sc1_defis.connections.append({"from": seq_accueil.uuid, "to": seq_ep1.uuid})
	sc1_defis.connections.append({"from": seq_ep1.uuid, "to": seq_ep2.uuid})
	sc1_defis.connections.append({"from": seq_ep2.uuid, "to": seq_porte.uuid})
	sc1_defis.connections.append({"from": seq_porte.uuid, "to": cond_jugement.uuid})

	# Endings
	seq_accueil.ending = _auto(_cons("redirect_sequence", seq_ep1.uuid))

	seq_ep1.ending = _choices([
		_choice(
			"Voie du Guerrier — Maîtriser la force physique",
			_cons("redirect_sequence", seq_ep2.uuid),
			[_effect("force", "increment", "2")]
		),
		_choice(
			"Voie du Mage — Cultiver la sagesse arcanique",
			_cons("redirect_sequence", seq_ep2.uuid),
			[_effect("sagesse", "increment", "2")]
		),
		_choice(
			"Abandonner le tournoi et rentrer chez soi",
			_cons("game_over")
		),
	])

	seq_ep2.ending = _choices([
		_choice(
			"Récolter les cristaux magiques de la salle",
			_cons("redirect_sequence", seq_porte.uuid),
			[_effect("cristaux", "increment", "3")]
		),
		_choice(
			"Conserver son énergie et continuer sans cristaux",
			_cons("redirect_sequence", seq_porte.uuid)
		),
	])

	seq_porte.ending = _auto(_cons("redirect_condition", cond_jugement.uuid))

	cond_jugement.rules.append(_rule(
		"force", "greater_than_equal", "2",
		_cons("redirect_scene", sc2_guerriere.uuid)
	))
	cond_jugement.rules.append(_rule(
		"sagesse", "greater_than_equal", "2",
		_cons("redirect_scene", sc3_sage.uuid)
	))
	cond_jugement.default_consequence = _cons("game_over")

	# ==============================
	# SCÈNE 2 : Victoire Guerrière
	# ==============================
	var seq_celeb_guerriere = SequenceScript.new()
	seq_celeb_guerriere.seq_name = "Célébration Guerrière"
	seq_celeb_guerriere.position = Vector2(100, 100)
	seq_celeb_guerriere.dialogues.append(_dlg("Champion Guerrier", "Ma force m'a conduit jusqu'ici!"))
	seq_celeb_guerriere.dialogues.append(_dlg("Foule", "Longue vie au champion!"))
	seq_celeb_guerriere.dialogues.append(_dlg("Champion Guerrier", "La forêt enchantée m'attend..."))
	seq_celeb_guerriere.ending = _auto(_cons("redirect_chapter", ch2.uuid))
	sc2_guerriere.sequences.append(seq_celeb_guerriere)
	sc2_guerriere.entry_point_uuid = seq_celeb_guerriere.uuid

	# ==============================
	# SCÈNE 3 : Victoire Sage
	# ==============================
	var seq_celeb_sage = SequenceScript.new()
	seq_celeb_sage.seq_name = "Célébration Sage"
	seq_celeb_sage.position = Vector2(100, 100)
	seq_celeb_sage.dialogues.append(_dlg("Archimage", "La sagesse illumine tous les chemins!"))
	seq_celeb_sage.dialogues.append(_dlg("Conseil des Mages", "Vous avez honoré notre ordre."))
	seq_celeb_sage.dialogues.append(_dlg("Archimage", "Que votre quête continue dans la forêt..."))
	seq_celeb_sage.ending = _auto(_cons("redirect_chapter", ch2.uuid))
	sc3_sage.sequences.append(seq_celeb_sage)
	sc3_sage.entry_point_uuid = seq_celeb_sage.uuid

	# ==============================
	# SCÈNE 4 : L'Entrée de la Forêt
	# ==============================
	var seq_lisiere = SequenceScript.new()
	seq_lisiere.seq_name = "La Lisière de la Forêt"
	seq_lisiere.position = Vector2(0, 100)
	seq_lisiere.dialogues.append(_dlg("Narrateur", "Vous pénétrez dans la forêt enchantée..."))
	seq_lisiere.dialogues.append(_dlg("Esprit de la Forêt", "Seuls les dignes peuvent traverser mes bois."))
	seq_lisiere.dialogues.append(_dlg("Esprit de la Forêt", "Je vais évaluer ce que vous portez avec vous."))

	var cond_cristaux = ConditionModelScript.new()
	cond_cristaux.condition_name = "Vérification des Cristaux"
	cond_cristaux.position = Vector2(300, 100)

	sc4_foret.sequences.append(seq_lisiere)
	sc4_foret.conditions.append(cond_cristaux)
	sc4_foret.entry_point_uuid = seq_lisiere.uuid
	sc4_foret.connections.append({"from": seq_lisiere.uuid, "to": cond_cristaux.uuid})

	seq_lisiere.ending = _auto(_cons("redirect_condition", cond_cristaux.uuid))

	cond_cristaux.rules.append(_rule(
		"cristaux", "greater_than_equal", "3",
		_cons("redirect_scene", sc5_totale.uuid)
	))
	cond_cristaux.default_consequence = _cons("redirect_scene", sc6_combat.uuid)

	# ==============================
	# SCÈNE 5 : Victoire Totale
	# ==============================
	var seq_gloire = SequenceScript.new()
	seq_gloire.seq_name = "Gloire Absolue"
	seq_gloire.position = Vector2(100, 100)
	seq_gloire.dialogues.append(_dlg("Esprit de la Forêt", "Vous possédez les cristaux sacrés!"))
	seq_gloire.dialogues.append(_dlg("Roi de la Forêt", "La forêt vous appartient, grand champion!"))
	seq_gloire.dialogues.append(_dlg("Roi de la Forêt", "Votre légende traversera les âges..."))
	seq_gloire.ending = _auto(_cons("to_be_continued"))
	sc5_totale.sequences.append(seq_gloire)
	sc5_totale.entry_point_uuid = seq_gloire.uuid

	# ==============================
	# SCÈNE 6 : Combat Final
	# ==============================
	var seq_combat = SequenceScript.new()
	seq_combat.seq_name = "Le Combat Final"
	seq_combat.position = Vector2(0, 100)
	seq_combat.dialogues.append(_dlg("Gardien Ancien", "Vous n'avez pas de cristaux... Affrontez-moi!"))
	seq_combat.dialogues.append(_dlg("Gardien Ancien", "Seule la force ou la sagesse pourra me vaincre."))

	var cond_puissance = ConditionModelScript.new()
	cond_puissance.condition_name = "Vérification de Puissance"
	cond_puissance.position = Vector2(300, 100)

	sc6_combat.sequences.append(seq_combat)
	sc6_combat.conditions.append(cond_puissance)
	sc6_combat.entry_point_uuid = seq_combat.uuid
	sc6_combat.connections.append({"from": seq_combat.uuid, "to": cond_puissance.uuid})

	seq_combat.ending = _auto(_cons("redirect_condition", cond_puissance.uuid))

	cond_puissance.rules.append(_rule(
		"force", "greater_than_equal", "2",
		_cons("to_be_continued")
	))
	cond_puissance.rules.append(_rule(
		"sagesse", "greater_than_equal", "2",
		_cons("to_be_continued")
	))
	cond_puissance.default_consequence = _cons("game_over")

	return story
