extends GutTest

const EditorStateScript = preload("res://src/controllers/editor_state.gd")


func test_mode_none_exists():
	assert_eq(EditorStateScript.Mode.NONE, 0)


func test_mode_chapter_view_exists():
	assert_eq(EditorStateScript.Mode.CHAPTER_VIEW, 1)


func test_mode_scene_view_exists():
	assert_eq(EditorStateScript.Mode.SCENE_VIEW, 2)


func test_mode_sequence_view_exists():
	assert_eq(EditorStateScript.Mode.SEQUENCE_VIEW, 3)


func test_mode_sequence_edit_exists():
	assert_eq(EditorStateScript.Mode.SEQUENCE_EDIT, 4)


func test_mode_condition_edit_exists():
	assert_eq(EditorStateScript.Mode.CONDITION_EDIT, 5)


func test_mode_play_mode_exists():
	assert_eq(EditorStateScript.Mode.PLAY_MODE, 6)


func test_all_modes_are_distinct():
	var values = [
		EditorStateScript.Mode.NONE,
		EditorStateScript.Mode.CHAPTER_VIEW,
		EditorStateScript.Mode.SCENE_VIEW,
		EditorStateScript.Mode.SEQUENCE_VIEW,
		EditorStateScript.Mode.SEQUENCE_EDIT,
		EditorStateScript.Mode.CONDITION_EDIT,
		EditorStateScript.Mode.PLAY_MODE,
	]
	# Check uniqueness
	for i in range(values.size()):
		for j in range(i + 1, values.size()):
			assert_ne(values[i], values[j])
