extends GutTest

var SequenceUIControllerScript

class MockMain extends Control:
	var _visual_editor = Control.new()
	var _sequence_editor_ctrl = Control.new()
	var _undo_redo = RefCounted.new()
	var _editor_main = Node.new()
	var _plugin_manager = null

	func _init():
		_visual_editor.set_script(load("res://src/ui/sequence/sequence_visual_editor.gd"))
		_sequence_editor_ctrl.set_script(load("res://src/ui/sequence/sequence_editor.gd"))
		_undo_redo.set_script(load("res://src/services/undo_redo_service.gd"))
		add_child(_visual_editor)
		add_child(_sequence_editor_ctrl)
		add_child(_editor_main)
	
	func _get_story_base_path():
		return "res://story/"
	
	func _rebuild_dialogue_list():
		pass
	
	func _on_dialogue_selected(idx):
		pass

	func update_preview_for_dialogue(_idx: int):
		pass

var _ctrl
var _main

func before_each():
	SequenceUIControllerScript = load("res://src/controllers/sequence_ui_controller.gd")
	_main = MockMain.new()
	add_child_autofree(_main)
	_ctrl = Node.new()
	_ctrl.set_script(SequenceUIControllerScript)
	add_child_autofree(_ctrl)
	_ctrl.setup(_main)

func test_grid_toggled():
	_ctrl.on_grid_toggled(true)
	assert_true(_main._visual_editor.is_grid_visible())
	_ctrl.on_grid_toggled(false)
	assert_false(_main._visual_editor.is_grid_visible())

func test_snap_toggled():
	_ctrl.on_snap_toggled(true)
	assert_true(_main._visual_editor.is_snap_enabled())
	_ctrl.on_snap_toggled(false)
	assert_false(_main._visual_editor.is_snap_enabled())

func test_on_bg_file_selected():
	_ctrl._on_bg_file_selected("assets/bg.png")
	# set_background délègue aux objets réels — pas de crash = succès
	assert_true(true)


# --- on_add_dialogue_pressed ---

func test_on_add_dialogue_pressed_null_sequence() -> void:
	# sequence_editor has no sequence loaded → early return
	_ctrl.on_add_dialogue_pressed()
	pass_test("on_add_dialogue_pressed with null sequence should not crash")


# --- on_delete_dialogue ---

func test_on_delete_dialogue_null_sequence() -> void:
	_ctrl.on_delete_dialogue(0)
	pass_test("on_delete_dialogue with null sequence should not crash")


# --- on_foreground_deselected ---

func test_on_foreground_deselected_clears_state() -> void:
	_ctrl._fg_initial_snapshot = {"anchor_bg": Vector2(0.5, 0.5)}
	_ctrl._fg_snapshot_uuid = "test-uuid"
	_ctrl.on_foreground_deselected()
	assert_true(_ctrl._fg_initial_snapshot.is_empty())
	assert_eq(_ctrl._fg_snapshot_uuid, "")


# --- on_foreground_selected ---

func test_on_foreground_selected_sets_uuid() -> void:
	_ctrl.on_foreground_selected("my-fg-uuid")
	assert_eq(_ctrl._fg_snapshot_uuid, "my-fg-uuid")

func test_on_foreground_selected_null_fg_clears_snapshot() -> void:
	# find_foreground("nonexistent") → null → snapshot = {}
	_ctrl.on_foreground_selected("nonexistent-uuid")
	assert_true(_ctrl._fg_initial_snapshot.is_empty())


# --- on_foreground_modified ---

func test_on_foreground_modified_empty_uuid() -> void:
	_ctrl._fg_snapshot_uuid = ""
	_ctrl.on_foreground_modified()
	pass_test("on_foreground_modified with empty uuid should not crash")

func test_on_foreground_modified_empty_snapshot() -> void:
	_ctrl._fg_snapshot_uuid = "test-uuid"
	_ctrl._fg_initial_snapshot = {}
	_ctrl.on_foreground_modified("test-uuid")
	pass_test("on_foreground_modified with empty snapshot should not crash")

func test_on_foreground_modified_nonexistent_fg() -> void:
	# fg = null → returns early after snapshot check
	_ctrl._fg_snapshot_uuid = "test-uuid"
	_ctrl._fg_initial_snapshot = {"anchor_bg": Vector2(0.1, 0.1)}
	_ctrl.on_foreground_modified("test-uuid")
	pass_test("on_foreground_modified with nonexistent fg should not crash")


# --- on_normalize_foregrounds_pressed ---

func test_on_normalize_foregrounds_pressed() -> void:
	_ctrl.on_normalize_foregrounds_pressed()
	pass_test("on_normalize_foregrounds_pressed should not crash")


# --- _capture_fg_snapshot ---

func test_capture_fg_snapshot() -> void:
	var FgScript = load("res://src/models/foreground.gd")
	var fg = FgScript.new()
	fg.anchor_bg = Vector2(0.3, 0.4)
	fg.z_order = 2
	fg.opacity = 0.8
	var snapshot = _ctrl._capture_fg_snapshot(fg)
	assert_eq(snapshot["anchor_bg"], Vector2(0.3, 0.4))
	assert_eq(snapshot["z_order"], 2)
	assert_eq(snapshot["opacity"], 0.8)


# --- _compute_fg_changes ---

func test_compute_fg_changes_no_changes() -> void:
	var FgScript = load("res://src/models/foreground.gd")
	var fg = FgScript.new()
	var snapshot = _ctrl._capture_fg_snapshot(fg)
	var changes = _ctrl._compute_fg_changes(fg, snapshot)
	assert_true(changes.is_empty())

func test_compute_fg_changes_with_changes() -> void:
	var FgScript = load("res://src/models/foreground.gd")
	var fg = FgScript.new()
	var snapshot = _ctrl._capture_fg_snapshot(fg)
	fg.anchor_bg = Vector2(0.9, 0.9)
	var changes = _ctrl._compute_fg_changes(fg, snapshot)
	assert_false(changes.is_empty())
	assert_true(changes.has("anchor_bg"))


# --- _on_fg_file_selected ---

func test_on_fg_file_selected_negative_idx() -> void:
	# get_selected_dialogue_index() returns -1 → early return
	_ctrl._on_fg_file_selected("assets/fg.png")
	pass_test("_on_fg_file_selected with negative idx should not crash")


# --- _on_replace_fg_selected ---

func test_on_replace_fg_selected_null_fg() -> void:
	# find_foreground returns null → no action
	_ctrl._on_replace_fg_selected("assets/new.png", "nonexistent-uuid")
	pass_test("_on_replace_fg_selected with null fg should not crash")


# --- _on_replace_with_new_fg_selected ---

func test_on_replace_with_new_fg_selected_null_fg() -> void:
	# find_foreground returns null → early return (template_fg null)
	_ctrl._on_replace_with_new_fg_selected("assets/new.png", "nonexistent-uuid")
	pass_test("_on_replace_with_new_fg_selected with null fg should not crash")


# --- on_add_dialogue_pressed with loaded sequence ---

func test_on_add_dialogue_pressed_with_sequence() -> void:
	var SequenceScript = load("res://src/models/sequence.gd")
	var seq = SequenceScript.new()
	_main._sequence_editor_ctrl.load_sequence(seq)
	var initial_size = seq.dialogues.size()
	_ctrl.on_add_dialogue_pressed()
	assert_eq(seq.dialogues.size(), initial_size + 1)


func test_on_add_dialogue_pressed_with_selection() -> void:
	var SequenceScript = load("res://src/models/sequence.gd")
	var DialogueScript = load("res://src/models/dialogue.gd")
	var seq = SequenceScript.new()
	var dlg = DialogueScript.new()
	seq.dialogues.append(dlg)
	_main._sequence_editor_ctrl.load_sequence(seq)
	_main._sequence_editor_ctrl.select_dialogue(0)
	_ctrl.on_add_dialogue_pressed()
	assert_eq(seq.dialogues.size(), 2)


# --- on_add_foreground_pressed ---

func test_on_add_foreground_pressed_no_sequence() -> void:
	# No sequence loaded, no dialogue selected → early return
	_ctrl.on_add_foreground_pressed()
	pass_test("on_add_foreground_pressed with no sequence should not crash")


func test_on_add_foreground_pressed_empty_sequence() -> void:
	var SequenceScript = load("res://src/models/sequence.gd")
	var seq = SequenceScript.new()
	_main._sequence_editor_ctrl.load_sequence(seq)
	# No dialogues, none selected → early return
	_ctrl.on_add_foreground_pressed()
	pass_test("on_add_foreground_pressed with empty sequence should not crash")


# --- _get_current_source_image ---

func test_get_current_source_image_background_with_sequence() -> void:
	var SequenceScript = load("res://src/models/sequence.gd")
	var seq = SequenceScript.new()
	seq.background = "assets/bg.png"
	_main._sequence_editor_ctrl.load_sequence(seq)
	var ImagePickerDialogScript = load("res://src/ui/dialogs/image_picker_dialog.gd")
	var result = _ctrl._get_current_source_image(ImagePickerDialogScript.Mode.BACKGROUND)
	assert_eq(result, "assets/bg.png")


func test_get_current_source_image_background_empty() -> void:
	var ImagePickerDialogScript = load("res://src/ui/dialogs/image_picker_dialog.gd")
	var result = _ctrl._get_current_source_image(ImagePickerDialogScript.Mode.BACKGROUND)
	assert_eq(result, "")


# --- on_duplicate_dialogue ---

func test_duplicate_dialogue() -> void:
	var SequenceScript = load("res://src/models/sequence.gd")
	var DialogueScript = load("res://src/models/dialogue.gd")
	var seq = SequenceScript.new()
	var dlg0 = DialogueScript.new()
	dlg0.character = "Alice"
	dlg0.text = "Hello"
	var dlg1 = DialogueScript.new()
	dlg1.character = "Bob"
	dlg1.text = "World"
	seq.dialogues.append(dlg0)
	seq.dialogues.append(dlg1)
	_main._sequence_editor_ctrl.load_sequence(seq)
	_ctrl.on_duplicate_dialogue(0)
	assert_eq(seq.dialogues.size(), 3)
	assert_eq(seq.dialogues[1].character, "Alice")
	assert_eq(seq.dialogues[1].text, "Hello")
	# The duplicate should be a different object with a new identity
	assert_ne(seq.dialogues[1], dlg0)


func test_duplicate_dialogue_invalid_index() -> void:
	var SequenceScript = load("res://src/models/sequence.gd")
	var seq = SequenceScript.new()
	_main._sequence_editor_ctrl.load_sequence(seq)
	_ctrl.on_duplicate_dialogue(-1)
	_ctrl.on_duplicate_dialogue(999)
	assert_eq(seq.dialogues.size(), 0)
	pass_test("on_duplicate_dialogue with invalid index should not crash")


# --- on_insert_dialogue_before ---

func test_insert_dialogue_before() -> void:
	var SequenceScript = load("res://src/models/sequence.gd")
	var DialogueScript = load("res://src/models/dialogue.gd")
	var seq = SequenceScript.new()
	var dlg0 = DialogueScript.new()
	dlg0.character = "Alice"
	dlg0.text = "First"
	var dlg1 = DialogueScript.new()
	dlg1.character = "Bob"
	dlg1.text = "Second"
	seq.dialogues.append(dlg0)
	seq.dialogues.append(dlg1)
	_main._sequence_editor_ctrl.load_sequence(seq)
	_ctrl.on_insert_dialogue_before(1)
	assert_eq(seq.dialogues.size(), 3)
	# The inserted dialogue should be at index 1 (before "Bob")
	assert_eq(seq.dialogues[1].character, "")
	assert_eq(seq.dialogues[1].text, "")
	# Original dialogues shifted
	assert_eq(seq.dialogues[0].character, "Alice")
	assert_eq(seq.dialogues[2].character, "Bob")


func test_insert_dialogue_before_invalid_index() -> void:
	# No sequence loaded → early return, no crash
	_ctrl.on_insert_dialogue_before(0)
	pass_test("on_insert_dialogue_before with null sequence should not crash")


# --- on_insert_dialogue_after ---

func test_insert_dialogue_after() -> void:
	var SequenceScript = load("res://src/models/sequence.gd")
	var DialogueScript = load("res://src/models/dialogue.gd")
	var seq = SequenceScript.new()
	var dlg0 = DialogueScript.new()
	dlg0.character = "Alice"
	dlg0.text = "First"
	var dlg1 = DialogueScript.new()
	dlg1.character = "Bob"
	dlg1.text = "Second"
	seq.dialogues.append(dlg0)
	seq.dialogues.append(dlg1)
	_main._sequence_editor_ctrl.load_sequence(seq)
	_ctrl.on_insert_dialogue_after(0)
	assert_eq(seq.dialogues.size(), 3)
	# The inserted dialogue should be at index 1 (after "Alice")
	assert_eq(seq.dialogues[1].character, "")
	assert_eq(seq.dialogues[1].text, "")
	# Original dialogues preserved in order
	assert_eq(seq.dialogues[0].character, "Alice")
	assert_eq(seq.dialogues[2].character, "Bob")


func test_insert_dialogue_after_invalid_index() -> void:
	# No sequence loaded → early return, no crash
	_ctrl.on_insert_dialogue_after(0)
	pass_test("on_insert_dialogue_after with null sequence should not crash")
