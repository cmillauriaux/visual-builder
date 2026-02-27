extends Node

## Gère la navigation (back, breadcrumb, double-click), la création d'éléments,
## le renommage, la sauvegarde/chargement, et la gestion des endings/conditions/variables.

const StoryScript = preload("res://src/models/story.gd")
const ChapterScript = preload("res://src/models/chapter.gd")
const SceneDataScript = preload("res://src/models/scene_data.gd")
const SequenceScript = preload("res://src/models/sequence.gd")
const StorySaver = preload("res://src/persistence/story_saver.gd")
const RenameDialogScript = preload("res://src/ui/dialogs/rename_dialog.gd")

var _main: Control
var _rename_dialog: ConfirmationDialog


func setup(main: Control) -> void:
	_main = main


# --- Create ---

func on_create_pressed() -> void:
	var level = _main._editor_main.get_current_level()
	var item_name = _main._editor_main.get_next_item_name()
	if level == "chapters":
		var pos = _main._editor_main.compute_next_position(_main._editor_main._story.chapters)
		_main._chapter_graph_view.add_new_chapter(item_name, pos)
	elif level == "scenes":
		var pos = _main._editor_main.compute_next_position(_main._editor_main._current_chapter.scenes)
		_main._scene_graph_view.add_new_scene(item_name, pos)
	elif level == "sequences":
		var pos = _main._editor_main.compute_next_position(_main._editor_main._current_scene.sequences)
		_main._sequence_graph_view.add_new_sequence(item_name, pos)


func on_create_condition_pressed() -> void:
	if _main._editor_main.get_current_level() != "sequences":
		return
	var cond_name = _main._editor_main.get_next_condition_name()
	var all_items: Array = []
	all_items.append_array(_main._editor_main._current_scene.sequences)
	all_items.append_array(_main._editor_main._current_scene.conditions)
	var pos = _main._editor_main.compute_next_position(all_items)
	_main._sequence_graph_view.add_new_condition(cond_name, pos)


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
		_main._chapter_graph_view.rename_chapter(u, n, s)
	)


func on_scene_rename_requested(uuid: String) -> void:
	if _main._editor_main._current_chapter == null:
		return
	var scene = _main._editor_main._current_chapter.find_scene(uuid)
	if scene == null:
		return
	_open_rename_dialog(uuid, scene.scene_name, scene.subtitle, func(u, n, s):
		_main._scene_graph_view.rename_scene(u, n, s)
	)


func on_sequence_rename_requested(uuid: String) -> void:
	if _main._editor_main._current_scene == null:
		return
	var seq = _main._editor_main._current_scene.find_sequence(uuid)
	if seq == null:
		return
	_open_rename_dialog(uuid, seq.seq_name, seq.subtitle, func(u, n, s):
		_main._sequence_graph_view.rename_sequence(u, n, s)
	)


func on_condition_rename_requested(uuid: String) -> void:
	if _main._editor_main._current_scene == null:
		return
	var cond = _main._editor_main._current_scene.find_condition(uuid)
	if cond == null:
		return
	_open_rename_dialog(uuid, cond.condition_name, cond.subtitle, func(u, n, s):
		_main._sequence_graph_view.rename_condition(u, n, s)
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
	var level = _main._editor_main.get_current_level()
	if level == "chapters":
		_main._chapter_graph_view.sync_positions_to_model()
	elif level == "scenes":
		_main._scene_graph_view.sync_positions_to_model()
	elif level == "sequences":
		_main._sequence_graph_view.sync_positions_to_model()
	_main._editor_main._story.touch()
	StorySaver.save_story(_main._editor_main._story, "user://stories/" + _main._editor_main._story.title.to_lower().replace(" ", "_"))
	_main._save_button.text = "Sauvegardé !"
	_main._save_button.disabled = true
	_main.get_tree().create_timer(2.0).timeout.connect(func():
		_main._save_button.text = "Sauvegarder"
		_main._save_button.disabled = false
	)


func on_load_pressed() -> void:
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	dialog.access = FileDialog.ACCESS_USERDATA
	dialog.current_dir = "user://stories/"
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

	_main._editor_main.open_story(story)
	_main.refresh_current_view()


# --- Variables ---

func on_variables_pressed() -> void:
	if _main._editor_main._story == null:
		return
	_main._variable_panel.load_story(_main._editor_main._story)
	_main._variable_panel_popup.popup_centered()


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
