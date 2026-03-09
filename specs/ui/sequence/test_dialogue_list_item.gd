extends GutTest

## Tests pour DialogueListItem — item de dialogue avec édition et drag & drop.

var DialogueListItemScript = load("res://src/ui/sequence/dialogue_list_item.gd")
var DialogueScript = load("res://src/models/dialogue.gd")

var _item: PanelContainer
var _dialogue
var _mock_seq_editor
var _mock_list_panel


func before_each() -> void:
	_dialogue = DialogueScript.new()
	_dialogue.character = "Alice"
	_dialogue.text = "Hello world"

	_mock_seq_editor = _MockSeqEditor.new()
	_mock_list_panel = _MockListPanel.new()

	_item = PanelContainer.new()
	_item.set_script(DialogueListItemScript)
	_item.setup(0, _dialogue, _mock_seq_editor, _mock_list_panel)
	add_child(_item)


func after_each() -> void:
	remove_child(_item)
	_item.queue_free()
	_mock_seq_editor.free()
	_mock_list_panel.free()


func test_setup_stores_index_and_dialogue() -> void:
	assert_eq(_item._index, 0)
	assert_eq(_item._dialogue, _dialogue)


func test_get_character_text() -> void:
	assert_eq(_item.get_character_text(), "Alice")


func test_get_dialogue_text() -> void:
	assert_eq(_item.get_dialogue_text(), "Hello world")


func test_get_character_text_without_dialogue() -> void:
	var item2 = PanelContainer.new()
	item2.set_script(DialogueListItemScript)
	assert_eq(item2.get_character_text(), "")
	item2.free()


func test_get_dialogue_text_without_dialogue() -> void:
	var item2 = PanelContainer.new()
	item2.set_script(DialogueListItemScript)
	assert_eq(item2.get_dialogue_text(), "")
	item2.free()


func test_highlight_default_off() -> void:
	assert_false(_item.is_highlighted())


func test_set_highlighted_on() -> void:
	_item.set_highlighted(true)
	assert_true(_item.is_highlighted())
	assert_eq(_item.modulate, Color(0.8, 0.9, 1.0))


func test_set_highlighted_off() -> void:
	_item.set_highlighted(true)
	_item.set_highlighted(false)
	assert_false(_item.is_highlighted())
	assert_eq(_item.modulate, Color.WHITE)


func test_set_character_text_updates_dialogue() -> void:
	_item.set_character_text("Bob")
	assert_eq(_dialogue.character, "Bob")
	assert_eq(_item._char_edit.text, "Bob")


func test_set_dialogue_text_updates_dialogue() -> void:
	_item.set_dialogue_text("Goodbye")
	assert_eq(_dialogue.text, "Goodbye")
	assert_eq(_item._text_edit.text, "Goodbye")


func test_character_change_calls_seq_editor() -> void:
	_item._on_character_changed("Charlie")
	assert_eq(_mock_seq_editor.last_modify_args, [0, "Charlie", "Hello world"])


func test_text_change_calls_seq_editor() -> void:
	_item._on_text_changed("New text")
	assert_eq(_mock_seq_editor.last_modify_args, [0, "Alice", "New text"])


func test_can_drop_valid_data() -> void:
	var data = {"type": "dialogue_reorder", "index": 1}
	assert_true(_item._can_drop_data(Vector2.ZERO, data))


func test_cannot_drop_invalid_data() -> void:
	assert_false(_item._can_drop_data(Vector2.ZERO, {"type": "other"}))
	assert_false(_item._can_drop_data(Vector2.ZERO, "not a dict"))
	assert_false(_item._can_drop_data(Vector2.ZERO, null))


func test_drop_data_calls_list_panel() -> void:
	var data = {"type": "dialogue_reorder", "index": 2}
	_item._drop_data(Vector2.ZERO, data)
	assert_eq(_mock_list_panel.last_reorder_args, [2, 0])


func test_minimum_size() -> void:
	assert_eq(_item.custom_minimum_size.y, 60.0)


func test_build_ui_creates_line_edits() -> void:
	assert_not_null(_item._char_edit)
	assert_not_null(_item._text_edit)
	assert_eq(_item._char_edit.text, "Alice")
	assert_eq(_item._text_edit.text, "Hello world")


# --- Mock classes ---

class _MockSeqEditor extends RefCounted:
	var last_modify_args: Array = []
	func modify_dialogue(idx: int, char_text: String, dlg_text: String) -> void:
		last_modify_args = [idx, char_text, dlg_text]


class _MockListPanel extends RefCounted:
	var last_select_args: Array = []
	var last_reorder_args: Array = []
	var last_delete_args: Array = []
	func select_item(index: int) -> void:
		last_select_args = [index]
	func request_delete(index: int) -> void:
		last_delete_args = [index]
	func on_drop_reorder(from_index: int, to_index: int) -> void:
		last_reorder_args = [from_index, to_index]
