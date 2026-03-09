extends GutTest

## Tests pour le panel de liste des dialogues avec drag & drop

var DialogueListPanel = load("res://src/ui/sequence/dialogue_list_panel.gd")
var SequenceEditor = load("res://src/ui/sequence/sequence_editor.gd")
var Sequence = load("res://src/models/sequence.gd")
var Dialogue = load("res://src/models/dialogue.gd")
var Foreground = load("res://src/models/foreground.gd")

var _panel: Control = null
var _seq_editor: Control = null
var _sequence = null

func before_each():
	_seq_editor = Control.new()
	_seq_editor.set_script(SequenceEditor)
	add_child_autofree(_seq_editor)

	_sequence = Sequence.new()
	_sequence.seq_name = "Test"

	_panel = VBoxContainer.new()
	_panel.set_script(DialogueListPanel)
	add_child_autofree(_panel)

func _add_dialogues(count: int) -> void:
	for i in range(count):
		var dlg = Dialogue.new()
		dlg.character = "P%d" % i
		dlg.text = "Texte %d" % i
		_sequence.dialogues.append(dlg)
	_seq_editor.load_sequence(_sequence)
	_panel.setup(_seq_editor)

# --- Tests basiques ---

func test_setup_builds_list():
	_add_dialogues(3)
	assert_eq(_panel.get_item_count(), 3)

func test_item_shows_character_and_text():
	_add_dialogues(1)
	var item = _panel.get_item(0)
	assert_not_null(item)
	assert_true(item.has_method("get_character_text"))
	assert_eq(item.get_character_text(), "P0")

func test_rebuild_updates_list():
	_add_dialogues(2)
	_seq_editor.add_dialogue("New", "Hello")
	_panel.rebuild()
	assert_eq(_panel.get_item_count(), 3)

# --- Drag & drop ---

func test_get_drag_data_returns_index():
	_add_dialogues(3)
	var item = _panel.get_item(1)
	var drag_data = item._get_drag_data(Vector2.ZERO)
	assert_not_null(drag_data)
	assert_eq(drag_data["type"], "dialogue_reorder")
	assert_eq(drag_data["index"], 1)

func test_can_drop_data_accepts_dialogue_reorder():
	_add_dialogues(3)
	var item = _panel.get_item(0)
	var drag_data = {"type": "dialogue_reorder", "index": 2}
	assert_true(item._can_drop_data(Vector2.ZERO, drag_data))

func test_can_drop_data_rejects_other():
	_add_dialogues(2)
	var item = _panel.get_item(0)
	assert_false(item._can_drop_data(Vector2.ZERO, {"type": "other"}))
	assert_false(item._can_drop_data(Vector2.ZERO, null))

func test_drop_data_reorders():
	_add_dialogues(3)
	# Simulate drop: drag item 2 onto item 0
	var item_0 = _panel.get_item(0)
	var drag_data = {"type": "dialogue_reorder", "index": 2}
	item_0._drop_data(Vector2.ZERO, drag_data)
	# Vérifier que le modèle a changé
	assert_eq(_sequence.dialogues[0].character, "P2")
	assert_eq(_sequence.dialogues[1].character, "P0")
	assert_eq(_sequence.dialogues[2].character, "P1")

func test_drop_data_rebuilds_list():
	_add_dialogues(3)
	var item_0 = _panel.get_item(0)
	var drag_data = {"type": "dialogue_reorder", "index": 2}
	item_0._drop_data(Vector2.ZERO, drag_data)
	# Vérifier que la liste est reconstruite (les items reflètent le nouvel ordre)
	assert_eq(_panel.get_item(0).get_character_text(), "P2")

# --- Sélection ---

func test_click_selects_dialogue():
	_add_dialogues(2)
	_panel.select_item(1)
	assert_eq(_seq_editor.get_selected_dialogue_index(), 1)

func test_highlight_item():
	_add_dialogues(3)
	_panel.highlight_item(1)
	var item = _panel.get_item(1)
	assert_true(item.is_highlighted())

func test_highlight_clears_others():
	_add_dialogues(3)
	_panel.highlight_item(0)
	_panel.highlight_item(2)
	assert_false(_panel.get_item(0).is_highlighted())
	assert_true(_panel.get_item(2).is_highlighted())

# --- Suppression ---

func test_delete_signal():
	_add_dialogues(2)
	watch_signals(_panel)
	_panel.request_delete(0)
	assert_signal_emitted(_panel, "dialogue_delete_requested")

# --- Édition inline ---

func test_edit_character():
	_add_dialogues(1)
	_panel.get_item(0).set_character_text("Nouveau")
	assert_eq(_sequence.dialogues[0].character, "Nouveau")

func test_edit_text():
	_add_dialogues(1)
	_panel.get_item(0).set_dialogue_text("Nouveau texte")
	assert_eq(_sequence.dialogues[0].text, "Nouveau texte")
