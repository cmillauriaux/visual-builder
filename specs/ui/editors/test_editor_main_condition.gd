extends GutTest

const EditorMainScript = preload("res://src/ui/editors/editor_main.gd")
const StoryScript = preload("res://src/models/story.gd")
const ChapterScript = preload("res://src/models/chapter.gd")
const SceneDataScript = preload("res://src/models/scene_data.gd")
const SequenceScript = preload("res://src/models/sequence.gd")
const ConditionScript = preload("res://src/models/condition.gd")

var _editor: Control
var _story: Object
var _chapter: Object
var _scene: Object
var _sequence: Object
var _condition: Object

func before_each():
	_editor = Control.new()
	_editor.set_script(EditorMainScript)
	add_child_autofree(_editor)

	_story = StoryScript.new()
	_story.title = "Test Story"

	_chapter = ChapterScript.new()
	_chapter.chapter_name = "Ch1"
	_story.chapters.append(_chapter)

	_scene = SceneDataScript.new()
	_scene.scene_name = "Sc1"
	_chapter.scenes.append(_scene)

	_sequence = SequenceScript.new()
	_sequence.seq_name = "Seq1"
	_scene.sequences.append(_sequence)

	_condition = ConditionScript.new()
	_condition.condition_name = "Cond1"
	_scene.conditions.append(_condition)

	_editor.open_story(_story)
	_editor.navigate_to_chapter(_chapter.uuid)
	_editor.navigate_to_scene(_scene.uuid)

func test_navigate_to_condition():
	_editor.navigate_to_condition(_condition.uuid)
	assert_eq(_editor.get_current_level(), "condition_edit")

func test_navigate_to_condition_sets_current_condition():
	_editor.navigate_to_condition(_condition.uuid)
	assert_not_null(_editor._current_condition)
	assert_eq(_editor._current_condition.condition_name, "Cond1")

func test_navigate_to_condition_invalid_uuid():
	_editor.navigate_to_condition("invalid-uuid")
	assert_eq(_editor.get_current_level(), "sequences")
	assert_null(_editor._current_condition)

func test_navigate_to_condition_requires_scene():
	var editor2 = Control.new()
	editor2.set_script(EditorMainScript)
	add_child_autofree(editor2)
	editor2.navigate_to_condition(_condition.uuid)
	assert_eq(editor2.get_current_level(), "none")

func test_navigate_back_from_condition_edit():
	_editor.navigate_to_condition(_condition.uuid)
	_editor.navigate_back()
	assert_eq(_editor.get_current_level(), "sequences")
	assert_null(_editor._current_condition)

func test_breadcrumb_includes_condition():
	_editor.navigate_to_condition(_condition.uuid)
	var path = _editor.get_breadcrumb_path()
	assert_eq(path.size(), 4)
	assert_eq(path[3], "Cond1")

func test_create_button_not_visible_in_condition_edit():
	_editor.navigate_to_condition(_condition.uuid)
	assert_false(_editor.is_create_button_visible())

func test_get_next_condition_name():
	assert_eq(_editor.get_next_condition_name(), "Condition 2")

func test_get_next_condition_name_empty():
	_scene.conditions.clear()
	assert_eq(_editor.get_next_condition_name(), "Condition 1")
