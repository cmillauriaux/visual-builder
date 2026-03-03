extends GutTest

## Tests pour les onglets du panneau droit de l'éditeur de séquence (spec 016)

const MainScript = preload("res://src/main.gd")
const Story = preload("res://src/models/story.gd")
const Chapter = preload("res://src/models/chapter.gd")
const SceneData = preload("res://src/models/scene_data.gd")
const Sequence = preload("res://src/models/sequence.gd")
const Dialogue = preload("res://src/models/dialogue.gd")
const Ending = preload("res://src/models/ending.gd")
const Consequence = preload("res://src/models/consequence.gd")

var _main = null

func before_each():
	_main = Control.new()
	_main.set_script(MainScript)
	add_child(_main)
	await get_tree().process_frame

func after_each():
	if _main:
		_main.queue_free()
		_main = null

func _navigate_to_sequence(seq: Sequence = null) -> Sequence:
	var story = Story.new()
	story.title = "Test"
	story.author = "A"
	var ch = Chapter.new()
	ch.chapter_name = "Ch1"
	var sc = SceneData.new()
	sc.scene_name = "S1"
	if seq == null:
		seq = Sequence.new()
		seq.seq_name = "Seq1"
		var dlg = Dialogue.new()
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

func test_tab_container_has_5_tabs():
	assert_eq(_main._tab_container.get_tab_count(), 5, "Should have 5 tabs")

func test_tab_names():
	assert_eq(_main._tab_container.get_tab_title(0), "Dialogues")
	assert_eq(_main._tab_container.get_tab_title(1), "Terminaison")
	assert_eq(_main._tab_container.get_tab_title(2), "Musique")
	assert_eq(_main._tab_container.get_tab_title(3), "FX")
	assert_eq(_main._tab_container.get_tab_title(4), "Transitions")

# --- Contenu de l'onglet Dialogues ---

func test_dialogues_tab_contains_scroll():
	var dialogues_tab = _main._tab_container.get_child(0)
	var has_scroll = false
	for child in dialogues_tab.get_children():
		if child is ScrollContainer:
			has_scroll = true
			break
	assert_true(has_scroll, "Dialogues tab should contain a ScrollContainer")

func test_dialogues_tab_contains_add_button():
	var dialogues_tab = _main._tab_container.get_child(0)
	var has_btn = false
	for child in dialogues_tab.get_children():
		if child is Button and child.text == "+ Ajouter un dialogue":
			has_btn = true
			break
	assert_true(has_btn, "Dialogues tab should contain add dialogue button")

func test_dialogue_list_container_in_dialogues_tab():
	assert_not_null(_main._dialogue_list_container, "Dialogue list container should exist")
	# Verify it's a descendant of the dialogues tab
	var dialogues_tab = _main._tab_container.get_child(0)
	assert_true(_main._dialogue_list_container.is_ancestor_of(_main._dialogue_list_container) or dialogues_tab.is_ancestor_of(_main._dialogue_list_container),
		"Dialogue list should be inside dialogues tab")

# --- Contenu de l'onglet Terminaison ---

func test_ending_editor_in_terminaison_tab():
	assert_not_null(_main._ending_editor, "Ending editor should exist")
	var terminaison_tab = _main._tab_container.get_child(1)
	assert_true(terminaison_tab.is_ancestor_of(_main._ending_editor),
		"Ending editor should be inside terminaison tab")

# --- Placeholders Musique et FX ---

func test_musique_tab_placeholder():
	var musique_tab = _main._tab_container.get_child(2)
	var label = _find_label_in(musique_tab, "À venir")
	assert_not_null(label, "Musique tab should have 'À venir' label")

func test_fx_tab_has_fx_panel():
	var fx_tab = _main._tab_container.get_child(3)
	assert_not_null(fx_tab, "FX tab should exist")
	assert_eq(fx_tab, _main._fx_panel, "FX tab should be the FxPanel")

func test_musique_placeholder_centered():
	var musique_tab = _main._tab_container.get_child(2)
	var label = _find_label_in(musique_tab, "À venir")
	assert_not_null(label)
	if label:
		assert_eq(label.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER)

func test_fx_panel_has_add_button():
	assert_not_null(_main._fx_panel._add_button, "FX panel should have an add button")

# --- Sélection par défaut ---

func test_dialogues_tab_selected_by_default():
	assert_eq(_main._tab_container.current_tab, 0, "Dialogues tab should be selected by default")

func test_dialogues_tab_reset_on_sequence_load():
	# Switch to another tab first
	_main._tab_container.current_tab = 1
	assert_eq(_main._tab_container.current_tab, 1)
	# Load a sequence
	_navigate_to_sequence()
	assert_eq(_main._tab_container.current_tab, 0, "Should reset to Dialogues tab on sequence load")

# --- Indicateur de terminaison ---

func test_terminaison_tab_no_indicator_when_no_ending():
	var seq = _navigate_to_sequence()
	seq.ending = null
	_main._update_ending_tab_indicator()
	assert_eq(_main._tab_container.get_tab_title(1), "Terminaison")

func test_terminaison_tab_indicator_when_ending_configured():
	var seq = _navigate_to_sequence()
	var ending = Ending.new()
	ending.type = "auto_redirect"
	var cons = Consequence.new()
	cons.type = "game_over"
	ending.auto_consequence = cons
	seq.ending = ending
	_main._update_ending_tab_indicator()
	assert_eq(_main._tab_container.get_tab_title(1), "Terminaison ●")

func test_indicator_updates_on_ending_changed():
	var seq = _navigate_to_sequence()
	# Initially no ending
	assert_eq(_main._tab_container.get_tab_title(1), "Terminaison")
	# Add ending
	var ending = Ending.new()
	ending.type = "choices"
	seq.ending = ending
	# Simulate ending_changed signal (emits EventBus.story_modified via _notify_change)
	_main._ending_editor._notify_change()
	
	# Attendre que l'EventBus propage le signal à main.gd
	await wait_frames(1)
	
	assert_eq(_main._tab_container.get_tab_title(1), "Terminaison ●")

func test_indicator_removed_when_ending_cleared():
	var seq = _navigate_to_sequence()
	# Set ending first
	var ending = Ending.new()
	ending.type = "auto_redirect"
	var cons = Consequence.new()
	cons.type = "game_over"
	ending.auto_consequence = cons
	seq.ending = ending
	_main._update_ending_tab_indicator()
	assert_eq(_main._tab_container.get_tab_title(1), "Terminaison ●")
	# Clear ending
	seq.ending = null
	_main._update_ending_tab_indicator()
	assert_eq(_main._tab_container.get_tab_title(1), "Terminaison")

# --- Fonctionnalités existantes ---

func test_add_dialogue_still_works():
	_navigate_to_sequence()
	var seq = _main._sequence_editor_ctrl.get_sequence()
	var initial_count = seq.dialogues.size()
	_main._on_add_dialogue_pressed()
	assert_eq(seq.dialogues.size(), initial_count + 1)

func test_dialogue_list_rebuilt_after_add():
	_navigate_to_sequence()
	var initial_items = _main._dialogue_list_container.get_item_count()
	_main._on_add_dialogue_pressed()
	assert_eq(_main._dialogue_list_container.get_item_count(), initial_items + 1)

func test_ending_editor_still_loads():
	var seq = _navigate_to_sequence()
	var ending = Ending.new()
	ending.type = "auto_redirect"
	var cons = Consequence.new()
	cons.type = "game_over"
	ending.auto_consequence = cons
	seq.ending = ending
	_main._ending_editor.load_sequence(seq)
	assert_eq(_main._ending_editor.get_ending_type(), "auto_redirect")

# --- Helper ---

func _find_label_in(node: Node, text: String) -> Label:
	if node is Label and node.text == text:
		return node
	for child in node.get_children():
		var found = _find_label_in(child, text)
		if found:
			return found
	return null
