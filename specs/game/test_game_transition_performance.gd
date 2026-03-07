extends GutTest

## Test d'intégration pour diagnostiquer les lenteurs lors des transitions
## de séquence/scène en mode jeu (game.gd).
##
## Reproduit le flux exact qui se produit quand le joueur appuie sur Espace
## au dernier dialogue d'une séquence, déclenchant une transition vers
## une nouvelle scène.

const GameScript = preload("res://src/game.gd")
const GameSaveManager = preload("res://src/persistence/game_save_manager.gd")
const StoryScript = preload("res://src/models/story.gd")
const ChapterScript = preload("res://src/models/chapter.gd")
const SceneDataScript = preload("res://src/models/scene_data.gd")
const SequenceScript = preload("res://src/models/sequence.gd")
const DialogueScript = preload("res://src/models/dialogue.gd")
const EndingScript = preload("res://src/models/ending.gd")
const ConsequenceScript = preload("res://src/models/consequence.gd")

var _game: Control


func before_each() -> void:
	_game = Control.new()
	_game.set_script(GameScript)
	add_child(_game)


func after_each() -> void:
	if _game.get_tree():
		_game.get_tree().paused = false
	remove_child(_game)
	_game.queue_free()


# --- Helpers ---

## Crée une story avec 1 chapitre, 2 scènes, chaque scène a 1 séquence avec 2 dialogues.
## La séquence de la scène 1 redirige automatiquement vers la scène 2.
func _create_multi_scene_story() -> RefCounted:
	var story = StoryScript.new()
	story.title = "Perf Test Story"

	var chapter = ChapterScript.new()
	chapter.chapter_name = "Chapter 1"

	# Scène 1
	var scene1 = SceneDataScript.new()
	scene1.scene_name = "Scene 1"
	var seq1 = SequenceScript.new()
	seq1.seq_name = "Seq 1"
	for i in range(3):
		var dlg = DialogueScript.new()
		dlg.character = "Alice"
		dlg.text = "Dialogue %d de la scène 1" % (i + 1)
		seq1.dialogues.append(dlg)

	# Scène 2
	var scene2 = SceneDataScript.new()
	scene2.scene_name = "Scene 2"
	var seq2 = SequenceScript.new()
	seq2.seq_name = "Seq 2"
	for i in range(3):
		var dlg = DialogueScript.new()
		dlg.character = "Bob"
		dlg.text = "Dialogue %d de la scène 2" % (i + 1)
		seq2.dialogues.append(dlg)

	# Ending de seq1 → redirect vers scene2
	var ending = EndingScript.new()
	ending.type = "auto_redirect"
	var consequence = ConsequenceScript.new()
	consequence.type = "redirect_scene"
	consequence.target = scene2.uuid
	ending.auto_consequence = consequence
	seq1.ending = ending

	scene1.sequences.append(seq1)
	scene1.entry_point_uuid = seq1.uuid
	scene2.sequences.append(seq2)
	scene2.entry_point_uuid = seq2.uuid

	chapter.scenes.append(scene1)
	chapter.scenes.append(scene2)
	chapter.entry_point_uuid = scene1.uuid
	story.chapters.append(chapter)
	story.entry_point_uuid = chapter.uuid

	return story


## Crée une story avec 1 chapitre, 1 scène, 2 séquences en chaîne.
func _create_multi_sequence_story() -> RefCounted:
	var story = StoryScript.new()
	story.title = "Multi Seq Story"

	var chapter = ChapterScript.new()
	chapter.chapter_name = "Chapter 1"

	var scene = SceneDataScript.new()
	scene.scene_name = "Scene 1"

	var seq1 = SequenceScript.new()
	seq1.seq_name = "Seq 1"
	var seq2 = SequenceScript.new()
	seq2.seq_name = "Seq 2"

	for i in range(2):
		var dlg = DialogueScript.new()
		dlg.character = "Alice"
		dlg.text = "Seq1 Dialogue %d" % (i + 1)
		seq1.dialogues.append(dlg)

	for i in range(2):
		var dlg = DialogueScript.new()
		dlg.character = "Bob"
		dlg.text = "Seq2 Dialogue %d" % (i + 1)
		seq2.dialogues.append(dlg)

	# seq1 → redirect vers seq2 (même scène)
	var ending = EndingScript.new()
	ending.type = "auto_redirect"
	var consequence = ConsequenceScript.new()
	consequence.type = "redirect_sequence"
	consequence.target = seq2.uuid
	ending.auto_consequence = consequence
	seq1.ending = ending

	scene.sequences.append(seq1)
	scene.sequences.append(seq2)
	scene.entry_point_uuid = seq1.uuid

	chapter.scenes.append(scene)
	chapter.entry_point_uuid = scene.uuid
	story.chapters.append(chapter)
	story.entry_point_uuid = chapter.uuid

	return story


# --- Tests de diagnostic de performance ---


## Vérifie que _update_skip_availability utilise le cache et ne fait PAS d'I/O disque.
func test_update_skip_availability_uses_cache() -> void:
	var story = _create_multi_scene_story()
	_game._current_story = story
	_game._cached_max_progression = {"chapter": 0, "scene": 1}

	var start := Time.get_ticks_usec()
	for i in range(100):
		_game._update_skip_availability()
	var elapsed := Time.get_ticks_usec() - start

	# 100 appels doivent prendre < 10ms (pas d'I/O disque)
	assert_true(elapsed < 10_000, "100 appels à _update_skip_availability devraient prendre < 10ms, a pris %d µs" % elapsed)


## Vérifie que _load_max_progression (I/O disque) n'est appelé qu'une seule fois au chargement.
func test_load_max_progression_called_once_at_load() -> void:
	var story = _create_multi_scene_story()
	_game._current_story = story

	# Simuler le chargement initial
	_game._load_max_progression()
	var initial_prog = _game._cached_max_progression.duplicate()

	# Les transitions de scène ne doivent PAS rappeler _load_max_progression
	# Elles utilisent _update_skip_availability qui lit le cache
	_game._on_scene_entered_update_skip("Scene 2", "uuid-test")

	# Le cache ne doit pas avoir changé (pas de rechargement disque)
	assert_eq(_game._cached_max_progression, initial_prog,
		"le cache ne doit pas changer lors d'une transition de scène")


## Vérifie que _update_cached_progression met à jour le cache sans I/O.
func test_update_cached_progression_incremental() -> void:
	var story = _create_multi_scene_story()
	_game._current_story = story
	_game._cached_max_progression = {"chapter": -1, "scene": -1}

	var ch_uuid = story.chapters[0].uuid
	var sc_uuid = story.chapters[0].scenes[1].uuid

	var start := Time.get_ticks_usec()
	_game._update_cached_progression({
		"chapter_uuid": ch_uuid,
		"scene_uuid": sc_uuid,
	})
	var elapsed := Time.get_ticks_usec() - start

	assert_eq(_game._cached_max_progression["chapter"], 0)
	assert_eq(_game._cached_max_progression["scene"], 1)
	assert_true(elapsed < 1000, "mise à jour incrémentale du cache doit prendre < 1ms, a pris %d µs" % elapsed)


## Vérifie que _on_autosave_triggered est non-bloquant (utilise un thread worker).
## La partie synchrone (capture screenshot + mise en cache) doit être < 5ms.
func test_autosave_triggered_is_non_blocking() -> void:
	var story = _create_multi_scene_story()
	_game._current_story = story
	_game._current_story_path = "res://story"

	# Préparer le story_play_ctrl avec un chapitre/scène courant
	_game._story_play_ctrl._story = story
	_game._story_play_ctrl._current_chapter = story.chapters[0]
	_game._story_play_ctrl._current_scene = story.chapters[0].scenes[0]
	_game._story_play_ctrl._current_sequence = story.chapters[0].scenes[0].sequences[0]
	_game._story_play_ctrl._state = 1  # PLAYING_SEQUENCE

	var start := Time.get_ticks_usec()
	_game._on_autosave_triggered()
	var elapsed := Time.get_ticks_usec() - start

	var elapsed_ms := elapsed / 1000.0
	gut.p(">>> _on_autosave_triggered (partie synchrone): %.2f ms" % elapsed_ms)

	# La partie synchrone ne doit PAS inclure l'encodage PNG ni l'écriture disque
	# Elle ne fait que capturer le screenshot et lancer le thread worker
	assert_true(elapsed < 5000, "la partie synchrone de l'autosave doit être < 5ms, a pris %d µs" % elapsed)


## Profiling complet d'une transition de scène : mesure chaque étape séparément.
func test_scene_transition_profiling() -> void:
	var story = _create_multi_scene_story()
	_game._current_story = story
	_game._current_story_path = "res://story"
	_game._cached_max_progression = {"chapter": 0, "scene": 0}

	# Préparer l'état comme si on jouait la scène 1
	_game._story_play_ctrl._story = story
	_game._story_play_ctrl._current_chapter = story.chapters[0]
	_game._story_play_ctrl._current_scene = story.chapters[0].scenes[0]
	_game._story_play_ctrl._current_sequence = story.chapters[0].scenes[0].sequences[0]
	_game._story_play_ctrl._state = 1  # PLAYING_SEQUENCE

	# --- Étape 1 : scene_entered signal handler (skip availability) ---
	var t1 := Time.get_ticks_usec()
	_game._on_scene_entered_update_skip("Scene 2", story.chapters[0].scenes[1].uuid)
	var dt1 := Time.get_ticks_usec() - t1

	# --- Étape 2 : autosave (screenshot capture + PNG encode + disk write) ---
	var t2 := Time.get_ticks_usec()
	_game._on_autosave_triggered()
	var dt2 := Time.get_ticks_usec() - t2

	# --- Étape 3 : sequence_play_requested (load sequence + visuals) ---
	var seq2 = story.chapters[0].scenes[1].sequences[0]
	var t3 := Time.get_ticks_usec()
	_game._play_ctrl.on_sequence_play_requested(seq2)
	var dt3 := Time.get_ticks_usec() - t3

	gut.p("═══════════════════════════════════════════════")
	gut.p("  PROFILING TRANSITION DE SCÈNE (game mode)")
	gut.p("═══════════════════════════════════════════════")
	gut.p("  1. Skip availability (cache)  : %8.2f ms" % (dt1 / 1000.0))
	gut.p("  2. Autosave (partie sync)      : %8.2f ms" % (dt2 / 1000.0))
	gut.p("  3. Load sequence + visuals     : %8.2f ms" % (dt3 / 1000.0))
	gut.p("  ─────────────────────────────────────────────")
	gut.p("  TOTAL (sync seulement)         : %8.2f ms" % ((dt1 + dt2 + dt3) / 1000.0))
	gut.p("═══════════════════════════════════════════════")

	# Le handler skip availability doit être rapide (< 1ms)
	assert_true(dt1 < 1000, "skip availability doit être < 1ms, a pris %d µs" % dt1)

	# L'autosave (partie synchrone) doit être rapide car le PNG est écrit en arrière-plan
	assert_true(dt2 < 5000, "autosave (sync) doit être < 5ms, a pris %d µs" % dt2)

	pass_test("profiling terminé — voir les temps ci-dessus")


## Simule le flux complet : avancer dans les dialogues puis transition de scène.
## Vérifie qu'aucune opération d'I/O disque synchrone lourde ne se produit
## dans le chemin critique (entre l'appui espace et l'affichage de la nouvelle scène).
func test_full_play_flow_scene_transition() -> void:
	var story = _create_multi_scene_story()
	_game._current_story = story
	_game._current_story_path = "res://story"
	_game._cached_max_progression = {"chapter": 0, "scene": 0}

	# Démarrer la lecture
	_game._play_ctrl.start_story(story)

	# Vérifier que la séquence 1 est en cours de lecture
	assert_true(_game._sequence_editor_ctrl.is_playing(), "devrait être en lecture")

	# Avancer les dialogues de la séquence 1 (3 dialogues)
	var seq1 = story.chapters[0].scenes[0].sequences[0]
	assert_eq(seq1.dialogues.size(), 3, "seq1 devrait avoir 3 dialogues")

	# Simuler l'avance rapide des dialogues (comme l'appui espace)
	var total_start := Time.get_ticks_usec()
	for i in range(seq1.dialogues.size()):
		# Skip le typewriter
		_game._sequence_editor_ctrl.skip_typewriter()
		# Avancer au prochain dialogue (ou terminer la séquence)
		if i < seq1.dialogues.size() - 1:
			_game._sequence_editor_ctrl.advance_play()
	# Dernier advance_play déclenche stop_play → transition de scène
	_game._sequence_editor_ctrl.advance_play()
	var total_elapsed := Time.get_ticks_usec() - total_start

	gut.p(">>> Flux complet (3 dialogues + transition): %.2f ms" % (total_elapsed / 1000.0))

	# Le flux complet ne devrait pas dépasser 100ms
	# (la majorité du temps devrait être dans le rendu, pas dans l'I/O)
	assert_true(total_elapsed < 100_000,
		"le flux complet ne devrait pas dépasser 100ms, a pris %d µs" % total_elapsed)


## Vérifie que les transitions séquence→séquence (même scène) ne déclenchent PAS d'autosave.
func test_same_scene_sequence_transition_no_autosave() -> void:
	var story = _create_multi_sequence_story()
	_game._current_story = story
	_game._current_story_path = "res://story"

	var autosave_count := 0
	_game._story_play_ctrl.autosave_triggered.connect(func(): autosave_count += 1)

	# Démarrer la lecture (scene_entry déclenche 1 autosave)
	_game._play_ctrl.start_story(story)
	var initial_autosave_count := autosave_count

	# Avancer tous les dialogues de seq1 pour déclencher la transition vers seq2
	for i in range(2):
		_game._sequence_editor_ctrl.skip_typewriter()
		_game._sequence_editor_ctrl.advance_play()

	# Vérifier qu'aucun autosave supplémentaire n'a été déclenché
	# (redirect_sequence ne passe pas par _start_scene_entry)
	assert_eq(autosave_count, initial_autosave_count,
		"transition séquence→séquence (même scène) ne devrait pas déclencher d'autosave supplémentaire")


## Vérifie que _trigger_autosave émet le signal quand activé.
func test_trigger_autosave_emits_signal() -> void:
	var autosave_count := 0
	_game._story_play_ctrl.autosave_triggered.connect(func(): autosave_count += 1)
	_game._story_play_ctrl._autosave_enabled = true

	_game._story_play_ctrl._trigger_autosave()

	assert_eq(autosave_count, 1,
		"_trigger_autosave devrait émettre autosave_triggered (count: %d)" % autosave_count)


## Vérifie que _trigger_autosave n'émet PAS le signal quand désactivé.
func test_trigger_autosave_does_not_emit_when_disabled() -> void:
	var autosave_count := 0
	_game._story_play_ctrl.autosave_triggered.connect(func(): autosave_count += 1)
	_game._story_play_ctrl._autosave_enabled = false

	_game._story_play_ctrl._trigger_autosave()

	assert_eq(autosave_count, 0,
		"_trigger_autosave ne devrait pas émettre si désactivé (count: %d)" % autosave_count)


## Vérifie que _open_chapter_scene_menu utilise le cache et ne scanne pas les sauvegardes.
func test_open_chapter_scene_menu_uses_cache() -> void:
	var story = _create_multi_scene_story()
	_game._current_story = story
	_game._cached_max_progression = {"chapter": 0, "scene": 1}

	var start := Time.get_ticks_usec()
	for i in range(50):
		_game._open_chapter_scene_menu()
		_game._chapter_scene_menu.hide_menu()
	var elapsed := Time.get_ticks_usec() - start

	# 50 ouvertures doivent être rapides (pas de scan disque)
	assert_true(elapsed < 50_000, "50 ouvertures du menu chapitre/scène devraient être < 50ms, a pris %d µs" % elapsed)
