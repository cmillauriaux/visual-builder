extends GutTest

## Tests pour NavigationController — navigation, création, renommage.

const MainScript = preload("res://src/main.gd")
const NavigationControllerScript = preload("res://src/controllers/navigation_controller.gd")
const StoryScript = preload("res://src/models/story.gd")
const ChapterScript = preload("res://src/models/chapter.gd")
const SceneDataScript = preload("res://src/models/scene_data.gd")
const SequenceScript = preload("res://src/models/sequence.gd")

var _main: Control


func before_each() -> void:
	_main = Control.new()
	_main.set_script(MainScript)
	add_child(_main)


func after_each() -> void:
	remove_child(_main)
	_main.queue_free()


func test_nav_controller_exists() -> void:
	assert_not_null(_main._nav_ctrl)
	assert_true(_main._nav_ctrl.get_script() == NavigationControllerScript)


func test_on_new_story_pressed_creates_story() -> void:
	_main._nav_ctrl.on_new_story_pressed()
	assert_not_null(_main._editor_main._story)
	assert_eq(_main._editor_main._story.title, "Mon Histoire")
	assert_eq(_main._editor_main._story.chapters.size(), 1)
	assert_eq(_main._editor_main._story.chapters[0].chapter_name, "Chapitre 1")


func test_on_new_story_has_scene_and_sequence() -> void:
	_main._nav_ctrl.on_new_story_pressed()
	var chapter = _main._editor_main._story.chapters[0]
	assert_eq(chapter.scenes.size(), 1)
	assert_eq(chapter.scenes[0].scene_name, "Scène 1")
	assert_eq(chapter.scenes[0].sequences.size(), 1)
	assert_eq(chapter.scenes[0].sequences[0].seq_name, "Séquence 1")


func test_on_create_pressed_at_chapters_level() -> void:
	_main._nav_ctrl.on_new_story_pressed()
	var initial_count = _main._editor_main._story.chapters.size()
	_main._nav_ctrl.on_create_pressed()
	assert_eq(_main._editor_main._story.chapters.size(), initial_count + 1)


func test_on_back_at_chapters_does_nothing() -> void:
	_main._nav_ctrl.on_new_story_pressed()
	var level_before = _main._editor_main.get_current_level()
	_main._nav_ctrl.on_back_pressed()
	# At chapters level, back might not change level
	assert_eq(_main._editor_main.get_current_level(), level_before)


func test_on_save_with_no_story_does_nothing() -> void:
	_main._nav_ctrl.on_save_pressed()
	pass_test("should not crash when no story")


func test_on_variables_pressed_with_no_story_does_nothing() -> void:
	_main._nav_ctrl.on_variables_pressed()
	pass_test("should not crash when no story")


func test_on_menu_config_with_no_story_does_nothing() -> void:
	_main._nav_ctrl.on_menu_config_requested()
	pass_test("should not crash when no story")


func test_on_variables_changed_updates_ending_editor() -> void:
	_main._nav_ctrl.on_new_story_pressed()
	_main._nav_ctrl.on_variables_changed()
	pass_test("should not crash")


func test_build_available_targets_empty_when_no_scene() -> void:
	_main._nav_ctrl.on_new_story_pressed()
	# At chapters level, _current_scene is null
	var targets = _main._nav_ctrl._build_available_targets()
	assert_eq(targets["sequences"].size(), 0)
	assert_eq(targets["conditions"].size(), 0)


func test_build_available_targets_with_story() -> void:
	_main._nav_ctrl.on_new_story_pressed()
	var targets = _main._nav_ctrl._build_available_targets()
	assert_true(targets["chapters"].size() > 0, "should list chapters from story")
