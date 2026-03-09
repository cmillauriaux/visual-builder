extends GutTest

## Tests pour NavigationController — navigation, création, renommage.

var MainScript
var NavigationControllerScript
var StoryScript
var ChapterScript
var SceneDataScript
var SequenceScript

var _main


func before_each() -> void:
	MainScript = load("res://src/main.gd")
	NavigationControllerScript = load("res://src/controllers/navigation_controller.gd")
	StoryScript = load("res://src/models/story.gd")
	ChapterScript = load("res://src/models/chapter.gd")
	SceneDataScript = load("res://src/models/scene_data.gd")
	SequenceScript = load("res://src/models/sequence.gd")
	
	_main = Control.new()
	_main.set_script(MainScript)
	add_child(_main)


func after_each() -> void:
	if _main:
		_main.queue_free()
		_main = null


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
