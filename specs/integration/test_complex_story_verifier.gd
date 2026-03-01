extends GutTest

## Test d'intégration complexe pour le vérificateur d'histoire.
##
## Histoire: "L'Épreuve du Héros"
## Structure:
##   - 2 chapitres, 6 scènes, 12 noeuds
##   - Variables: force (int), sagesse (int), cristaux (int)
##   - Choix avec effets increment (×4 choices)
##   - Conditions: greater_than_equal (×4 conditions), 2 règles chacune
##   - Redirections: sequence, condition, scene, chapter
##   - Terminaisons: to_be_continued (×3), game_over (×3)
##   - Résultat attendu: success=true, 3 runs, 12 noeuds, 0 orphelins

const StoryVerifier = preload("res://src/services/story_verifier.gd")
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

var _verifier: RefCounted


func before_each():
	_verifier = StoryVerifier.new()


# ==============================================================================
# HELPERS
# ==============================================================================

func _make_dialogue(character: String, text: String) -> RefCounted:
	var d = DialogueScript.new()
	d.character = character
	d.text = text
	return d


func _make_variable(name: String, initial: String) -> RefCounted:
	var v = VariableDefinitionScript.new()
	v.var_name = name
	v.initial_value = initial
	return v


func _make_effect(variable: String, operation: String, value: String = "") -> RefCounted:
	var e = VariableEffectScript.new()
	e.variable = variable
	e.operation = operation
	e.value = value
	return e


func _make_consequence(type: String, target: String = "") -> RefCounted:
	var c = ConsequenceScript.new()
	c.type = type
	c.target = target
	return c


func _make_consequence_with_effects(type: String, target: String, effects: Array) -> RefCounted:
	var c = _make_consequence(type, target)
	for e in effects:
		c.effects.append(e)
	return c


func _make_ending_auto(consequence: RefCounted) -> RefCounted:
	var e = EndingScript.new()
	e.type = "auto_redirect"
	e.auto_consequence = consequence
	return e


func _make_choice(text: String, consequence: RefCounted, effects: Array = []) -> RefCounted:
	var c = ChoiceScript.new()
	c.text = text
	c.consequence = consequence
	for e in effects:
		c.effects.append(e)
	return c


func _make_rule(variable: String, operator: String, value: String, consequence: RefCounted) -> RefCounted:
	var r = ConditionRuleScript.new()
	r.variable = variable
	r.operator = operator
	r.value = value
	r.consequence = consequence
	return r


func _find_steps_by_type(path: Array, type: String) -> Array:
	var result := []
	for step in path:
		if step["type"] == type:
			result.append(step)
	return result


func _find_step_by_name(path: Array, name: String) -> Dictionary:
	for step in path:
		if step["name"] == name or step["name"].begins_with(name):
			return step
	return {}


# ==============================================================================
# CONSTRUCTION DE L'HISTOIRE "L'Épreuve du Héros"
#
# Parcours couverts par le vérificateur:
#   Run 1: ep1[0:Guerrier] → ep2[0:Cristaux] → cond_jugement(force≥2) →
#          celeb_guerriere → ch2 → cond_cristaux(3≥3) → gloire → to_be_continued
#   Run 2: ep1[1:Mage] → ep2[1:Energie] → cond_jugement(sagesse≥2) →
#          celeb_sage → ch2 → cond_cristaux(0<3) → combat → cond_puissance(sagesse≥2) → to_be_continued
#   Run 3: ep1[2:Abandonner] → game_over
# ==============================================================================

func _build_epreuve_du_heros() -> RefCounted:
	var story = StoryScript.new()
	story.title = "L'Épreuve du Héros"
	story.author = "Test Intégration"
	story.description = "Histoire de test d'intégration pour le vérificateur"
	story.variables.append(_make_variable("force", "0"))
	story.variables.append(_make_variable("sagesse", "0"))
	story.variables.append(_make_variable("cristaux", "0"))

	# ==============================
	# CHAPITRE 1 : Les Épreuves de la Cité
	# ==============================
	var ch1 = ChapterScript.new()
	ch1.chapter_name = "Les Épreuves de la Cité"
	ch1.position = Vector2(100, 100)
	story.chapters.append(ch1)
	story.entry_point_uuid = ch1.uuid

	# --- Scène 1 : La Salle des Défis ---
	var sc1_defis = SceneDataScript.new()
	sc1_defis.scene_name = "La Salle des Défis"
	sc1_defis.position = Vector2(100, 100)
	ch1.scenes.append(sc1_defis)
	ch1.entry_point_uuid = sc1_defis.uuid

	# --- Scène 2 : Victoire Guerrière ---
	var sc2_guerriere = SceneDataScript.new()
	sc2_guerriere.scene_name = "Victoire Guerrière"
	sc2_guerriere.position = Vector2(500, 100)
	ch1.scenes.append(sc2_guerriere)

	# --- Scène 3 : Victoire Sage ---
	var sc3_sage = SceneDataScript.new()
	sc3_sage.scene_name = "Victoire Sage"
	sc3_sage.position = Vector2(500, 300)
	ch1.scenes.append(sc3_sage)

	# ==============================
	# CHAPITRE 2 : La Forêt Enchantée
	# ==============================
	var ch2 = ChapterScript.new()
	ch2.chapter_name = "La Forêt Enchantée"
	ch2.position = Vector2(700, 100)
	story.chapters.append(ch2)

	# --- Scène 4 : L'Entrée de la Forêt ---
	var sc4_foret = SceneDataScript.new()
	sc4_foret.scene_name = "L'Entrée de la Forêt"
	sc4_foret.position = Vector2(100, 100)
	ch2.scenes.append(sc4_foret)
	ch2.entry_point_uuid = sc4_foret.uuid

	# --- Scène 5 : Victoire Totale ---
	var sc5_totale = SceneDataScript.new()
	sc5_totale.scene_name = "Victoire Totale"
	sc5_totale.position = Vector2(400, 100)
	ch2.scenes.append(sc5_totale)

	# --- Scène 6 : Combat Final ---
	var sc6_combat = SceneDataScript.new()
	sc6_combat.scene_name = "Combat Final"
	sc6_combat.position = Vector2(400, 300)
	ch2.scenes.append(sc6_combat)

	# ==============================
	# NOEUDS : Scène 1 — La Salle des Défis
	# ==============================

	# Accueil (auto → Épreuve 1)
	var seq_accueil = SequenceScript.new()
	seq_accueil.seq_name = "Accueil du Tournoi"
	seq_accueil.position = Vector2(0, 100)
	seq_accueil.dialogues.append(_make_dialogue("Héraut", "Bienvenue au Grand Tournoi des Héros!"))
	seq_accueil.dialogues.append(_make_dialogue("Héraut", "Trois épreuves vous attendent. Montrez votre valeur!"))

	# Épreuve 1 : choix de la voie (3 choices)
	var seq_ep1 = SequenceScript.new()
	seq_ep1.seq_name = "Épreuve 1 - Le Choix de la Voie"
	seq_ep1.position = Vector2(200, 100)
	seq_ep1.dialogues.append(_make_dialogue("Maître du Tournoi", "Quelle voie choisissez-vous, valeureux héros?"))
	seq_ep1.dialogues.append(_make_dialogue("Maître du Tournoi", "La force, la sagesse... ou la fuite?"))

	# Épreuve 2 : quête des cristaux (2 choices)
	var seq_ep2 = SequenceScript.new()
	seq_ep2.seq_name = "Épreuve 2 - La Quête des Cristaux"
	seq_ep2.position = Vector2(400, 100)
	seq_ep2.dialogues.append(_make_dialogue("Gardien des Cristaux", "La deuxième épreuve commence."))
	seq_ep2.dialogues.append(_make_dialogue("Gardien des Cristaux", "Récolterez-vous les cristaux magiques de la salle?"))

	# La Porte du Jugement (auto → condition)
	var seq_porte = SequenceScript.new()
	seq_porte.seq_name = "La Porte du Jugement"
	seq_porte.position = Vector2(600, 100)
	seq_porte.dialogues.append(_make_dialogue("Voix Mystérieuse", "Le jugement approche. Êtes-vous prêt?"))

	# Condition : Jugement du Tournoi
	var cond_jugement = ConditionModelScript.new()
	cond_jugement.condition_name = "Jugement du Tournoi"
	cond_jugement.position = Vector2(800, 100)

	# Relier les noeuds à la scène
	sc1_defis.sequences.append(seq_accueil)
	sc1_defis.sequences.append(seq_ep1)
	sc1_defis.sequences.append(seq_ep2)
	sc1_defis.sequences.append(seq_porte)
	sc1_defis.conditions.append(cond_jugement)
	sc1_defis.entry_point_uuid = seq_accueil.uuid

	# Endings de la scène 1
	seq_accueil.ending = _make_ending_auto(_make_consequence("redirect_sequence", seq_ep1.uuid))

	seq_ep1.ending = EndingScript.new()
	seq_ep1.ending.type = "choices"
	seq_ep1.ending.choices.append(_make_choice(
		"Voie du Guerrier - Maîtriser la force physique",
		_make_consequence("redirect_sequence", seq_ep2.uuid),
		[_make_effect("force", "increment", "2")]
	))
	seq_ep1.ending.choices.append(_make_choice(
		"Voie du Mage - Cultiver la sagesse arcanique",
		_make_consequence("redirect_sequence", seq_ep2.uuid),
		[_make_effect("sagesse", "increment", "2")]
	))
	seq_ep1.ending.choices.append(_make_choice(
		"Abandonner le tournoi et renter chez soi",
		_make_consequence("game_over")
	))

	seq_ep2.ending = EndingScript.new()
	seq_ep2.ending.type = "choices"
	seq_ep2.ending.choices.append(_make_choice(
		"Récolter les cristaux magiques de la salle",
		_make_consequence("redirect_sequence", seq_porte.uuid),
		[_make_effect("cristaux", "increment", "3")]
	))
	seq_ep2.ending.choices.append(_make_choice(
		"Conserver son énergie et continuer sans cristaux",
		_make_consequence("redirect_sequence", seq_porte.uuid)
	))

	seq_porte.ending = _make_ending_auto(_make_consequence("redirect_condition", cond_jugement.uuid))

	# Règles de la condition Jugement
	cond_jugement.rules.append(_make_rule(
		"force", "greater_than_equal", "2",
		_make_consequence("redirect_scene", sc2_guerriere.uuid)
	))
	cond_jugement.rules.append(_make_rule(
		"sagesse", "greater_than_equal", "2",
		_make_consequence("redirect_scene", sc3_sage.uuid)
	))
	cond_jugement.default_consequence = _make_consequence("game_over")

	# ==============================
	# NOEUDS : Scène 2 — Victoire Guerrière
	# ==============================
	var seq_celeb_guerriere = SequenceScript.new()
	seq_celeb_guerriere.seq_name = "Célébration Guerrière"
	seq_celeb_guerriere.position = Vector2(100, 100)
	seq_celeb_guerriere.dialogues.append(_make_dialogue("Champion Guerrier", "La force prime sur tout! Je suis prêt pour la prochaine épreuve!"))
	seq_celeb_guerriere.ending = _make_ending_auto(_make_consequence("redirect_chapter", ch2.uuid))
	sc2_guerriere.sequences.append(seq_celeb_guerriere)
	sc2_guerriere.entry_point_uuid = seq_celeb_guerriere.uuid

	# ==============================
	# NOEUDS : Scène 3 — Victoire Sage
	# ==============================
	var seq_celeb_sage = SequenceScript.new()
	seq_celeb_sage.seq_name = "Célébration Sage"
	seq_celeb_sage.position = Vector2(100, 100)
	seq_celeb_sage.dialogues.append(_make_dialogue("Archimage", "La sagesse illumine le chemin vers la victoire!"))
	seq_celeb_sage.ending = _make_ending_auto(_make_consequence("redirect_chapter", ch2.uuid))
	sc3_sage.sequences.append(seq_celeb_sage)
	sc3_sage.entry_point_uuid = seq_celeb_sage.uuid

	# ==============================
	# NOEUDS : Scène 4 — L'Entrée de la Forêt
	# ==============================
	var seq_lisiere = SequenceScript.new()
	seq_lisiere.seq_name = "La Lisière de la Forêt"
	seq_lisiere.position = Vector2(0, 100)
	seq_lisiere.dialogues.append(_make_dialogue("Narrateur", "Vous entrez dans la forêt enchantée..."))
	seq_lisiere.dialogues.append(_make_dialogue("Esprit de la Forêt", "Seuls les dignes peuvent traverser ce lieu."))

	var cond_cristaux = ConditionModelScript.new()
	cond_cristaux.condition_name = "Vérification des Cristaux"
	cond_cristaux.position = Vector2(250, 100)

	sc4_foret.sequences.append(seq_lisiere)
	sc4_foret.conditions.append(cond_cristaux)
	sc4_foret.entry_point_uuid = seq_lisiere.uuid

	seq_lisiere.ending = _make_ending_auto(_make_consequence("redirect_condition", cond_cristaux.uuid))

	cond_cristaux.rules.append(_make_rule(
		"cristaux", "greater_than_equal", "3",
		_make_consequence("redirect_scene", sc5_totale.uuid)
	))
	cond_cristaux.default_consequence = _make_consequence("redirect_scene", sc6_combat.uuid)

	# ==============================
	# NOEUDS : Scène 5 — Victoire Totale
	# ==============================
	var seq_gloire = SequenceScript.new()
	seq_gloire.seq_name = "Gloire Absolue"
	seq_gloire.position = Vector2(100, 100)
	seq_gloire.dialogues.append(_make_dialogue("Roi de la Cité", "Vous êtes notre grand champion! La forêt vous appartient!"))
	seq_gloire.dialogues.append(_make_dialogue("Roi de la Cité", "Votre légende traversera les âges."))
	seq_gloire.ending = _make_ending_auto(_make_consequence("to_be_continued"))
	sc5_totale.sequences.append(seq_gloire)
	sc5_totale.entry_point_uuid = seq_gloire.uuid

	# ==============================
	# NOEUDS : Scène 6 — Combat Final
	# ==============================
	var seq_combat = SequenceScript.new()
	seq_combat.seq_name = "Le Combat Final"
	seq_combat.position = Vector2(0, 100)
	seq_combat.dialogues.append(_make_dialogue("Gardien Ancien", "Vous n'aurez pas la forêt sans me combattre!"))

	var cond_puissance = ConditionModelScript.new()
	cond_puissance.condition_name = "Vérification de Puissance"
	cond_puissance.position = Vector2(250, 100)

	sc6_combat.sequences.append(seq_combat)
	sc6_combat.conditions.append(cond_puissance)
	sc6_combat.entry_point_uuid = seq_combat.uuid

	seq_combat.ending = _make_ending_auto(_make_consequence("redirect_condition", cond_puissance.uuid))

	cond_puissance.rules.append(_make_rule(
		"force", "greater_than_equal", "2",
		_make_consequence("to_be_continued")
	))
	cond_puissance.rules.append(_make_rule(
		"sagesse", "greater_than_equal", "2",
		_make_consequence("to_be_continued")
	))
	cond_puissance.default_consequence = _make_consequence("game_over")

	return story


# ==============================================================================
# TESTS DE L'HISTOIRE VALIDE
# ==============================================================================

func test_complex_valid_story_succeeds():
	var story = _build_epreuve_du_heros()
	var report = _verifier.verify(story)
	assert_true(report["success"], "L'histoire valide doit passer la vérification")


func test_complex_valid_story_no_orphans():
	var story = _build_epreuve_du_heros()
	var report = _verifier.verify(story)
	assert_eq(report["orphan_nodes"].size(), 0, "Aucun noeud orphelin attendu")


func test_complex_valid_story_three_runs():
	var story = _build_epreuve_du_heros()
	var report = _verifier.verify(story)
	assert_eq(report["total_runs"], 3, "3 parcours nécessaires pour couvrir tous les choix")


func test_complex_valid_story_all_nodes_visited():
	var story = _build_epreuve_du_heros()
	var report = _verifier.verify(story)
	assert_eq(report["all_nodes"], 12, "12 noeuds au total (8 séquences + 4 conditions)")
	assert_eq(report["visited_nodes"], 12, "Tous les 12 noeuds doivent être visités")


func test_complex_valid_story_all_runs_valid():
	var story = _build_epreuve_du_heros()
	var report = _verifier.verify(story)
	for run in report["runs"]:
		assert_true(run["is_valid"],
			"Run %d doit être valide (reason: %s)" % [run["run_index"], run["ending_reason"]])


# ==============================================================================
# TESTS DES PARCOURS INDIVIDUELS
# ==============================================================================

func test_run1_takes_guerrier_path():
	## Run 1: choice 0 (Guerrier) → cristaux → force >= 2 → Victoire Guerrière → Victoire Totale
	var story = _build_epreuve_du_heros()
	var report = _verifier.verify(story)
	var run1 = report["runs"][0]

	assert_eq(run1["ending_reason"], "to_be_continued", "Run 1 → to_be_continued via Victoire Totale")

	# Vérifier que le chemin contient le choix Guerrier (choice_index 0)
	var choice_steps = _find_steps_by_type(run1["path"], "choice")
	assert_true(choice_steps.size() >= 1, "Au moins un choix effectué dans run 1")
	var first_choice = choice_steps[0]
	assert_eq(first_choice["choice_index"], 0, "Run 1 prend le choix 0 (Guerrier)")


func test_run2_takes_mage_path():
	## Run 2: choice 1 (Mage) → sagesse >= 2 → Victoire Sage → Combat Final → to_be_continued
	var story = _build_epreuve_du_heros()
	var report = _verifier.verify(story)
	var run2 = report["runs"][1]

	assert_eq(run2["ending_reason"], "to_be_continued", "Run 2 → to_be_continued via Combat Final")

	# Le premier choix de run 2 est le choix 1 (Mage)
	var choice_steps = _find_steps_by_type(run2["path"], "choice")
	assert_true(choice_steps.size() >= 1, "Au moins un choix effectué dans run 2")
	var first_choice = choice_steps[0]
	assert_eq(first_choice["choice_index"], 1, "Run 2 prend le choix 1 (Mage)")


func test_run3_ends_in_game_over():
	## Run 3: choice 2 (Abandonner) → game_over immédiat
	var story = _build_epreuve_du_heros()
	var report = _verifier.verify(story)
	var run3 = report["runs"][2]

	assert_eq(run3["ending_reason"], "game_over", "Run 3 → game_over (Abandonner)")
	# game_over EST une terminaison valide (is_valid = true)
	assert_true(run3["is_valid"], "game_over est une terminaison valide")


func test_run1_visits_guerriere_scene():
	var story = _build_epreuve_du_heros()
	var report = _verifier.verify(story)
	var run1 = report["runs"][0]

	# Le chemin contient les noeuds (séquences/conditions), pas les noms de scènes
	var celeb_step = _find_step_by_name(run1["path"], "Célébration Guerrière")
	assert_false(celeb_step.is_empty(), "Run 1 passe par la séquence 'Célébration Guerrière'")


func test_run2_visits_sage_and_combat_scenes():
	var story = _build_epreuve_du_heros()
	var report = _verifier.verify(story)
	var run2 = report["runs"][1]

	var celeb_sage_step = _find_step_by_name(run2["path"], "Célébration Sage")
	assert_false(celeb_sage_step.is_empty(), "Run 2 passe par la Célébration Sage")

	var combat_step = _find_step_by_name(run2["path"], "Le Combat Final")
	assert_false(combat_step.is_empty(), "Run 2 passe par le Combat Final")


func test_run1_visits_gloire_not_combat():
	var story = _build_epreuve_du_heros()
	var report = _verifier.verify(story)
	var run1 = report["runs"][0]

	var gloire_step = _find_step_by_name(run1["path"], "Gloire Absolue")
	assert_false(gloire_step.is_empty(), "Run 1 (cristaux=3) passe par Gloire Absolue")

	var combat_step = _find_step_by_name(run1["path"], "Le Combat Final")
	assert_true(combat_step.is_empty(), "Run 1 ne passe pas par le Combat Final")


func test_run2_visits_combat_not_gloire():
	var story = _build_epreuve_du_heros()
	var report = _verifier.verify(story)
	var run2 = report["runs"][1]

	var combat_step = _find_step_by_name(run2["path"], "Le Combat Final")
	assert_false(combat_step.is_empty(), "Run 2 (sans cristaux) passe par le Combat Final")

	var gloire_step = _find_step_by_name(run2["path"], "Gloire Absolue")
	assert_true(gloire_step.is_empty(), "Run 2 ne passe pas par Gloire Absolue")


# ==============================================================================
# TESTS DES EFFETS DE VARIABLES
# ==============================================================================

func test_run1_force_applied_correctly():
	## Run 1 choisit Guerrier (+2 force) puis cristaux (+3).
	## Le chemin doit passer par la condition Jugement avec force >= 2.
	var story = _build_epreuve_du_heros()
	var report = _verifier.verify(story)
	var run1 = report["runs"][0]

	# Vérifier que le chemin passe par la condition Jugement
	var jugement_step = _find_step_by_name(run1["path"], "Jugement du Tournoi")
	assert_false(jugement_step.is_empty(), "Run 1 passe par la condition Jugement")

	# La séquence 'Célébration Guerrière' (dans la scène Victoire Guerrière) prouve que force >= 2
	var guerriere_step = _find_step_by_name(run1["path"], "Célébration Guerrière")
	assert_false(guerriere_step.is_empty(), "Run 1 va vers Célébration Guerrière (force >= 2 confirmé)")


func test_run2_sagesse_applied_correctly():
	## Run 2 choisit Mage (+2 sagesse). Le jugement doit prendre la règle sagesse >= 2.
	var story = _build_epreuve_du_heros()
	var report = _verifier.verify(story)
	var run2 = report["runs"][1]

	# 'Célébration Sage' est la séquence dans la scène Victoire Sage
	var sage_step = _find_step_by_name(run2["path"], "Célébration Sage")
	assert_false(sage_step.is_empty(), "Run 2 va vers Célébration Sage (sagesse >= 2 confirmé)")


func test_run1_cristaux_determine_final_path():
	## Run 1: cristaux = 3 → Victoire Totale (pas Combat Final)
	## Run 2: cristaux = 0 → Combat Final (pas Victoire Totale)
	var story = _build_epreuve_du_heros()
	var report = _verifier.verify(story)

	var run1 = report["runs"][0]
	var cond_cristaux_step_r1 = _find_step_by_name(run1["path"], "Vérification des Cristaux")
	assert_false(cond_cristaux_step_r1.is_empty(), "Run 1 passe par Vérification des Cristaux")

	var run2 = report["runs"][1]
	var cond_cristaux_step_r2 = _find_step_by_name(run2["path"], "Vérification des Cristaux")
	assert_false(cond_cristaux_step_r2.is_empty(), "Run 2 passe par Vérification des Cristaux")


# ==============================================================================
# TESTS DE LA STRUCTURE DU RAPPORT
# ==============================================================================

func test_report_structure_complete():
	var story = _build_epreuve_du_heros()
	var report = _verifier.verify(story)

	assert_true(report.has("success"))
	assert_true(report.has("runs"))
	assert_true(report.has("orphan_nodes"))
	assert_true(report.has("total_runs"))
	assert_true(report.has("all_nodes"))
	assert_true(report.has("visited_nodes"))


func test_each_run_has_path():
	var story = _build_epreuve_du_heros()
	var report = _verifier.verify(story)

	for run in report["runs"]:
		assert_true(run.has("run_index"))
		assert_true(run.has("path"))
		assert_true(run.has("ending_reason"))
		assert_true(run.has("is_valid"))
		assert_true(run["path"].size() > 0, "Chaque run doit avoir au moins un noeud dans son chemin")


func test_run1_path_includes_accueil():
	## Le premier noeud visité doit être l'Accueil (entry point de la scène 1)
	var story = _build_epreuve_du_heros()
	var report = _verifier.verify(story)
	var run1 = report["runs"][0]
	assert_true(run1["path"].size() > 0)
	var first_step = run1["path"][0]
	assert_eq(first_step["name"], "Accueil du Tournoi", "Le premier noeud doit être l'Accueil")
	assert_eq(first_step["type"], "sequence")


func test_path_contains_sequence_and_condition_types():
	var story = _build_epreuve_du_heros()
	var report = _verifier.verify(story)
	var run1 = report["runs"][0]

	var seq_steps = _find_steps_by_type(run1["path"], "sequence")
	var cond_steps = _find_steps_by_type(run1["path"], "condition")
	var choice_steps = _find_steps_by_type(run1["path"], "choice")

	assert_true(seq_steps.size() > 0, "Run 1 doit contenir des étapes de type sequence")
	assert_true(cond_steps.size() > 0, "Run 1 doit contenir des étapes de type condition")
	assert_true(choice_steps.size() > 0, "Run 1 doit contenir des étapes de type choice")


# ==============================================================================
# HISTOIRE AVEC ORPHELIN CONNU
# "Le Labyrinthe du Destin" — 1 noeud orphelin intentionnel
#
# Structure:
#   Ch1 Sc1: entry → seq_debut → cond_karma (karma >= 10 toujours vrai)
#              ├─ karma >= 10 → seq_triomphe → game_over
#              └─ default → seq_ruine (JAMAIS ATTEINT car karma=10)
# Résultat attendu: success=false, orphan: seq_ruine
# ==============================================================================

func _build_labyrinthe_du_destin() -> RefCounted:
	var story = StoryScript.new()
	story.title = "Le Labyrinthe du Destin"
	story.variables.append(_make_variable("karma", "10"))

	var ch1 = ChapterScript.new()
	ch1.chapter_name = "Le Labyrinthe"
	ch1.position = Vector2(100, 100)
	story.chapters.append(ch1)
	story.entry_point_uuid = ch1.uuid

	var sc1 = SceneDataScript.new()
	sc1.scene_name = "Le Couloir"
	sc1.position = Vector2(100, 100)
	ch1.scenes.append(sc1)
	ch1.entry_point_uuid = sc1.uuid

	# seq_debut: intro, auto → condition
	var seq_debut = SequenceScript.new()
	seq_debut.seq_name = "L'Entrée du Labyrinthe"
	seq_debut.position = Vector2(0, 100)
	seq_debut.dialogues.append(_make_dialogue("Narrateur", "Vous entrez dans le labyrinthe..."))

	# cond_karma: karma >= 10 → triomphe; default → ruine
	var cond_karma = ConditionModelScript.new()
	cond_karma.condition_name = "Évaluation du Karma"
	cond_karma.position = Vector2(200, 100)

	# seq_triomphe: game_over (reachable)
	var seq_triomphe = SequenceScript.new()
	seq_triomphe.seq_name = "Le Triomphe"
	seq_triomphe.position = Vector2(400, 50)
	seq_triomphe.dialogues.append(_make_dialogue("Destin", "Votre karma vous a mené à la gloire!"))
	seq_triomphe.ending = _make_ending_auto(_make_consequence("game_over"))

	# seq_ruine: to_be_continued (ORPHELIN — karma toujours >= 10)
	var seq_ruine = SequenceScript.new()
	seq_ruine.seq_name = "La Ruine"
	seq_ruine.position = Vector2(400, 200)
	seq_ruine.dialogues.append(_make_dialogue("Destin", "Votre karma vous condamne..."))
	seq_ruine.ending = _make_ending_auto(_make_consequence("to_be_continued"))

	sc1.sequences.append(seq_debut)
	sc1.sequences.append(seq_triomphe)
	sc1.sequences.append(seq_ruine)
	sc1.conditions.append(cond_karma)
	sc1.entry_point_uuid = seq_debut.uuid

	seq_debut.ending = _make_ending_auto(_make_consequence("redirect_condition", cond_karma.uuid))

	# karma toujours 10 au départ, donc la règle >= 10 matche toujours
	cond_karma.rules.append(_make_rule(
		"karma", "greater_than_equal", "10",
		_make_consequence("redirect_sequence", seq_triomphe.uuid)
	))
	cond_karma.default_consequence = _make_consequence("redirect_sequence", seq_ruine.uuid)

	return story


func test_broken_story_fails():
	var story = _build_labyrinthe_du_destin()
	var report = _verifier.verify(story)
	assert_false(report["success"], "L'histoire avec orphelin doit échouer la vérification")


func test_broken_story_detects_orphan():
	var story = _build_labyrinthe_du_destin()
	var report = _verifier.verify(story)
	assert_eq(report["orphan_nodes"].size(), 1, "1 noeud orphelin attendu")
	assert_eq(report["orphan_nodes"][0]["name"], "La Ruine", "Le noeud orphelin est 'La Ruine'")
	assert_eq(report["orphan_nodes"][0]["type"], "sequence")


func test_broken_story_run_is_valid():
	## Même si un orphelin existe, les runs sont valides (game_over).
	## Le vérificateur fait au moins 2 runs avant de s'arrêter (condition run_index > 0).
	var story = _build_labyrinthe_du_destin()
	var report = _verifier.verify(story)
	assert_true(report["runs"].size() >= 1, "Au moins 1 run effectué")
	assert_eq(report["runs"][0]["ending_reason"], "game_over")
	assert_true(report["runs"][0]["is_valid"])


func test_broken_story_orphan_location():
	var story = _build_labyrinthe_du_destin()
	var report = _verifier.verify(story)
	var orphan = report["orphan_nodes"][0]
	assert_eq(orphan["chapter"], "Le Labyrinthe")
	assert_eq(orphan["scene"], "Le Couloir")


# ==============================================================================
# HISTOIRE AVEC BOUCLE DÉTECTÉE
# "Le Piège Éternel" — boucle infinie avec variables changeantes
#
# Structure:
#   Ch1 Sc1: seq_piege → cond_compteur
#             ├─ compteur >= 5 → to_be_continued
#             └─ default → seq_piege (boucle + increment compteur)
#
# Le vérificateur doit détecter la boucle via l'état composite (uuid + variables)
# ==============================================================================

func _build_piege_eternel() -> RefCounted:
	var story = StoryScript.new()
	story.title = "Le Piège Éternel"
	story.variables.append(_make_variable("compteur", "0"))

	var ch1 = ChapterScript.new()
	ch1.chapter_name = "Le Piège"
	ch1.position = Vector2(100, 100)
	story.chapters.append(ch1)
	story.entry_point_uuid = ch1.uuid

	var sc1 = SceneDataScript.new()
	sc1.scene_name = "La Chambre"
	sc1.position = Vector2(100, 100)
	ch1.scenes.append(sc1)
	ch1.entry_point_uuid = sc1.uuid

	var seq_piege = SequenceScript.new()
	seq_piege.seq_name = "Le Piège"
	seq_piege.position = Vector2(0, 100)
	seq_piege.dialogues.append(_make_dialogue("Voix", "Vous êtes piégé dans ce cycle..."))

	var cond_compteur = ConditionModelScript.new()
	cond_compteur.condition_name = "Vérification du Compteur"
	cond_compteur.position = Vector2(200, 100)

	sc1.sequences.append(seq_piege)
	sc1.conditions.append(cond_compteur)
	sc1.entry_point_uuid = seq_piege.uuid

	# Ending: auto → condition, avec incrément du compteur
	var cons_to_cond = ConsequenceScript.new()
	cons_to_cond.type = "redirect_condition"
	cons_to_cond.target = cond_compteur.uuid
	cons_to_cond.effects.append(_make_effect("compteur", "increment", "1"))
	seq_piege.ending = _make_ending_auto(cons_to_cond)

	# Condition: compteur >= 5 → to_be_continued; default → redirect_sequence (boucle)
	cond_compteur.rules.append(_make_rule(
		"compteur", "greater_than_equal", "5",
		_make_consequence("to_be_continued")
	))
	cond_compteur.default_consequence = _make_consequence("redirect_sequence", seq_piege.uuid)

	return story


func test_loop_story_terminates():
	## La boucle avec variable changeante doit se terminer (to_be_continued quand compteur >= 5)
	var story = _build_piege_eternel()
	var report = _verifier.verify(story)
	assert_eq(report["runs"][0]["ending_reason"], "to_be_continued",
		"La boucle doit se terminer quand compteur >= 5")


func test_loop_story_is_valid():
	var story = _build_piege_eternel()
	var report = _verifier.verify(story)
	assert_true(report["success"], "La boucle qui se termine est valide")


# ==============================================================================
# HISTOIRE AVEC BOUCLE INFINIE (variables fixes)
# ==============================================================================

func _build_boucle_infinie() -> RefCounted:
	var story = StoryScript.new()
	story.title = "La Boucle Infinie"

	var ch1 = ChapterScript.new()
	ch1.chapter_name = "L'Enfer"
	ch1.position = Vector2(100, 100)
	story.chapters.append(ch1)
	story.entry_point_uuid = ch1.uuid

	var sc1 = SceneDataScript.new()
	sc1.scene_name = "La Boucle"
	sc1.position = Vector2(100, 100)
	ch1.scenes.append(sc1)
	ch1.entry_point_uuid = sc1.uuid

	var seq_a = SequenceScript.new()
	seq_a.seq_name = "Séquence A"
	seq_a.position = Vector2(0, 100)

	var seq_b = SequenceScript.new()
	seq_b.seq_name = "Séquence B"
	seq_b.position = Vector2(200, 100)

	sc1.sequences.append(seq_a)
	sc1.sequences.append(seq_b)
	sc1.entry_point_uuid = seq_a.uuid

	seq_a.ending = _make_ending_auto(_make_consequence("redirect_sequence", seq_b.uuid))
	seq_b.ending = _make_ending_auto(_make_consequence("redirect_sequence", seq_a.uuid))

	return story


func test_infinite_loop_detected():
	var story = _build_boucle_infinie()
	var report = _verifier.verify(story)
	assert_false(report["success"])
	assert_eq(report["runs"][0]["ending_reason"], "loop_detected")
	assert_false(report["runs"][0]["is_valid"])


# ==============================================================================
# TESTS MULTI-SCÈNES ET MULTI-CHAPITRES (vérification globale)
# ==============================================================================

func test_complex_story_chapter_count():
	var story = _build_epreuve_du_heros()
	assert_eq(story.chapters.size(), 2, "L'histoire doit avoir 2 chapitres")


func test_complex_story_scene_count():
	var story = _build_epreuve_du_heros()
	var total_scenes := 0
	for ch in story.chapters:
		total_scenes += ch.scenes.size()
	assert_eq(total_scenes, 6, "L'histoire doit avoir 6 scènes au total")


func test_complex_story_node_count_per_chapter():
	var story = _build_epreuve_du_heros()
	var report = _verifier.verify(story)
	# Chapter 1: 4 seq + 1 cond (sc1) + 1 seq (sc2) + 1 seq (sc3) = 7 nodes
	# Chapter 2: 1 seq + 1 cond (sc4) + 1 seq (sc5) + 1 seq + 1 cond (sc6) = 5 nodes
	assert_eq(report["all_nodes"], 12)


func test_complex_story_variable_count():
	var story = _build_epreuve_du_heros()
	assert_eq(story.variables.size(), 3, "3 variables: force, sagesse, cristaux")
	assert_eq(story.variables[0].var_name, "force")
	assert_eq(story.variables[0].initial_value, "0")
	assert_eq(story.variables[1].var_name, "sagesse")
	assert_eq(story.variables[2].var_name, "cristaux")
