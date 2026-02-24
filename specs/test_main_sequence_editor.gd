extends GutTest

## Tests d'intégration pour le layout de l'éditeur de séquence dans main.gd

const MainScript = preload("res://src/main.gd")
const Story = preload("res://src/models/story.gd")
const Chapter = preload("res://src/models/chapter.gd")
const SceneData = preload("res://src/models/scene_data.gd")
const Sequence = preload("res://src/models/sequence.gd")
const Dialogue = preload("res://src/models/dialogue.gd")
const Foreground = preload("res://src/models/foreground.gd")

var _main = null

func before_each():
	_main = Control.new()
	_main.set_script(MainScript)
	add_child_autofree(_main)
	# Force la création manuelle plutôt que _on_new_story_pressed pour contrôler les données
	await get_tree().process_frame

func _navigate_to_sequence_edit() -> void:
	var story = Story.new()
	story.title = "Test"
	story.author = "A"
	var ch = Chapter.new()
	ch.chapter_name = "Ch1"
	var sc = SceneData.new()
	sc.scene_name = "S1"
	var seq = Sequence.new()
	seq.seq_name = "Seq1"
	seq.background = "bg.png"
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
	_main._load_sequence_editors(seq)
	_main._update_view()

# --- Tests Layout ---

func test_sequence_editor_panel_exists():
	assert_not_null(_main._sequence_editor_panel)

func test_sequence_editor_panel_is_vbox():
	# Le panel de séquence doit être un VBoxContainer (toolbar + content)
	assert_true(_main._sequence_editor_panel is VBoxContainer)

func test_sequence_toolbar_exists():
	_navigate_to_sequence_edit()
	assert_not_null(_main._sequence_toolbar)

func test_import_bg_button_exists():
	_navigate_to_sequence_edit()
	assert_not_null(_main._import_bg_button)
	assert_true(_main._import_bg_button is Button)

func test_play_button_exists():
	_navigate_to_sequence_edit()
	assert_not_null(_main._play_button)
	assert_true(_main._play_button is Button)

func test_stop_button_exists():
	_navigate_to_sequence_edit()
	assert_not_null(_main._stop_button)
	assert_true(_main._stop_button is Button)

func test_visual_editor_exists():
	assert_not_null(_main._visual_editor)

func test_dialogue_panel_exists():
	assert_not_null(_main._dialogue_panel)

func test_sequence_editor_controller_exists():
	assert_not_null(_main._sequence_editor_ctrl)

# --- Test visibility ---

func test_sequence_panel_visible_at_sequence_edit():
	_navigate_to_sequence_edit()
	assert_true(_main._sequence_editor_panel.visible)

func test_sequence_panel_hidden_at_chapters():
	var story = Story.new()
	story.title = "Test"
	_main._editor_main.open_story(story)
	_main._update_view()
	assert_false(_main._sequence_editor_panel.visible)

# --- Test SequenceEditor integration ---

func test_sequence_editor_loaded_with_sequence():
	_navigate_to_sequence_edit()
	assert_not_null(_main._sequence_editor_ctrl.get_sequence())
	assert_eq(_main._sequence_editor_ctrl.get_sequence().seq_name, "Seq1")

# --- Test dialogue list panel ---

func test_dialogue_list_shows_items():
	_navigate_to_sequence_edit()
	# Le dialogue_panel doit contenir la liste
	assert_not_null(_main._dialogue_list_container)

# --- Test Play/Stop button states ---

func test_stop_button_hidden_initially():
	_navigate_to_sequence_edit()
	assert_false(_main._stop_button.visible)

func test_play_button_visible_initially():
	_navigate_to_sequence_edit()
	assert_true(_main._play_button.visible)

func test_add_foreground_button_exists():
	_navigate_to_sequence_edit()
	assert_not_null(_main._add_fg_button)
	assert_true(_main._add_fg_button is Button)
