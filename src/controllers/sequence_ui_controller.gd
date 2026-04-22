# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends Node

## Gère les actions UI de l'éditeur de séquence : import background,
## ajout foreground, toggle grille/snap, et CRUD des dialogues.

const ImagePickerDialogScript = preload("res://src/ui/dialogs/image_picker_dialog.gd")
const AddDialogueCommand = preload("res://src/commands/add_dialogue_command.gd")
const RemoveDialogueCommand = preload("res://src/commands/remove_dialogue_command.gd")

const ReplaceForegroundImageCommand = preload("res://src/commands/replace_foreground_image_command.gd")
const ReplaceWithNewForegroundCommand = preload("res://src/commands/replace_with_new_foreground_command.gd")

var _main: Control
var _fg_initial_snapshot: Dictionary = {}
var _fg_snapshot_uuid: String = ""

const TRACKED_FG_PROPERTIES := [
	"anchor_bg", "scale", "z_order",
	"censored",
	"flip_h", "flip_v", "opacity",
	"transition_type", "transition_duration",
	"anim_speed", "anim_reverse", "anim_loop", "anim_reverse_loop",
]


func setup(main: Control) -> void:
	_main = main


func on_grid_toggled(toggled_on: bool) -> void:
	_main._visual_editor.set_grid_visible(toggled_on)


func on_snap_toggled(toggled_on: bool) -> void:
	_main._visual_editor.set_snap_enabled(toggled_on)


func on_import_bg_pressed() -> void:
	_open_image_picker(ImagePickerDialogScript.Mode.BACKGROUND, _on_bg_file_selected)


func _on_bg_file_selected(path: String) -> void:
	_main._sequence_editor_ctrl.set_background(path)
	_main._visual_editor.set_background(path)
	_main._rebuild_dialogue_list()
	EventBus.story_modified.emit()


func on_normalize_foregrounds_pressed() -> void:
	var cleared = _main._sequence_editor_ctrl.normalize_dialogue_foregrounds()
	if cleared > 0:
		var idx = _main._sequence_editor_ctrl.get_selected_dialogue_index()
		if idx >= 0:
			_main.update_preview_for_dialogue(idx)
		EventBus.story_modified.emit()


func on_add_foreground_pressed() -> void:
	if _main._sequence_editor_ctrl.get_selected_dialogue_index() < 0:
		var seq = _main._sequence_editor_ctrl.get_sequence()
		if seq and seq.dialogues.size() > 0:
			_main._sequence_editor_ctrl.select_dialogue(0)
		else:
			return
	_open_image_picker(ImagePickerDialogScript.Mode.FOREGROUND, _on_fg_file_selected)


func _on_fg_file_selected(path: String) -> void:
	var idx = _main._sequence_editor_ctrl.get_selected_dialogue_index()
	if idx < 0:
		return
	_main._sequence_editor_ctrl.add_foreground_to_current(path.get_file().get_basename(), path)
	_main.update_preview_for_dialogue(idx)
	_main._rebuild_dialogue_list()
	EventBus.story_modified.emit()


func on_foreground_replace_requested(uuid: String) -> void:
	_open_image_picker(ImagePickerDialogScript.Mode.FOREGROUND, _on_replace_fg_selected.bind(uuid))


func _on_replace_fg_selected(path: String, uuid: String) -> void:
	# S'assurer que le dialogue courant a ses propres foregrounds (pas hérités)
	# avant de modifier l'image, sinon on modifie l'objet partagé de la séquence/dialogue parent.
	var idx = _main._sequence_editor_ctrl.get_selected_dialogue_index()
	if idx >= 0:
		_main._sequence_editor_ctrl.ensure_own_foregrounds(idx)
		_main.update_preview_for_dialogue(idx)
	var fg = _main._visual_editor.find_foreground(uuid)
	if fg:
		var cmd = ReplaceForegroundImageCommand.new(fg, path)
		_main._undo_redo.push_and_execute(cmd)
		_main._visual_editor._update_foreground_visuals()
		_main._rebuild_dialogue_list()
		EventBus.story_modified.emit()


func on_foreground_replace_with_new_requested(uuid: String) -> void:
	_open_image_picker(ImagePickerDialogScript.Mode.FOREGROUND, _on_replace_with_new_fg_selected.bind(uuid))


func _on_replace_with_new_fg_selected(path: String, uuid: String) -> void:
	var template_fg = _main._visual_editor.find_foreground(uuid)
	var idx = _main._sequence_editor_ctrl.get_selected_dialogue_index()
	var seq = _main._sequence_editor_ctrl.get_sequence()
	if template_fg and idx >= 0 and seq:
		var dialogue = seq.dialogues[idx]
		var inherited = _main._sequence_editor_ctrl.get_effective_foregrounds(idx)
		var cmd = ReplaceWithNewForegroundCommand.new(dialogue, template_fg, path, inherited)
		_main._undo_redo.push_and_execute(cmd)
		_main.update_preview_for_dialogue(idx)
		_main._rebuild_dialogue_list()
		EventBus.story_modified.emit()


func _open_image_picker(mode: int, on_selected: Callable) -> void:
	var picker = Window.new()
	picker.set_script(ImagePickerDialogScript)
	_main.add_child(picker)
	var story_base_path = _main._get_story_base_path()
	var story = _main._editor_main._story if _main._editor_main else null
	picker.setup(mode, story_base_path, story)
	picker.image_selected.connect(on_selected)

	# Inject plugin tabs (e.g. IA tab from ai_studio plugin)
	if _main.get("_plugin_manager") != null:
		for tab_def in _main._plugin_manager.get_image_picker_tabs():
			picker.add_plugin_tab(tab_def)

	# Pre-fill source image in plugin tabs
	var source = _get_current_source_image(mode)
	if source != "":
		picker.set_source_image(source)
	picker.popup_centered()


func _get_current_source_image(mode: int) -> String:
	if mode == ImagePickerDialogScript.Mode.FOREGROUND:
		if _main._visual_editor._selected_fg_uuid != "":
			var idx = _main._sequence_editor_ctrl.get_selected_dialogue_index()
			if idx >= 0:
				var fgs = _main._sequence_editor_ctrl.get_effective_foregrounds(idx)
				for fg in fgs:
					if fg.uuid == _main._visual_editor._selected_fg_uuid:
						return fg.image
	elif mode == ImagePickerDialogScript.Mode.BACKGROUND:
		var seq = _main._sequence_editor_ctrl.get_sequence()
		if seq and seq.background != "":
			return seq.background
	return ""


func on_add_dialogue_pressed() -> void:
	var seq = _main._sequence_editor_ctrl.get_sequence()
	if seq == null:
		return
	
	var index = _main._sequence_editor_ctrl.get_selected_dialogue_index()
	if index >= 0:
		index += 1
	else:
		index = seq.dialogues.size()
	
	var cmd = AddDialogueCommand.new(seq, "Nouveau", "Texte", index)
	_main._undo_redo.push_and_execute(cmd)
	_main._rebuild_dialogue_list()
	_main._on_dialogue_selected(index)


func on_duplicate_dialogue(index: int) -> void:
	var new_idx = _main._sequence_editor_ctrl.duplicate_dialogue(index)
	if new_idx >= 0:
		_main._rebuild_dialogue_list()
		_main._on_dialogue_selected(new_idx)
		EventBus.story_modified.emit()


func on_insert_dialogue_before(index: int) -> void:
	var seq = _main._sequence_editor_ctrl.get_sequence()
	if seq == null:
		return
	var cmd = AddDialogueCommand.new(seq, "", "", index)
	_main._undo_redo.push_and_execute(cmd)
	_main._rebuild_dialogue_list()
	_main._on_dialogue_selected(index)
	EventBus.story_modified.emit()


func on_insert_dialogue_after(index: int) -> void:
	var seq = _main._sequence_editor_ctrl.get_sequence()
	if seq == null:
		return
	var insert_idx = index + 1
	var cmd = AddDialogueCommand.new(seq, "", "", insert_idx)
	_main._undo_redo.push_and_execute(cmd)
	_main._rebuild_dialogue_list()
	_main._on_dialogue_selected(insert_idx)
	EventBus.story_modified.emit()


func on_delete_dialogue(index: int) -> void:
	var seq = _main._sequence_editor_ctrl.get_sequence()
	if seq == null:
		return
		
	var confirm = ConfirmationDialog.new()
	confirm.dialog_text = "Supprimer ce dialogue ?"
	confirm.confirmed.connect(func():
		var cmd = RemoveDialogueCommand.new(seq, index)
		_main._undo_redo.push_and_execute(cmd)
		
		# Ajuster la sélection dans le contrôleur si nécessaire
		var current_sel = _main._sequence_editor_ctrl.get_selected_dialogue_index()
		if current_sel == index:
			_main._sequence_editor_ctrl.select_dialogue(-1)
		elif current_sel > index:
			_main._sequence_editor_ctrl.select_dialogue(current_sel - 1)
			
		_main._rebuild_dialogue_list()
		confirm.queue_free()
	)
	confirm.canceled.connect(func(): confirm.queue_free())
	_main.add_child(confirm)
	confirm.popup_centered()


# --- Propagation foregrounds ---

func _capture_fg_snapshot(fg) -> Dictionary:
	var snapshot := {}
	for prop in TRACKED_FG_PROPERTIES:
		snapshot[prop] = fg.get(prop)
	return snapshot


func _compute_fg_changes(fg, snapshot: Dictionary) -> Dictionary:
	var changes := {}
	for key in snapshot.keys():
		if fg.get(key) != snapshot[key]:
			changes[key] = fg.get(key)
	return changes


func on_foreground_selected(uuid: String) -> void:
	_fg_snapshot_uuid = uuid
	var fg = _main._visual_editor.find_foreground(uuid)
	if fg:
		_fg_initial_snapshot = _capture_fg_snapshot(fg)
	else:
		_fg_initial_snapshot = {}


func on_foreground_deselected() -> void:
	_fg_initial_snapshot = {}
	_fg_snapshot_uuid = ""


func on_foreground_modified(uuid: String = "") -> void:
	var target_uuid = uuid if uuid != "" else _fg_snapshot_uuid
	if target_uuid == "" or _fg_initial_snapshot.is_empty():
		return

	var fg = _main._visual_editor.find_foreground(target_uuid)
	if fg == null:
		return

	var changes = _compute_fg_changes(fg, _fg_initial_snapshot)
	if changes.is_empty():
		_fg_initial_snapshot = _capture_fg_snapshot(fg)
		return

	var idx = _main._sequence_editor_ctrl.get_selected_dialogue_index()
	if idx < 0:
		_fg_initial_snapshot = _capture_fg_snapshot(fg)
		return

	var initial_anchor_bg: Vector2 = _fg_initial_snapshot.get("anchor_bg", fg.anchor_bg)
	var matches = _main._sequence_editor_ctrl.find_similar_foregrounds(initial_anchor_bg, idx)

	if matches.is_empty():
		_fg_initial_snapshot = _capture_fg_snapshot(fg)
		return

	# Count distinct dialogues
	var dialogue_indices := {}
	for m in matches:
		dialogue_indices[m["dialogue_index"]] = true

	var confirm = ConfirmationDialog.new()
	confirm.dialog_text = "%d foreground(s) dans %d dialogue(s) suivant(s) ont une position similaire.\nAppliquer la modification à tous ?" % [matches.size(), dialogue_indices.size()]
	confirm.ok_button_text = "Oui"
	confirm.cancel_button_text = "Non"

	var captured_changes = changes.duplicate()
	var captured_matches = matches.duplicate()
	var captured_initial = initial_anchor_bg

	confirm.confirmed.connect(func():
		_main._sequence_editor_ctrl.propagate_fg_changes(captured_matches, captured_changes, captured_initial)
		EventBus.story_modified.emit()
		confirm.queue_free()
	)
	confirm.canceled.connect(func():
		confirm.queue_free()
	)

	_fg_initial_snapshot = _capture_fg_snapshot(fg)

	_main.add_child(confirm)
	confirm.popup_centered()
