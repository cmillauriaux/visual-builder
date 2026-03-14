extends GutTest

## Tests pour DialogueTimeline — timeline horizontale des dialogues.

var DialogueTimelineScript = load("res://src/ui/sequence/dialogue_timeline.gd")
var Dialogue = load("res://src/models/dialogue.gd")
var Foreground = load("res://src/models/foreground.gd")
var Sequence = load("res://src/models/sequence.gd")

var _timeline: PanelContainer
var _mock_editor: _MockSequenceEditor


func before_each() -> void:
	_mock_editor = _MockSequenceEditor.new()
	_timeline = PanelContainer.new()
	_timeline.set_script(DialogueTimelineScript)
	add_child_autofree(_timeline)


func after_each() -> void:
	# _MockSequenceEditor extends RefCounted, no need to free manually
	_mock_editor = null


# --- Setup ---

func test_setup_stores_seq_editor() -> void:
	_mock_editor.sequence = _create_sequence_with_dialogues(2)
	_timeline.setup(_mock_editor)
	assert_eq(_timeline._seq_editor, _mock_editor)


func test_setup_triggers_rebuild() -> void:
	_mock_editor.sequence = _create_sequence_with_dialogues(3)
	_timeline.setup(_mock_editor)
	assert_eq(_timeline.get_item_count(), 3)


# --- Rebuild ---

func test_rebuild_creates_correct_number_of_items() -> void:
	_mock_editor.sequence = _create_sequence_with_dialogues(4)
	_timeline.setup(_mock_editor)
	assert_eq(_timeline.get_item_count(), 4)


func test_rebuild_with_zero_dialogues() -> void:
	_mock_editor.sequence = _create_sequence_with_dialogues(0)
	_timeline.setup(_mock_editor)
	assert_eq(_timeline.get_item_count(), 0)


func test_rebuild_with_null_sequence() -> void:
	_mock_editor.sequence = null
	_timeline.setup(_mock_editor)
	assert_eq(_timeline.get_item_count(), 0)


func test_rebuild_replaces_previous_items() -> void:
	_mock_editor.sequence = _create_sequence_with_dialogues(3)
	_timeline.setup(_mock_editor)
	assert_eq(_timeline.get_item_count(), 3)
	_mock_editor.sequence = _create_sequence_with_dialogues(5)
	_timeline.rebuild()
	assert_eq(_timeline.get_item_count(), 5)


# --- Select item ---

func test_select_item_highlights_correct_item() -> void:
	_mock_editor.sequence = _create_sequence_with_dialogues(3)
	_timeline.setup(_mock_editor)
	_timeline.select_item(1)
	assert_eq(_timeline._selected_index, 1)
	assert_true(_timeline._items[1]._selected)
	assert_false(_timeline._items[0]._selected)
	assert_false(_timeline._items[2]._selected)


func test_select_item_deselects_previous() -> void:
	_mock_editor.sequence = _create_sequence_with_dialogues(3)
	_timeline.setup(_mock_editor)
	_timeline.select_item(0)
	assert_true(_timeline._items[0]._selected)
	_timeline.select_item(2)
	assert_false(_timeline._items[0]._selected)
	assert_true(_timeline._items[2]._selected)


func test_highlight_item_delegates_to_select_item() -> void:
	_mock_editor.sequence = _create_sequence_with_dialogues(2)
	_timeline.setup(_mock_editor)
	_timeline.highlight_item(1)
	assert_eq(_timeline._selected_index, 1)
	assert_true(_timeline._items[1]._selected)


# --- Add button ---

func test_add_button_exists() -> void:
	assert_not_null(_timeline._add_btn)


func test_add_button_is_in_tree_after_setup() -> void:
	_mock_editor.sequence = _create_sequence_with_dialogues(2)
	_timeline.setup(_mock_editor)
	assert_true(_timeline._add_btn.is_inside_tree())


func test_add_button_is_last_child_in_hbox() -> void:
	_mock_editor.sequence = _create_sequence_with_dialogues(2)
	_timeline.setup(_mock_editor)
	var last_child = _timeline._hbox.get_child(_timeline._hbox.get_child_count() - 1)
	assert_eq(last_child, _timeline._add_btn)


# --- get_item_count ---

func test_get_item_count_returns_correct_count() -> void:
	_mock_editor.sequence = _create_sequence_with_dialogues(5)
	_timeline.setup(_mock_editor)
	assert_eq(_timeline.get_item_count(), 5)


func test_get_item_count_returns_zero_initially() -> void:
	assert_eq(_timeline.get_item_count(), 0)


# --- Signals ---

func test_dialogue_clicked_signal_emitted_on_item_click() -> void:
	_mock_editor.sequence = _create_sequence_with_dialogues(3)
	_timeline.setup(_mock_editor)
	watch_signals(_timeline)
	_timeline._on_item_clicked(1)
	assert_signal_emitted_with_parameters(_timeline, "dialogue_clicked", [1])


func test_add_dialogue_requested_signal_exists() -> void:
	watch_signals(_timeline)
	_timeline.add_dialogue_requested.emit()
	assert_signal_emitted(_timeline, "add_dialogue_requested")


# --- Rebuild preserves selection ---

func test_rebuild_preserves_selection() -> void:
	_mock_editor.sequence = _create_sequence_with_dialogues(3)
	_timeline.setup(_mock_editor)
	_timeline.select_item(1)
	_timeline.rebuild()
	assert_true(_timeline._items[1]._selected)


# --- Helpers ---

func _create_sequence_with_dialogues(count: int):
	var seq = Sequence.new()
	for i in range(count):
		var dlg = Dialogue.new()
		dlg.character = "Char %d" % i
		dlg.text = "Text %d" % i
		if i == 0:
			var fg = Foreground.new()
			fg.fg_name = "FG %d" % i
			dlg.foregrounds.append(fg)
		seq.dialogues.append(dlg)
	return seq


# --- Mock classes ---

class _MockSequenceEditor extends RefCounted:
	var sequence = null

	func get_sequence():
		return sequence

	func get_effective_foregrounds(index: int) -> Array:
		if sequence == null:
			return []
		if index < 0 or index >= sequence.dialogues.size():
			return []
		var dlg = sequence.dialogues[index]
		if dlg.foregrounds.size() > 0:
			return dlg.foregrounds
		for i in range(index - 1, -1, -1):
			if sequence.dialogues[i].foregrounds.size() > 0:
				return sequence.dialogues[i].foregrounds
		return []
