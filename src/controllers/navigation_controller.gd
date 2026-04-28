# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

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
const RemoveChapterCommand = preload("res://src/commands/remove_chapter_command.gd")
const RemoveSceneCommand = preload("res://src/commands/remove_scene_command.gd")
const RemoveSequenceCommand = preload("res://src/commands/remove_sequence_command.gd")
const RemoveConditionCommand = preload("res://src/commands/remove_condition_command.gd")
const SetSequenceTransitionCommand = preload("res://src/commands/set_sequence_transition_command.gd")
const EditorState = preload("res://src/controllers/editor_state.gd")
const ForegroundScript = preload("res://src/models/foreground.gd")

var _main: Control
var _rename_dialog: ConfirmationDialog
var _menu_config_dialog: ConfirmationDialog
var _last_save_path: String = ""
var _current_mode: int = -1


func get_save_path() -> String:
	return _last_save_path


func setup(main: Control) -> void:
	_main = main


func update_editor_mode() -> void:
	var level = _main._editor_main.get_current_level()
	var new_mode = EditorState.Mode.NONE
	
	if _main._play_ctrl and _main._play_ctrl.is_story_play_mode():
		new_mode = EditorState.Mode.PLAY_MODE
	else:
		match level:
			"chapters": new_mode = EditorState.Mode.CHAPTER_VIEW
			"scenes": new_mode = EditorState.Mode.SCENE_VIEW
			"sequences": new_mode = EditorState.Mode.SEQUENCE_VIEW
			"sequence_edit": new_mode = EditorState.Mode.SEQUENCE_EDIT
			"condition_edit": new_mode = EditorState.Mode.CONDITION_EDIT
			"map": new_mode = EditorState.Mode.MAP_VIEW
	
	if new_mode != _current_mode:
		_current_mode = new_mode
		EventBus.editor_mode_changed.emit(_current_mode, {
			"level": level,
			"chapter": _main._editor_main._current_chapter,
			"scene": _main._editor_main._current_scene,
			"sequence": _main._editor_main._current_sequence,
			"condition": _main._editor_main._current_condition
		})


# --- Map ---

func on_map_pressed() -> void:
	if _main._editor_main.get_current_level() == "map":
		_main._editor_main.navigate_back()
	else:
		_main._editor_main.navigate_to_map()
	update_editor_mode()
	_main.refresh_current_view()


# --- Create ---

func on_create_pressed() -> void:
	var level = _main._editor_main.get_current_level()
	var item_name = _main._editor_main.get_next_item_name()
	if level == "chapters":
		var pos = _main._editor_main.compute_next_position(_main._editor_main._story.chapters)
		var cmd = AddChapterCommand.new(_main._editor_main._story, item_name, pos)
		_main._undo_redo.push_and_execute(cmd)
		_main._chapter_graph_view.load_story(_main._editor_main._story)
		notify_targets_changed()
	elif level == "scenes":
		var pos = _main._editor_main.compute_next_position(_main._editor_main._current_chapter.scenes)
		var cmd = AddSceneCommand.new(_main._editor_main._current_chapter, item_name, pos)
		_main._undo_redo.push_and_execute(cmd)
		_main._scene_graph_view.load_chapter(_main._editor_main._current_chapter)
		notify_targets_changed()
	elif level == "sequences":
		var pos = _main._editor_main.compute_next_position(_main._editor_main._current_scene.sequences)
		var cmd = AddSequenceCommand.new(_main._editor_main._current_scene, item_name, pos)
		_main._undo_redo.push_and_execute(cmd)
		_main._sequence_graph_view.load_scene(_main._editor_main._current_scene)
		notify_targets_changed()
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
	_main._undo_redo.push_and_execute(cmd)
	_main._sequence_graph_view.load_scene(_main._editor_main._current_scene)
	notify_targets_changed()


func on_chapter_delete_requested(uuid: String) -> void:
	var chapter = _main._editor_main._story.find_chapter(uuid)
	if chapter:
		var cmd = RemoveChapterCommand.new(_main._editor_main._story, chapter)
		_main._undo_redo.push_and_execute(cmd)
		_main._chapter_graph_view.load_story(_main._editor_main._story)
		notify_targets_changed()


func on_scene_delete_requested(uuid: String) -> void:
	var scene = _main._editor_main._current_chapter.find_scene(uuid)
	if scene:
		var cmd = RemoveSceneCommand.new(_main._editor_main._current_chapter, scene)
		_main._undo_redo.push_and_execute(cmd)
		_main._scene_graph_view.load_chapter(_main._editor_main._current_chapter)
		notify_targets_changed()


func on_sequence_delete_requested(uuid: String) -> void:
	var seq = _main._editor_main._current_scene.find_sequence(uuid)
	if seq:
		var cmd = RemoveSequenceCommand.new(_main._editor_main._current_scene, seq)
		_main._undo_redo.push_and_execute(cmd)
		_main._sequence_graph_view.load_scene(_main._editor_main._current_scene)
		notify_targets_changed()


func on_condition_delete_requested(uuid: String) -> void:
	var cond = _main._editor_main._current_scene.find_condition(uuid)
	if cond:
		var cmd = RemoveConditionCommand.new(_main._editor_main._current_scene, cond)
		_main._undo_redo.push_and_execute(cmd)
		_main._sequence_graph_view.load_scene(_main._editor_main._current_scene)
		notify_targets_changed()


func on_sequences_transition_requested(uuids: Array, property: String, value: String) -> void:
	if _main._editor_main._current_scene == null:
		return
		
	var sequences = []
	for uuid in uuids:
		var seq = _main._editor_main._current_scene.find_sequence(uuid)
		if seq:
			sequences.append(seq)
	
	if sequences.is_empty():
		return
		
	var cmd = SetSequenceTransitionCommand.new(sequences, property, value)
	_main._undo_redo.push_and_execute(cmd)
	# Pas besoin de recharger tout le graphe, mais on notifie d'une modification
	EventBus.story_modified.emit()


func on_sequence_foregrounds_paste(target_uuid: String, clipboard_data: Dictionary) -> void:
	if _main._editor_main._current_scene == null:
		return
	var seq = _main._editor_main._current_scene.find_sequence(target_uuid)
	if seq == null:
		return

	# Remplacer les foregrounds de la séquence
	var new_seq_fgs := []
	for fg_dict in clipboard_data.get("sequence_foregrounds", []):
		var fg = ForegroundScript.from_dict(fg_dict)
		fg.uuid = ForegroundScript._generate_uuid()
		new_seq_fgs.append(fg)
	seq.foregrounds = new_seq_fgs

	# Appliquer les foregrounds dialogue par dialogue (par index)
	var dlg_fgs_data: Array = clipboard_data.get("dialogue_foregrounds", [])
	for i in range(mini(seq.dialogues.size(), dlg_fgs_data.size())):
		var new_dlg_fgs := []
		for fg_dict in dlg_fgs_data[i]:
			var fg = ForegroundScript.from_dict(fg_dict)
			fg.uuid = ForegroundScript._generate_uuid()
			new_dlg_fgs.append(fg)
		seq.dialogues[i].foregrounds = new_dlg_fgs

	EventBus.story_modified.emit()


func notify_targets_changed() -> void:
	var targets = _build_available_targets()
	EventBus.targets_updated.emit(targets["sequences"], targets["scenes"], targets["chapters"], targets["conditions"])


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

func on_story_rename_confirmed(new_name: String) -> void:
	if _main._editor_main._story == null:
		return
	_main._editor_main._story.title = new_name
	_main.refresh_current_view()
	EventBus.story_modified.emit()


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
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	_main.add_child(dialog)
	dialog.popup_centered(Vector2i(800, 600))


func _on_save_dir_selected(path: String) -> void:
	_do_save(path)


func _do_save(path: String) -> void:
	_last_save_path = path
	_main._editor_main._story.touch()
	StorySaver.save_story(_main._editor_main._story, path)


func on_load_pressed() -> void:
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.current_dir = OS.get_environment("HOME")
	dialog.dir_selected.connect(_on_load_dir_selected)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	_main.add_child(dialog)
	dialog.popup_centered(Vector2i(800, 600))


func _on_load_dir_selected(path: String) -> void:
	var loaded_story = StorySaver.load_story(path)
	if loaded_story == null:
		_show_load_error(tr("Impossible de charger l'histoire : fichier story.yaml introuvable dans le dossier sélectionné."))
		return
	_last_save_path = path
	_main._undo_redo.clear()
	_main._editor_main.open_story(loaded_story)
	_main.refresh_current_view()


func on_reload_pressed() -> void:
	if _main._editor_main._story == null:
		return
	if _last_save_path == "":
		_show_load_error(tr("Impossible de recharger l'histoire : aucun dossier de sauvegarde n'est associé à l'histoire courante."))
		return

	var dialog = ConfirmationDialog.new()
	dialog.title = tr("Recharger l'histoire")
	dialog.dialog_text = tr("Recharger l'histoire depuis :\n%s\n\nLes modifications non sauvegardées seront perdues.") % _last_save_path
	dialog.confirmed.connect(func():
		_reload_current_story()
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	_main.add_child(dialog)
	dialog.get_ok_button().text = tr("Recharger")
	dialog.popup_centered()


func _reload_current_story() -> void:
	var loaded_story = StorySaver.load_story(_last_save_path)
	if loaded_story == null:
		_show_load_error(tr("Impossible de recharger l'histoire : fichier story.yaml introuvable dans le dossier courant."))
		return

	var nav_state = _capture_navigation_state()
	_main._undo_redo.clear()
	_main._editor_main.open_story(loaded_story)
	_restore_navigation_state(nav_state)
	_main.refresh_current_view()


func _capture_navigation_state() -> Dictionary:
	return {
		"level": _main._editor_main.get_current_level(),
		"chapter_uuid": _main._editor_main._current_chapter.uuid if _main._editor_main._current_chapter else "",
		"scene_uuid": _main._editor_main._current_scene.uuid if _main._editor_main._current_scene else "",
		"sequence_uuid": _main._editor_main._current_sequence.uuid if _main._editor_main._current_sequence else "",
		"condition_uuid": _main._editor_main._current_condition.uuid if _main._editor_main._current_condition else ""
	}


func _restore_navigation_state(state: Dictionary) -> void:
	var level: String = state.get("level", "chapters")
	var chapter_uuid: String = state.get("chapter_uuid", "")
	var scene_uuid: String = state.get("scene_uuid", "")

	if level in ["scenes", "sequences", "sequence_edit", "condition_edit"] and chapter_uuid != "":
		_main._editor_main.navigate_to_chapter(chapter_uuid)
	if level in ["sequences", "sequence_edit", "condition_edit"] and scene_uuid != "":
		_main._editor_main.navigate_to_scene(scene_uuid)
	if level == "sequence_edit":
		var sequence_uuid: String = state.get("sequence_uuid", "")
		if sequence_uuid != "":
			_main._editor_main.navigate_to_sequence(sequence_uuid)
			if _main._editor_main._current_sequence:
				_main.load_sequence_editors(_main._editor_main._current_sequence)
	elif level == "condition_edit":
		var condition_uuid: String = state.get("condition_uuid", "")
		if condition_uuid != "":
			_main._editor_main.navigate_to_condition(condition_uuid)
			if _main._editor_main._current_condition:
				load_condition_editor(_main._editor_main._current_condition)
	elif level == "map":
		_main._editor_main.navigate_to_map()


func _show_load_error(message: String) -> void:
	var err_dialog = AcceptDialog.new()
	err_dialog.dialog_text = message
	err_dialog.confirmed.connect(err_dialog.queue_free)
	_main.add_child(err_dialog)
	err_dialog.popup_centered()


func on_new_story_pressed() -> void:
	TextureLoader.base_dir = ""
	_last_save_path = ""
	var story = StoryScript.new()
	story.title = tr("Mon Histoire")
	story.author = tr("Auteur")
	story.description = tr("Une histoire de démonstration")

	var chapter = ChapterScript.new()
	chapter.chapter_name = tr("Chapitre 1")
	chapter.position = Vector2(100, 100)
	story.chapters.append(chapter)

	var scene = SceneDataScript.new()
	scene.scene_name = tr("Scène 1")
	scene.position = Vector2(100, 100)
	chapter.scenes.append(scene)

	var seq = SequenceScript.new()
	seq.seq_name = tr("Séquence 1")
	seq.position = Vector2(100, 100)
	scene.sequences.append(seq)

	var dlg = DialogueModel.new()
	dlg.character = tr("Narrateur")
	dlg.text = tr("Bienvenue dans votre nouvelle histoire.")
	seq.dialogues.append(dlg)

	_main._undo_redo.clear()
	_main._editor_main.open_story(story)
	_main.refresh_current_view()


# --- Variables ---

func _on_languages_changed() -> void:
	EventBus.story_modified.emit()


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
	_menu_config_dialog.story_rename_requested.connect(on_story_rename_confirmed)
	_menu_config_dialog.variables_changed.connect(on_variables_changed)
	_menu_config_dialog.languages_changed.connect(_on_languages_changed)
	_menu_config_dialog.popup_centered_ratio(0.85)


func _on_menu_config_confirmed(menu_title: String, menu_subtitle: String, menu_background: String, menu_music: String = "", patreon_url: String = "", itchio_url: String = "", game_over_title: String = "", game_over_subtitle: String = "", game_over_background: String = "", to_be_continued_title: String = "", to_be_continued_subtitle: String = "", to_be_continued_background: String = "", the_end_title: String = "", the_end_subtitle: String = "", the_end_background: String = "", app_icon: String = "", show_title_banner: bool = true, ui_theme_mode: String = "default", plugin_settings: Dictionary = {}, platform_settings: Dictionary = {}) -> void:
	_main._editor_main._story.menu_title = menu_title
	_main._editor_main._story.menu_subtitle = menu_subtitle
	_main._editor_main._story.menu_background = menu_background
	_main._editor_main._story.menu_music = menu_music
	_main._editor_main._story.patreon_url = patreon_url
	_main._editor_main._story.itchio_url = itchio_url
	_main._editor_main._story.game_over_title = game_over_title
	_main._editor_main._story.game_over_subtitle = game_over_subtitle
	_main._editor_main._story.game_over_background = game_over_background
	_main._editor_main._story.to_be_continued_title = to_be_continued_title
	_main._editor_main._story.to_be_continued_subtitle = to_be_continued_subtitle
	_main._editor_main._story.to_be_continued_background = to_be_continued_background
	_main._editor_main._story.the_end_title = the_end_title
	_main._editor_main._story.the_end_subtitle = the_end_subtitle
	_main._editor_main._story.the_end_background = the_end_background
	_main._editor_main._story.app_icon = app_icon
	_main._editor_main._story.show_title_banner = show_title_banner
	_main._editor_main._story.ui_theme_mode = ui_theme_mode
	_main._editor_main._story.plugin_settings = plugin_settings
	_main._editor_main._story.platform_settings = platform_settings
	EventBus.story_modified.emit()


func on_variables_changed() -> void:
	EventBus.story_modified.emit()


# --- Ending ---

func on_ending_changed() -> void:
	_update_ending_connections()


func _update_ending_connections() -> void:
	if _main._editor_main._current_scene and _main._sequence_graph_view:
		_main._sequence_graph_view.load_scene(_main._editor_main._current_scene)


# --- Condition ---

func on_condition_changed() -> void:
	_update_ending_connections()


func load_condition_editor(cond) -> void:
	notify_targets_changed()
	_main._condition_editor.load_condition(cond)


# --- Verifier ---

func on_verify_pressed() -> void:
	if _main._editor_main._story == null:
		return
	var verifier = StoryVerifierScript.new()
	var report = verifier.verify(_main._editor_main._story, _main._get_story_base_path())
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


func _on_new_target_requested(ctype: String, callback: Callable) -> void:
	match ctype:
		"redirect_sequence":
			if _main._editor_main._current_scene == null:
				return
			var name = tr("Séquence %d") % (_main._editor_main._current_scene.sequences.size() + 1)
			var all_items: Array = []
			all_items.append_array(_main._editor_main._current_scene.sequences)
			all_items.append_array(_main._editor_main._current_scene.conditions)
			var pos = _main._editor_main.compute_next_position(all_items)
			var cmd = AddSequenceCommand.new(_main._editor_main._current_scene, name, pos)
			_main._undo_redo.push_and_execute(cmd)
			var new_uuid = _main._editor_main._current_scene.sequences.back().uuid
			notify_targets_changed()
			callback.call(new_uuid)
			_update_ending_connections()
		"redirect_scene":
			if _main._editor_main._current_chapter == null:
				return
			var name = tr("Scène %d") % (_main._editor_main._current_chapter.scenes.size() + 1)
			var pos = _main._editor_main.compute_next_position(_main._editor_main._current_chapter.scenes)
			var cmd = AddSceneCommand.new(_main._editor_main._current_chapter, name, pos)
			_main._undo_redo.push_and_execute(cmd)
			var new_uuid = _main._editor_main._current_chapter.scenes.back().uuid
			notify_targets_changed()
			callback.call(new_uuid)
			_update_ending_connections()
		"redirect_chapter":
			if _main._editor_main._story == null:
				return
			var name = tr("Chapitre %d") % (_main._editor_main._story.chapters.size() + 1)
			var pos = _main._editor_main.compute_next_position(_main._editor_main._story.chapters)
			var cmd = AddChapterCommand.new(_main._editor_main._story, name, pos)
			_main._undo_redo.push_and_execute(cmd)
			var new_uuid = _main._editor_main._story.chapters.back().uuid
			notify_targets_changed()
			callback.call(new_uuid)
			_update_ending_connections()


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
