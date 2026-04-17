extends GutTest

## Tests pour les onglets du panneau droit de l'éditeur de séquence (spec 016)

var MainScript
var StoryScript
var ChapterScript
var SceneDataScript
var SequenceScript
var DialogueScript
var EndingScript
var ConsequenceScript

var _main = null

func before_each():
	MainScript = load("res://src/main.gd")
	StoryScript = load("res://src/models/story.gd")
	ChapterScript = load("res://src/models/chapter.gd")
	SceneDataScript = load("res://src/models/scene_data.gd")
	SequenceScript = load("res://src/models/sequence.gd")
	DialogueScript = load("res://src/models/dialogue.gd")
	EndingScript = load("res://src/models/ending.gd")
	ConsequenceScript = load("res://src/models/consequence.gd")

	_main = Control.new()
	_main.set_script(MainScript)
	add_child(_main)
	await get_tree().process_frame

func after_each():
	if _main:
		_main.queue_free()
		_main = null

func _navigate_to_sequence(seq = null):
	var story = StoryScript.new()
	story.title = "Test"
	story.author = "A"
	var ch = ChapterScript.new()
	ch.chapter_name = "Ch1"
	var sc = SceneDataScript.new()
	sc.scene_name = "S1"
	if seq == null:
		seq = SequenceScript.new()
		seq.seq_name = "Seq1"
		var dlg = DialogueScript.new()
		dlg.character = "Héros"
		dlg.text = "Bonjour"
		seq.dialogues.append(dlg)
	sc.sequences.append(seq)
	ch.scenes.append(sc)
	story.chapters.append(ch)
	_main._editor_main.open_story(story)
	_main._editor_main.navigate_to_chapter(ch.uuid)
	_main._editor_main.navigate_to_scene(sc.uuid)
	_main._editor_main.navigate_to_sequence(seq.uuid)
	_main.load_sequence_editors(seq)
	_main.update_view()
	return seq

# --- Structure TabContainer ---

func test_tab_container_exists():
	assert_not_null(_main._tab_container, "TabContainer should exist")
	assert_true(_main._tab_container is TabContainer, "Should be a TabContainer")

func test_tab_container_has_expected_tabs():
	# 6 onglets core (Texte, Calques, Terminaison, Musique, FX, Paramètres)
	# + 1 onglet plugin voice_studio (Voix)
	assert_eq(_main._tab_container.get_tab_count(), 7, "Should have 7 tabs (6 core + 1 plugin)")

func test_tab_names():
	assert_eq(_main._tab_container.get_tab_title(0), "Texte")
	assert_eq(_main._tab_container.get_tab_title(1), "Calques")
	assert_eq(_main._tab_container.get_tab_title(2), "Terminaison")
	assert_eq(_main._tab_container.get_tab_title(3), "Musique")
	assert_eq(_main._tab_container.get_tab_title(4), "FX")
	assert_eq(_main._tab_container.get_tab_title(5), "Paramètres")

# --- Contenu de l'onglet Terminaison ---

func test_ending_editor_in_terminaison_tab():
	assert_not_null(_main._ending_editor, "Ending editor should exist")
	# Terminaison est désormais l'onglet index 2 (après Texte et Calques)
	var terminaison_tab = _main._tab_container.get_child(2)
	assert_true(terminaison_tab.is_ancestor_of(_main._ending_editor),
		"Ending editor should be inside terminaison tab")

# --- Placeholders Musique et FX ---

func test_fx_tab_has_fx_panel():
	# FX est désormais l'onglet index 4
	var fx_tab = _main._tab_container.get_child(4)
	assert_not_null(fx_tab, "FX tab should exist")
	assert_eq(fx_tab, _main._fx_panel, "FX tab should be the FxPanel")

# --- Sélection par défaut ---

func test_texte_tab_selected_by_default():
	assert_eq(_main._tab_container.current_tab, 0, "Texte tab should be selected by default")

# --- Indicateur de terminaison ---

func test_terminaison_tab_no_indicator_when_no_ending():
	var seq = _navigate_to_sequence()
	seq.ending = null
	_main._update_ending_tab_indicator()
	assert_eq(_main._tab_container.get_tab_title(2), "Terminaison")

func test_terminaison_tab_indicator_when_ending_configured():
	var seq = _navigate_to_sequence()
	var ending = EndingScript.new()
	ending.type = "auto_redirect"
	var cons = ConsequenceScript.new()
	cons.type = "game_over"
	ending.auto_consequence = cons
	seq.ending = ending
	_main._update_ending_tab_indicator()
	assert_eq(_main._tab_container.get_tab_title(2), "Terminaison ●")

func test_indicator_updates_on_ending_changed():
	var seq = _navigate_to_sequence()
	# Initially no ending
	assert_eq(_main._tab_container.get_tab_title(2), "Terminaison")
	# Add ending
	var ending = EndingScript.new()
	ending.type = "choices"
	seq.ending = ending
	# Simulate ending_changed signal
	_main._ending_editor._notify_change()

	# Attendre que l'EventBus propage le signal à main.gd
	await wait_frames(1)

	assert_eq(_main._tab_container.get_tab_title(2), "Terminaison ●")

# --- Fonctionnalités existantes ---

func test_add_dialogue_still_works():
	_navigate_to_sequence()
	var seq = _main._sequence_editor_ctrl.get_sequence()
	var initial_count = seq.dialogues.size()
	_main._seq_ui_ctrl.on_add_dialogue_pressed()
	assert_eq(seq.dialogues.size(), initial_count + 1)
