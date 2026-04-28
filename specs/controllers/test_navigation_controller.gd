extends GutTest

## Tests pour NavigationController — navigation, création, renommage.

var MainScript
var NavigationControllerScript
var StoryScript
var ChapterScript
var SceneDataScript
var SequenceScript
var StorySaver

var _main
var _test_dir: String = ""


func before_each() -> void:
	MainScript = load("res://src/main.gd")
	NavigationControllerScript = load("res://src/controllers/navigation_controller.gd")
	StoryScript = load("res://src/models/story.gd")
	ChapterScript = load("res://src/models/chapter.gd")
	SceneDataScript = load("res://src/models/scene_data.gd")
	SequenceScript = load("res://src/models/sequence.gd")
	StorySaver = load("res://src/persistence/story_saver.gd")
	_test_dir = "user://test_nav_reload_" + str(randi())
	
	_main = Control.new()
	_main.set_script(MainScript)
	add_child(_main)


func after_each() -> void:
	if _main:
		_main.queue_free()
		_main = null
	_remove_dir_recursive(_test_dir)


func _remove_dir_recursive(path: String) -> void:
	var dir = DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if dir.current_is_dir():
			_remove_dir_recursive(path + "/" + fname)
		else:
			dir.remove(fname)
		fname = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)


func test_nav_controller_exists() -> void:
	assert_not_null(_main._nav_ctrl)

func test_on_new_story_pressed_creates_story() -> void:
	_main._nav_ctrl.on_new_story_pressed()
	assert_not_null(_main._editor_main._story)
	assert_eq(_main._editor_main._story.title, "Mon Histoire")
	assert_eq(_main._editor_main._story.chapters.size(), 1)

func test_on_create_pressed_at_chapters_level() -> void:
	_main._nav_ctrl.on_new_story_pressed()
	var initial_count = _main._editor_main._story.chapters.size()
	_main._nav_ctrl.on_create_pressed()
	assert_eq(_main._editor_main._story.chapters.size(), initial_count + 1)


# --- get_save_path ---

func test_get_save_path_default() -> void:
	assert_eq(_main._nav_ctrl.get_save_path(), "")


# --- update_editor_mode ---

func test_update_editor_mode_at_chapters_level() -> void:
	_main._nav_ctrl.on_new_story_pressed()
	_main._nav_ctrl.update_editor_mode()
	pass_test("update_editor_mode at chapters level should not crash")


# --- on_create_pressed at scenes/sequences levels ---

func test_on_create_pressed_at_scenes_level() -> void:
	_main._nav_ctrl.on_new_story_pressed()
	var chapter = _main._editor_main._story.chapters[0]
	_main._nav_ctrl.on_chapter_double_clicked(chapter.uuid)
	var initial_count = chapter.scenes.size()
	_main._nav_ctrl.on_create_pressed()
	assert_eq(chapter.scenes.size(), initial_count + 1)

func test_on_create_pressed_at_sequences_level() -> void:
	_main._nav_ctrl.on_new_story_pressed()
	var chapter = _main._editor_main._story.chapters[0]
	_main._nav_ctrl.on_chapter_double_clicked(chapter.uuid)
	var scene = chapter.scenes[0]
	_main._nav_ctrl.on_scene_double_clicked(scene.uuid)
	var initial_count = scene.sequences.size()
	_main._nav_ctrl.on_create_pressed()
	assert_eq(scene.sequences.size(), initial_count + 1)


# --- on_create_condition_pressed ---

func test_on_create_condition_pressed_at_sequences_level() -> void:
	_main._nav_ctrl.on_new_story_pressed()
	var chapter = _main._editor_main._story.chapters[0]
	_main._nav_ctrl.on_chapter_double_clicked(chapter.uuid)
	var scene = chapter.scenes[0]
	_main._nav_ctrl.on_scene_double_clicked(scene.uuid)
	var initial_count = scene.conditions.size()
	_main._nav_ctrl.on_create_condition_pressed()
	assert_eq(scene.conditions.size(), initial_count + 1)

func test_on_create_condition_pressed_at_chapters_level_returns_early() -> void:
	_main._nav_ctrl.on_new_story_pressed()
	# At chapters level — should return early without crash
	_main._nav_ctrl.on_create_condition_pressed()
	pass_test("on_create_condition_pressed at chapters level should not crash")


# --- Delete operations ---

func test_on_chapter_delete_requested() -> void:
	_main._nav_ctrl.on_new_story_pressed()
	_main._nav_ctrl.on_create_pressed()  # add a second chapter
	var initial_count = _main._editor_main._story.chapters.size()
	var uuid = _main._editor_main._story.chapters[0].uuid
	_main._nav_ctrl.on_chapter_delete_requested(uuid)
	assert_eq(_main._editor_main._story.chapters.size(), initial_count - 1)

func test_on_chapter_delete_requested_invalid_uuid() -> void:
	_main._nav_ctrl.on_new_story_pressed()
	var initial_count = _main._editor_main._story.chapters.size()
	_main._nav_ctrl.on_chapter_delete_requested("invalid-uuid")
	assert_eq(_main._editor_main._story.chapters.size(), initial_count)

func test_on_scene_delete_requested() -> void:
	_main._nav_ctrl.on_new_story_pressed()
	var chapter = _main._editor_main._story.chapters[0]
	_main._nav_ctrl.on_chapter_double_clicked(chapter.uuid)
	_main._nav_ctrl.on_create_pressed()  # add a second scene
	var initial_count = chapter.scenes.size()
	var uuid = chapter.scenes[0].uuid
	_main._nav_ctrl.on_scene_delete_requested(uuid)
	assert_eq(chapter.scenes.size(), initial_count - 1)

func test_on_scene_delete_requested_invalid_uuid() -> void:
	_main._nav_ctrl.on_new_story_pressed()
	var chapter = _main._editor_main._story.chapters[0]
	_main._nav_ctrl.on_chapter_double_clicked(chapter.uuid)
	var initial_count = chapter.scenes.size()
	_main._nav_ctrl.on_scene_delete_requested("invalid-uuid")
	assert_eq(chapter.scenes.size(), initial_count)

func test_on_sequence_delete_requested() -> void:
	_main._nav_ctrl.on_new_story_pressed()
	var chapter = _main._editor_main._story.chapters[0]
	_main._nav_ctrl.on_chapter_double_clicked(chapter.uuid)
	var scene = chapter.scenes[0]
	_main._nav_ctrl.on_scene_double_clicked(scene.uuid)
	_main._nav_ctrl.on_create_pressed()  # add a second sequence
	var initial_count = scene.sequences.size()
	var uuid = scene.sequences[0].uuid
	_main._nav_ctrl.on_sequence_delete_requested(uuid)
	assert_eq(scene.sequences.size(), initial_count - 1)

func test_on_sequence_delete_requested_invalid_uuid() -> void:
	_main._nav_ctrl.on_new_story_pressed()
	var chapter = _main._editor_main._story.chapters[0]
	_main._nav_ctrl.on_chapter_double_clicked(chapter.uuid)
	var scene = chapter.scenes[0]
	_main._nav_ctrl.on_scene_double_clicked(scene.uuid)
	var initial_count = scene.sequences.size()
	_main._nav_ctrl.on_sequence_delete_requested("invalid-uuid")
	assert_eq(scene.sequences.size(), initial_count)

func test_on_condition_delete_requested() -> void:
	_main._nav_ctrl.on_new_story_pressed()
	var chapter = _main._editor_main._story.chapters[0]
	_main._nav_ctrl.on_chapter_double_clicked(chapter.uuid)
	var scene = chapter.scenes[0]
	_main._nav_ctrl.on_scene_double_clicked(scene.uuid)
	_main._nav_ctrl.on_create_condition_pressed()
	assert_gt(scene.conditions.size(), 0)
	var uuid = scene.conditions[0].uuid
	_main._nav_ctrl.on_condition_delete_requested(uuid)
	assert_eq(scene.conditions.size(), 0)

func test_on_condition_delete_requested_invalid_uuid() -> void:
	_main._nav_ctrl.on_new_story_pressed()
	var chapter = _main._editor_main._story.chapters[0]
	_main._nav_ctrl.on_chapter_double_clicked(chapter.uuid)
	var scene = chapter.scenes[0]
	_main._nav_ctrl.on_scene_double_clicked(scene.uuid)
	_main._nav_ctrl.on_condition_delete_requested("invalid-uuid")
	pass_test("on_condition_delete_requested with invalid uuid should not crash")


# --- on_sequences_transition_requested ---

func test_on_sequences_transition_requested() -> void:
	_main._nav_ctrl.on_new_story_pressed()
	var chapter = _main._editor_main._story.chapters[0]
	_main._nav_ctrl.on_chapter_double_clicked(chapter.uuid)
	var scene = chapter.scenes[0]
	_main._nav_ctrl.on_scene_double_clicked(scene.uuid)
	var uuid = scene.sequences[0].uuid
	_main._nav_ctrl.on_sequences_transition_requested([uuid], "transition_in_type", "fade")
	assert_eq(scene.sequences[0].transition_in_type, "fade")

func test_on_sequences_transition_requested_null_scene() -> void:
	# No story → null scene → returns early
	_main._nav_ctrl.on_sequences_transition_requested([], "transition_in_type", "fade")
	pass_test("on_sequences_transition_requested with null scene should not crash")

func test_on_sequences_transition_requested_empty_uuids() -> void:
	_main._nav_ctrl.on_new_story_pressed()
	var chapter = _main._editor_main._story.chapters[0]
	_main._nav_ctrl.on_chapter_double_clicked(chapter.uuid)
	var scene = chapter.scenes[0]
	_main._nav_ctrl.on_scene_double_clicked(scene.uuid)
	# Empty uuid list → sequences.is_empty() → returns early
	_main._nav_ctrl.on_sequences_transition_requested([], "transition_in_type", "fade")
	pass_test("on_sequences_transition_requested with empty uuids should not crash")


# --- on_sequence_foregrounds_paste ---

func test_on_sequence_foregrounds_paste_null_scene() -> void:
	_main._nav_ctrl.on_sequence_foregrounds_paste("some-uuid", {})
	pass_test("on_sequence_foregrounds_paste with null scene should not crash")

func test_on_sequence_foregrounds_paste_invalid_uuid() -> void:
	_main._nav_ctrl.on_new_story_pressed()
	var chapter = _main._editor_main._story.chapters[0]
	_main._nav_ctrl.on_chapter_double_clicked(chapter.uuid)
	var scene = chapter.scenes[0]
	_main._nav_ctrl.on_scene_double_clicked(scene.uuid)
	_main._nav_ctrl.on_sequence_foregrounds_paste("invalid-uuid", {})
	pass_test("on_sequence_foregrounds_paste with invalid uuid should not crash")

func test_on_sequence_foregrounds_paste_success() -> void:
	_main._nav_ctrl.on_new_story_pressed()
	var chapter = _main._editor_main._story.chapters[0]
	_main._nav_ctrl.on_chapter_double_clicked(chapter.uuid)
	var scene = chapter.scenes[0]
	_main._nav_ctrl.on_scene_double_clicked(scene.uuid)
	var uuid = scene.sequences[0].uuid
	_main._nav_ctrl.on_sequence_foregrounds_paste(uuid, {
		"sequence_foregrounds": [],
		"dialogue_foregrounds": []
	})
	pass_test("on_sequence_foregrounds_paste with valid data should not crash")


# --- Navigation ---

func test_on_back_pressed_at_scenes_level() -> void:
	_main._nav_ctrl.on_new_story_pressed()
	var chapter = _main._editor_main._story.chapters[0]
	_main._nav_ctrl.on_chapter_double_clicked(chapter.uuid)
	assert_eq(_main._editor_main.get_current_level(), "scenes")
	_main._nav_ctrl.on_back_pressed()
	assert_eq(_main._editor_main.get_current_level(), "chapters")

func test_on_back_pressed_at_sequences_level() -> void:
	_main._nav_ctrl.on_new_story_pressed()
	var chapter = _main._editor_main._story.chapters[0]
	_main._nav_ctrl.on_chapter_double_clicked(chapter.uuid)
	var scene = chapter.scenes[0]
	_main._nav_ctrl.on_scene_double_clicked(scene.uuid)
	assert_eq(_main._editor_main.get_current_level(), "sequences")
	_main._nav_ctrl.on_back_pressed()
	assert_eq(_main._editor_main.get_current_level(), "scenes")

func test_on_breadcrumb_clicked_0_from_scenes() -> void:
	_main._nav_ctrl.on_new_story_pressed()
	var chapter = _main._editor_main._story.chapters[0]
	_main._nav_ctrl.on_chapter_double_clicked(chapter.uuid)
	_main._nav_ctrl.on_breadcrumb_clicked(0)
	assert_eq(_main._editor_main.get_current_level(), "chapters")

func test_on_breadcrumb_clicked_1_from_sequences() -> void:
	_main._nav_ctrl.on_new_story_pressed()
	var chapter = _main._editor_main._story.chapters[0]
	_main._nav_ctrl.on_chapter_double_clicked(chapter.uuid)
	var scene = chapter.scenes[0]
	_main._nav_ctrl.on_scene_double_clicked(scene.uuid)
	assert_eq(_main._editor_main.get_current_level(), "sequences")
	_main._nav_ctrl.on_breadcrumb_clicked(1)
	assert_eq(_main._editor_main.get_current_level(), "scenes")

func test_on_breadcrumb_clicked_0_already_at_chapters() -> void:
	_main._nav_ctrl.on_new_story_pressed()
	# Already at chapters level → no change
	_main._nav_ctrl.on_breadcrumb_clicked(0)
	assert_eq(_main._editor_main.get_current_level(), "chapters")


# --- Double-click navigation ---

func test_on_scene_double_clicked() -> void:
	_main._nav_ctrl.on_new_story_pressed()
	var chapter = _main._editor_main._story.chapters[0]
	_main._nav_ctrl.on_chapter_double_clicked(chapter.uuid)
	var scene = chapter.scenes[0]
	_main._nav_ctrl.on_scene_double_clicked(scene.uuid)
	assert_eq(_main._editor_main.get_current_level(), "sequences")

func test_on_sequence_double_clicked() -> void:
	_main._nav_ctrl.on_new_story_pressed()
	var chapter = _main._editor_main._story.chapters[0]
	_main._nav_ctrl.on_chapter_double_clicked(chapter.uuid)
	var scene = chapter.scenes[0]
	_main._nav_ctrl.on_scene_double_clicked(scene.uuid)
	var seq = scene.sequences[0]
	_main._nav_ctrl.on_sequence_double_clicked(seq.uuid)
	assert_eq(_main._editor_main.get_current_level(), "sequence_edit")

func test_on_condition_double_clicked() -> void:
	_main._nav_ctrl.on_new_story_pressed()
	var chapter = _main._editor_main._story.chapters[0]
	_main._nav_ctrl.on_chapter_double_clicked(chapter.uuid)
	var scene = chapter.scenes[0]
	_main._nav_ctrl.on_scene_double_clicked(scene.uuid)
	_main._nav_ctrl.on_create_condition_pressed()
	var cond = scene.conditions[0]
	_main._nav_ctrl.on_condition_double_clicked(cond.uuid)
	assert_eq(_main._editor_main.get_current_level(), "condition_edit")


# --- Rename (null-guard tests) ---

func test_on_story_rename_requested_null_story() -> void:
	# No story → returns early
	_main._nav_ctrl.on_story_rename_requested()
	pass_test("on_story_rename_requested with null story should not crash")

func test_on_chapter_rename_requested_invalid_uuid() -> void:
	_main._nav_ctrl.on_new_story_pressed()
	_main._nav_ctrl.on_chapter_rename_requested("invalid-uuid")
	pass_test("on_chapter_rename_requested with invalid uuid should not crash")

func test_on_chapter_rename_requested_opens_dialog() -> void:
	_main._nav_ctrl.on_new_story_pressed()
	var uuid = _main._editor_main._story.chapters[0].uuid
	_main._nav_ctrl.on_chapter_rename_requested(uuid)
	assert_not_null(_main._nav_ctrl._rename_dialog)
	# Hide immediately to release the exclusive window lock
	_main._nav_ctrl._rename_dialog.hide()

func test_on_scene_rename_requested_null_chapter() -> void:
	# No current chapter → returns early
	_main._nav_ctrl.on_scene_rename_requested("some-uuid")
	pass_test("on_scene_rename_requested with null chapter should not crash")

func test_on_scene_rename_requested_invalid_uuid() -> void:
	_main._nav_ctrl.on_new_story_pressed()
	var chapter = _main._editor_main._story.chapters[0]
	_main._nav_ctrl.on_chapter_double_clicked(chapter.uuid)
	_main._nav_ctrl.on_scene_rename_requested("invalid-uuid")
	pass_test("on_scene_rename_requested with invalid uuid should not crash")

func test_on_sequence_rename_requested_null_scene() -> void:
	_main._nav_ctrl.on_sequence_rename_requested("some-uuid")
	pass_test("on_sequence_rename_requested with null scene should not crash")

func test_on_condition_rename_requested_null_scene() -> void:
	_main._nav_ctrl.on_condition_rename_requested("some-uuid")
	pass_test("on_condition_rename_requested with null scene should not crash")


# --- Save / Load (null-story guards) ---

func test_on_save_pressed_null_story() -> void:
	_main._nav_ctrl.on_save_pressed()
	pass_test("on_save_pressed with null story should not crash")

func test_on_save_as_pressed_null_story() -> void:
	_main._nav_ctrl.on_save_as_pressed()
	pass_test("on_save_as_pressed with null story should not crash")


# --- Verify ---

func test_on_verify_pressed_null_story() -> void:
	_main._nav_ctrl.on_verify_pressed()
	pass_test("on_verify_pressed with null story should not crash")

func test_on_verify_pressed_with_story() -> void:
	_main._nav_ctrl.on_new_story_pressed()
	_main._nav_ctrl.on_verify_pressed()
	pass_test("on_verify_pressed with story should not crash")

func test_on_verifier_close() -> void:
	_main._nav_ctrl.on_new_story_pressed()
	_main._nav_ctrl.on_verifier_close()
	pass_test("on_verifier_close should not crash")


# --- Variables ---

func test_on_variables_pressed_null_story() -> void:
	_main._nav_ctrl.on_variables_pressed()
	pass_test("on_variables_pressed with null story should not crash")

func test_on_variables_changed() -> void:
	_main._nav_ctrl.on_variables_changed()
	pass_test("on_variables_changed should not crash")


# --- Menu config ---

func test_on_menu_config_requested_null_story() -> void:
	_main._nav_ctrl.on_menu_config_requested()
	pass_test("on_menu_config_requested with null story should not crash")


# --- Ending / Condition ---

func test_on_ending_changed() -> void:
	_main._nav_ctrl.on_ending_changed()
	pass_test("on_ending_changed should not crash")

func test_on_condition_changed() -> void:
	_main._nav_ctrl.on_condition_changed()
	pass_test("on_condition_changed should not crash")


# --- notify_targets_changed ---

func test_notify_targets_changed_no_story() -> void:
	_main._nav_ctrl.notify_targets_changed()
	pass_test("notify_targets_changed with no story should not crash")

func test_notify_targets_changed_at_sequences_level() -> void:
	_main._nav_ctrl.on_new_story_pressed()
	var chapter = _main._editor_main._story.chapters[0]
	_main._nav_ctrl.on_chapter_double_clicked(chapter.uuid)
	var scene = chapter.scenes[0]
	_main._nav_ctrl.on_scene_double_clicked(scene.uuid)
	_main._nav_ctrl.notify_targets_changed()
	pass_test("notify_targets_changed at sequences level should not crash")


# --- _sync_positions ---

func test_sync_positions_at_chapters_level() -> void:
	_main._nav_ctrl.on_new_story_pressed()
	_main._nav_ctrl._sync_positions()
	pass_test("_sync_positions at chapters level should not crash")

func test_sync_positions_at_scenes_level() -> void:
	_main._nav_ctrl.on_new_story_pressed()
	var chapter = _main._editor_main._story.chapters[0]
	_main._nav_ctrl.on_chapter_double_clicked(chapter.uuid)
	_main._nav_ctrl._sync_positions()
	pass_test("_sync_positions at scenes level should not crash")

func test_sync_positions_at_sequences_level() -> void:
	_main._nav_ctrl.on_new_story_pressed()
	var chapter = _main._editor_main._story.chapters[0]
	_main._nav_ctrl.on_chapter_double_clicked(chapter.uuid)
	var scene = chapter.scenes[0]
	_main._nav_ctrl.on_scene_double_clicked(scene.uuid)
	_main._nav_ctrl._sync_positions()
	pass_test("_sync_positions at sequences level should not crash")


# --- _on_menu_config_confirmed ---

func test_on_menu_config_confirmed_updates_story() -> void:
	_main._nav_ctrl.on_new_story_pressed()
	_main._nav_ctrl._on_menu_config_confirmed(
		"Test Menu Title", "Test Subtitle", "bg.png", "music.mp3",
		"https://patreon.com/x", "https://game.itch.io",
		"Game Over", "Go Sub", "go_bg.png",
		"To Be Continued", "TBC Sub", "tbc_bg.png",
		"The End", "The End Sub", "te_bg.png",
		"icon.png", false, "dark",
		{"playfab_analytics": {"title_id": "playfab123", "enabled": true}}
	)
	assert_eq(_main._editor_main._story.menu_title, "Test Menu Title")
	assert_eq(_main._editor_main._story.menu_subtitle, "Test Subtitle")
	assert_eq(_main._editor_main._story.menu_background, "bg.png")
	assert_eq(_main._editor_main._story.the_end_title, "The End")
	assert_eq(_main._editor_main._story.the_end_subtitle, "The End Sub")
	assert_eq(_main._editor_main._story.the_end_background, "te_bg.png")
	assert_eq(_main._editor_main._story.ui_theme_mode, "dark")
	assert_false(_main._editor_main._story.show_title_banner)


# --- _on_load_dir_selected (invalid path creates error dialog) ---

func test_on_load_dir_selected_invalid_path() -> void:
	_main._nav_ctrl._on_load_dir_selected("/nonexistent/path/that/does/not/exist")
	# Should create an AcceptDialog with error message
	var last_child = _main.get_child(_main.get_child_count() - 1)
	assert_true(last_child is AcceptDialog)
	_free_dialog_immediately(last_child)


func test_on_reload_pressed_without_save_path_shows_error() -> void:
	_main._nav_ctrl.on_new_story_pressed()
	_main._nav_ctrl.on_reload_pressed()
	var last_child = _main.get_child(_main.get_child_count() - 1)
	assert_true(last_child is AcceptDialog)
	_free_dialog_immediately(last_child)


func _free_dialog_immediately(dialog: Node) -> void:
	dialog.hide()
	if dialog.get_parent():
		dialog.get_parent().remove_child(dialog)
	dialog.free()


func test_on_reload_pressed_reloads_current_story_after_confirmation() -> void:
	_main._nav_ctrl.on_new_story_pressed()
	_main._editor_main._story.title = "Titre disque initial"
	StorySaver.save_story(_main._editor_main._story, _test_dir)
	_main._nav_ctrl._on_load_dir_selected(_test_dir)

	var disk_story = StorySaver.load_story(_test_dir)
	disk_story.title = "Titre modifié par outil externe"
	StorySaver.save_story(disk_story, _test_dir)
	_main._editor_main._story.title = "Titre modifié en mémoire"

	_main._nav_ctrl.on_reload_pressed()
	var dialog = _main.get_child(_main.get_child_count() - 1)
	assert_true(dialog is ConfirmationDialog)
	dialog.confirmed.emit()

	assert_eq(_main._editor_main._story.title, "Titre modifié par outil externe")


# --- _on_new_target_requested ---

func test_on_new_target_requested_redirect_sequence() -> void:
	_main._nav_ctrl.on_new_story_pressed()
	var chapter = _main._editor_main._story.chapters[0]
	_main._nav_ctrl.on_chapter_double_clicked(chapter.uuid)
	var scene = chapter.scenes[0]
	_main._nav_ctrl.on_scene_double_clicked(scene.uuid)
	var initial_count = scene.sequences.size()
	var result = {"uuid": ""}
	_main._nav_ctrl._on_new_target_requested("redirect_sequence", func(uuid): result["uuid"] = uuid)
	assert_eq(scene.sequences.size(), initial_count + 1)
	assert_ne(result["uuid"], "")

func test_on_new_target_requested_redirect_scene() -> void:
	_main._nav_ctrl.on_new_story_pressed()
	var chapter = _main._editor_main._story.chapters[0]
	_main._nav_ctrl.on_chapter_double_clicked(chapter.uuid)
	var scene = chapter.scenes[0]
	_main._nav_ctrl.on_scene_double_clicked(scene.uuid)
	var initial_count = chapter.scenes.size()
	var result = {"uuid": ""}
	_main._nav_ctrl._on_new_target_requested("redirect_scene", func(uuid): result["uuid"] = uuid)
	assert_eq(chapter.scenes.size(), initial_count + 1)
	assert_ne(result["uuid"], "")

func test_on_new_target_requested_redirect_chapter() -> void:
	_main._nav_ctrl.on_new_story_pressed()
	var initial_count = _main._editor_main._story.chapters.size()
	var result = {"uuid": ""}
	_main._nav_ctrl._on_new_target_requested("redirect_chapter", func(uuid): result["uuid"] = uuid)
	assert_eq(_main._editor_main._story.chapters.size(), initial_count + 1)
	assert_ne(result["uuid"], "")

func test_on_new_target_requested_redirect_sequence_null_scene() -> void:
	# No current scene → returns early
	_main._nav_ctrl._on_new_target_requested("redirect_sequence", func(_uuid): pass)
	pass_test("redirect_sequence with null scene should not crash")

func test_on_new_target_requested_redirect_scene_null_chapter() -> void:
	# No current chapter → returns early
	_main._nav_ctrl._on_new_target_requested("redirect_scene", func(_uuid): pass)
	pass_test("redirect_scene with null chapter should not crash")

func test_on_new_target_requested_redirect_chapter_null_story() -> void:
	# No story → returns early
	_main._nav_ctrl._on_new_target_requested("redirect_chapter", func(_uuid): pass)
	pass_test("redirect_chapter with null story should not crash")
