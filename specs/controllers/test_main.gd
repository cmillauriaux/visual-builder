extends GutTest

## Tests pour main.gd — scène principale de l'éditeur.

const MainScript = preload("res://src/main.gd")

var _main: Control


func before_each() -> void:
	_main = Control.new()
	_main.set_script(MainScript)
	add_child(_main)


func after_each() -> void:
	remove_child(_main)
	_main.queue_free()


func test_initializes_without_errors() -> void:
	assert_not_null(_main)


func test_has_editor_main() -> void:
	assert_not_null(_main._editor_main)


func test_has_sequence_editor_ctrl() -> void:
	assert_not_null(_main._sequence_editor_ctrl)


func test_has_play_controller() -> void:
	assert_not_null(_main._play_ctrl)


func test_has_nav_controller() -> void:
	assert_not_null(_main._nav_ctrl)


func test_update_view_at_chapters_level() -> void:
	_main._nav_ctrl.on_new_story_pressed()
	_main.update_view()
	assert_true(_main._chapter_graph_view.visible)
	assert_false(_main._scene_graph_view.visible)
	assert_false(_main._sequence_graph_view.visible)
	assert_false(_main._sequence_editor_panel.visible)
	assert_false(_main._condition_editor_panel.visible)


func test_get_story_base_path_returns_empty_when_no_save() -> void:
	assert_eq(_main._get_story_base_path(), "")


func test_get_story_base_path_returns_save_path() -> void:
	_main._nav_ctrl.on_new_story_pressed()
	_main._nav_ctrl._last_save_path = "/tmp/my_story"
	assert_eq(_main._get_story_base_path(), "/tmp/my_story")


func test_extract_export_error_no_file() -> void:
	var result = _main._export_service.extract_export_error("res://nonexistent_log_12345.txt")
	assert_eq(result, "L'export a échoué (log introuvable).")


func test_load_sequence_editors_does_not_crash() -> void:
	_main._nav_ctrl.on_new_story_pressed()
	var seq = _main._editor_main._story.chapters[0].scenes[0].sequences[0]
	_main.load_sequence_editors(seq)
	pass_test("should not crash")


func test_refresh_current_view_at_chapters() -> void:
	_main._nav_ctrl.on_new_story_pressed()
	_main.refresh_current_view()
	assert_true(_main._chapter_graph_view.visible)
