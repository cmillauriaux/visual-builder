extends Node

## Gère la navigation (back, breadcrumb, double-click), la création d'éléments,
## le renommage, la sauvegarde/chargement, et la gestion des endings/conditions/variables.

const StoryScript = preload("res://src/models/story.gd")
const ChapterScript = preload("res://src/models/chapter.gd")
const SceneDataScript = preload("res://src/models/scene_data.gd")
const SequenceScript = preload("res://src/models/sequence.gd")
const StorySaver = preload("res://src/persistence/story_saver.gd")
const RenameDialogScript = preload("res://src/ui/dialogs/rename_dialog.gd")
const MenuConfigDialogScript = preload("res://src/ui/dialogs/menu_config_dialog.gd")
const StoryVerifierScript = preload("res://src/services/story_verifier.gd")
const AddChapterCommand = preload("res://src/commands/add_chapter_command.gd")
const AddSceneCommand = preload("res://src/commands/add_scene_command.gd")
const AddSequenceCommand = preload("res://src/commands/add_sequence_command.gd")
const AddConditionCommand = preload("res://src/commands/add_condition_command.gd")
const RenameNodeCommand = preload("res://src/commands/rename_node_command.gd")

var _main: Control
var _rename_dialog: ConfirmationDialog
var _menu_config_dialog: ConfirmationDialog
var _last_save_path: String = ""


func get_save_path() -> String:
	return _last_save_path


func setup(main: Control) -> void:
	_main = main


# --- Create ---

func on_create_pressed() -> void:
	var level = _main._editor_main.get_current_level()
	var item_name = _main._editor_main.get_next_item_name()
	if level == "chapters":
		var pos = _main._editor_main.compute_next_position(_main._editor_main._story.chapters)
		var cmd = AddChapterCommand.new(_main._editor_main._story, item_name, pos)
		_main._undo_redo.push(cmd)
		_main._chapter_graph_view.load_story(_main._editor_main._story)
		_main._refresh_undo_redo_buttons()
	elif level == "scenes":
		var pos = _main._editor_main.compute_next_position(_main._editor_main._current_chapter.scenes)
		var cmd = AddSceneCommand.new(_main._editor_main._current_chapter, item_name, pos)
		_main._undo_redo.push(cmd)
		_main._scene_graph_view.load_chapter(_main._editor_main._current_chapter)
		_main._refresh_undo_redo_buttons()
	elif level == "sequences":
		var pos = _main._editor_main.compute_next_position(_main._editor_main._current_scene.sequences)
		var cmd = AddSequenceCommand.new(_main._editor_main._current_scene, item_name, pos)
		_main._undo_redo.push(cmd)
		_main._sequence_graph_view.load_scene(_main._editor_main._current_scene)
		_main._refresh_undo_redo_buttons()


func on_create_condition_pressed() -> void:
	if _main._editor_main.get_current_level() != "sequences":
		return
	var cond_name = _main._editor_main.get_next_condition_name()
	var all_items: Array = []
	all_items.append_array(_main._editor_main._current_scene.sequences)
	all_items.append_array(_main._editor_main._current_scene.conditions)
	var pos = _main._editor_main.compute_next_position(all_items)
	var cmd = AddConditionCommand.new(_main._editor_main._current_scene, cond_name, pos)
	_main._undo_redo.push(cmd)
	_main._sequence_graph_view.load_scene(_main._editor_main._current_scene)
	_main._refresh_undo_redo_buttons()


# --- Navigation ---

func on_back_pressed() -> void:
	if _main._play_ctrl.is_story_play_mode():
		_main._play_ctrl._stop_story_play()
		return
	if _main._sequence_editor_ctrl.is_playing():
		_main._sequence_editor_ctrl.stop_play()
	_main._editor_main.navigate_back()
	_main.refresh_current_view()


func on_breadcrumb_clicked(index: int) -> void:
	var level = _main._editor_main.get_current_level()
	if index == 0 and level != "chapters":
		while _main._editor_main.get_current_level() != "chapters":
			_main._editor_main.navigate_back()
	elif index == 1 and (level == "sequences" or level == "sequence_edit" or level == "condition_edit"):
		while _main._editor_main.get_current_level() != "scenes":
			_main._editor_main.navigate_back()
	elif index == 2 and (level == "sequence_edit" or level == "condition_edit"):
		_main._editor_main.navigate_back()
	_main.refresh_current_view()


# --- Double-click navigation ---

func on_chapter_double_clicked(chapter_uuid: String) -> void:
	_main._chapter_graph_view.sync_positions_to_model()
	_main._editor_main.navigate_to_chapter(chapter_uuid)
	_main.refresh_current_view()


func on_scene_double_clicked(scene_uuid: String) -> void:
	_main._scene_graph_view.sync_positions_to_model()
	_main._editor_main.navigate_to_scene(scene_uuid)
	_main.refresh_current_view()


func on_sequence_double_clicked(sequence_uuid: String) -> void:
	_main._sequence_graph_view.sync_positions_to_model()
	_main._editor_main.navigate_to_sequence(sequence_uuid)
	if _main._editor_main._current_sequence:
		_main.load_sequence_editors(_main._editor_main._current_sequence)
	_main.refresh_current_view()


func on_condition_double_clicked(condition_uuid: String) -> void:
	_main._sequence_graph_view.sync_positions_to_model()
	_main._editor_main.navigate_to_condition(condition_uuid)
	if _main._editor_main._current_condition:
		load_condition_editor(_main._editor_main._current_condition)
	_main.refresh_current_view()


# --- Rename ---

func on_story_rename_requested() -> void:
	if _main._editor_main._story == null:
		return
	_open_rename_dialog("story", _main._editor_main._story.title, _main._editor_main._story.description, func(_u, new_name, new_subtitle):
		_main._editor_main._story.title = new_name
		_main._editor_main._story.description = new_subtitle
		_main._breadcrumb.set_path(_main._editor_main.get_breadcrumb_path())
	)


func on_chapter_rename_requested(uuid: String) -> void:
	var chapter = _main._editor_main._story.find_chapter(uuid)
	if chapter == null:
		return
	_open_rename_dialog(uuid, chapter.chapter_name, chapter.subtitle, func(u, n, s):
		var cmd = RenameNodeCommand.new(
			func(nm, sub): chapter.chapter_name = nm; chapter.subtitle = sub; _main._chapter_graph_view.rename_chapter(u, nm, sub),
			func(): return [chapter.chapter_name, chapter.subtitle],
			n, s, chapter.chapter_name, chapter.subtitle, "chapitre"
		)
		_main._undo_redo.push(cmd)
		_main._refresh_undo_redo_buttons()
	)


func on_scene_rename_requested(uuid: String) -> void:
	if _main._editor_main._current_chapter == null:
		return
	var scene = _main._editor_main._current_chapter.find_scene(uuid)
	if scene == null:
		return
	_open_rename_dialog(uuid, scene.scene_name, scene.subtitle, func(u, n, s):
		var cmd = RenameNodeCommand.new(
			func(nm, sub): scene.scene_name = nm; scene.subtitle = sub; _main._scene_graph_view.rename_scene(u, nm, sub),
			func(): return [scene.scene_name, scene.subtitle],
			n, s, scene.scene_name, scene.subtitle, "scène"
		)
		_main._undo_redo.push(cmd)
		_main._refresh_undo_redo_buttons()
	)


func on_sequence_rename_requested(uuid: String) -> void:
	if _main._editor_main._current_scene == null:
		return
	var seq = _main._editor_main._current_scene.find_sequence(uuid)
	if seq == null:
		return
	_open_rename_dialog(uuid, seq.seq_name, seq.subtitle, func(u, n, s):
		var cmd = RenameNodeCommand.new(
			func(nm, sub): seq.seq_name = nm; seq.subtitle = sub; _main._sequence_graph_view.rename_sequence(u, nm, sub),
			func(): return [seq.seq_name, seq.subtitle],
			n, s, seq.seq_name, seq.subtitle, "séquence"
		)
		_main._undo_redo.push(cmd)
		_main._refresh_undo_redo_buttons()
	)


func on_condition_rename_requested(uuid: String) -> void:
	if _main._editor_main._current_scene == null:
		return
	var cond = _main._editor_main._current_scene.find_condition(uuid)
	if cond == null:
		return
	_open_rename_dialog(uuid, cond.condition_name, cond.subtitle, func(u, n, s):
		var cmd = RenameNodeCommand.new(
			func(nm, sub): cond.condition_name = nm; cond.subtitle = sub; _main._sequence_graph_view.rename_condition(u, nm, sub),
			func(): return [cond.condition_name, cond.subtitle],
			n, s, cond.condition_name, cond.subtitle, "condition"
		)
		_main._undo_redo.push(cmd)
		_main._refresh_undo_redo_buttons()
	)


func _open_rename_dialog(uuid: String, current_name: String, current_subtitle: String, callback: Callable) -> void:
	if _rename_dialog != null and is_instance_valid(_rename_dialog):
		_rename_dialog.queue_free()
	_rename_dialog = ConfirmationDialog.new()
	_rename_dialog.set_script(RenameDialogScript)
	_main.add_child(_rename_dialog)
	_rename_dialog.setup(uuid, current_name, current_subtitle)
	_rename_dialog.rename_confirmed.connect(func(u, n, s):
		callback.call(u, n, s)
	)
	_rename_dialog.popup_centered()


# --- Save / Load ---

func on_save_pressed() -> void:
	if _main._editor_main._story == null:
		return
	_sync_positions()
	if _last_save_path != "":
		_do_save(_last_save_path)
	else:
		_open_save_dialog()


func on_save_as_pressed() -> void:
	if _main._editor_main._story == null:
		return
	_sync_positions()
	_open_save_dialog()


func _sync_positions() -> void:
	var level = _main._editor_main.get_current_level()
	if level == "chapters":
		_main._chapter_graph_view.sync_positions_to_model()
	elif level == "scenes":
		_main._scene_graph_view.sync_positions_to_model()
	elif level == "sequences":
		_main._sequence_graph_view.sync_positions_to_model()


func _open_save_dialog() -> void:
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.current_dir = _last_save_path if _last_save_path != "" else OS.get_environment("HOME")
	dialog.dir_selected.connect(_on_save_dir_selected)
	_main.add_child(dialog)
	dialog.popup_centered(Vector2i(800, 600))


func _on_save_dir_selected(path: String) -> void:
	_do_save(path)


func _do_save(path: String) -> void:
	_last_save_path = path
	_main._editor_main._story.touch()
	StorySaver.save_story(_main._editor_main._story, path)
	_main._save_button.text = "Sauvegardé !"
	_main._save_button.disabled = true
	_main.get_tree().create_timer(2.0).timeout.connect(func():
		_main._save_button.text = "Sauvegarder"
		_main._save_button.disabled = false
	)


func on_load_pressed() -> void:
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.current_dir = OS.get_environment("HOME")
	dialog.dir_selected.connect(_on_load_dir_selected)
	_main.add_child(dialog)
	dialog.popup_centered(Vector2i(800, 600))


func _on_load_dir_selected(path: String) -> void:
	var loaded_story = StorySaver.load_story(path)
	if loaded_story == null:
		var err_dialog = AcceptDialog.new()
		err_dialog.dialog_text = "Impossible de charger l'histoire : fichier story.yaml introuvable dans le dossier sélectionné."
		_main.add_child(err_dialog)
		err_dialog.popup_centered()
		return
	_last_save_path = path
	_main._undo_redo.clear()
	_main._editor_main.open_story(loaded_story)
	_main.refresh_current_view()


func on_new_story_pressed() -> void:
	var story = StoryScript.new()
	story.title = "Mon Histoire"
	story.author = "Auteur"
	story.description = "Une histoire de démonstration"

	var chapter = ChapterScript.new()
	chapter.chapter_name = "Chapitre 1"
	chapter.position = Vector2(100, 100)
	story.chapters.append(chapter)

	var scene = SceneDataScript.new()
	scene.scene_name = "Scène 1"
	scene.position = Vector2(100, 100)
	chapter.scenes.append(scene)

	var seq = SequenceScript.new()
	seq.seq_name = "Séquence 1"
	seq.position = Vector2(100, 100)
	scene.sequences.append(seq)

	_main._undo_redo.clear()
	_main._editor_main.open_story(story)
	_main.refresh_current_view()


# --- Variables ---

func on_variables_pressed() -> void:
	if _main._editor_main._story == null:
		return
	_main._variable_panel.load_story(_main._editor_main._story)
	_main._variable_panel_popup.popup_centered()


func on_menu_config_requested() -> void:
	if _main._editor_main._story == null:
		return
	if _menu_config_dialog != null and is_instance_valid(_menu_config_dialog):
		_menu_config_dialog.queue_free()
	_menu_config_dialog = ConfirmationDialog.new()
	_menu_config_dialog.set_script(MenuConfigDialogScript)
	_main.add_child(_menu_config_dialog)
	_menu_config_dialog.setup(_main._editor_main._story, _last_save_path)
	_menu_config_dialog.menu_config_confirmed.connect(_on_menu_config_confirmed)
	_menu_config_dialog.popup_centered()


func _on_menu_config_confirmed(menu_title: String, menu_subtitle: String, menu_background: String) -> void:
	_main._editor_main._story.menu_title = menu_title
	_main._editor_main._story.menu_subtitle = menu_subtitle
	_main._editor_main._story.menu_background = menu_background


func on_variables_changed() -> void:
	if _main._editor_main._story:
		var names = _main._editor_main._story.get_variable_names()
		_main._ending_editor.set_variable_names(names)


# --- Ending ---

func on_ending_changed() -> void:
	_update_ending_connections()
	_update_ending_tab_indicator()


func _update_ending_tab_indicator() -> void:
	if _main._tab_container == null:
		return
	var seq = _main._sequence_editor_ctrl.get_sequence() if _main._sequence_editor_ctrl else null
	if seq and seq.ending != null:
		_main._tab_container.set_tab_title(1, "Terminaison ●")
	else:
		_main._tab_container.set_tab_title(1, "Terminaison")


func update_ending_targets() -> void:
	var targets = _build_available_targets()
	_main._ending_editor.set_available_targets(targets["sequences"], targets["scenes"], targets["chapters"], targets["conditions"])


func _update_ending_connections() -> void:
	if _main._editor_main._current_scene and _main._sequence_graph_view:
		_main._sequence_graph_view.load_scene(_main._editor_main._current_scene)


# --- Condition ---

func on_condition_changed() -> void:
	_update_ending_connections()


func load_condition_editor(cond) -> void:
	_update_condition_targets()
	if _main._editor_main._story:
		_main._condition_editor.set_variable_names(_main._editor_main._story.get_variable_names())
	_main._condition_editor.load_condition(cond)


func _update_condition_targets() -> void:
	var targets = _build_available_targets()
	_main._condition_editor.set_available_targets(targets["sequences"], targets["scenes"], targets["chapters"], targets["conditions"])


# --- Verifier ---

func on_verify_pressed() -> void:
	if _main._editor_main._story == null:
		return
	var verifier = StoryVerifierScript.new()
	var report = verifier.verify(_main._editor_main._story)
	_main._verifier_report_panel.show_report(report)
	_main._verifier_report_panel.visible = true
	_main._chapter_graph_view.visible = false
	_main._scene_graph_view.visible = false
	_main._sequence_graph_view.visible = false
	_main._sequence_editor_panel.visible = false
	_main._condition_editor_panel.visible = false


func on_verifier_close() -> void:
	_main._verifier_report_panel.visible = false
	_main.update_view()


func _build_available_targets() -> Dictionary:
	var sequences: Array = []
	var conditions: Array = []
	var scenes: Array = []
	var chapters: Array = []
	if _main._editor_main._current_scene:
		for seq in _main._editor_main._current_scene.sequences:
			sequences.append({"uuid": seq.uuid, "name": seq.seq_name})
		for c in _main._editor_main._current_scene.conditions:
			conditions.append({"uuid": c.uuid, "name": c.condition_name})
	if _main._editor_main._current_chapter:
		for sc in _main._editor_main._current_chapter.scenes:
			scenes.append({"uuid": sc.uuid, "name": sc.scene_name})
	if _main._editor_main._story:
		for ch in _main._editor_main._story.chapters:
			chapters.append({"uuid": ch.uuid, "name": ch.chapter_name})
	return {"sequences": sequences, "conditions": conditions, "scenes": scenes, "chapters": chapters}
