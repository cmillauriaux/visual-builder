extends GutTest

# Tests pour le conteneur principal EditorMain

var EditorMainScript
var StoryScript
var ChapterScript
var SceneDataScript
var SequenceScript

var _editor: Control = null

func before_each():
	EditorMainScript = load("res://src/ui/editors/editor_main.gd")
	StoryScript = load("res://src/models/story.gd")
	ChapterScript = load("res://src/models/chapter.gd")
	SceneDataScript = load("res://src/models/scene_data.gd")
	SequenceScript = load("res://src/models/sequence.gd")
	
	_editor = Control.new()
	_editor.set_script(EditorMainScript)
	add_child_autofree(_editor)

func test_initial_state():
	assert_eq(_editor.get_current_level(), "none")

func test_load_story():
	var story = StoryScript.new()
	story.title = "Test"
	story.author = "Auteur"
	_editor.open_story(story)
	assert_eq(_editor.get_current_level(), "chapters")

func test_navigate_to_scenes():
	var story = StoryScript.new()
	story.title = "Test"
	story.author = "Auteur"
	var ch = ChapterScript.new()
	ch.chapter_name = "Ch1"
	story.chapters.append(ch)
	_editor.open_story(story)
	_editor.navigate_to_chapter(ch.uuid)
	assert_eq(_editor.get_current_level(), "scenes")

func test_navigate_to_sequences():
	var story = StoryScript.new()
	story.title = "Test"
	story.author = "Auteur"
	var ch = ChapterScript.new()
	ch.chapter_name = "Ch1"
	var scene = SceneDataScript.new()
	scene.scene_name = "S1"
	ch.scenes.append(scene)
	story.chapters.append(ch)
	_editor.open_story(story)
	_editor.navigate_to_chapter(ch.uuid)
	_editor.navigate_to_scene(scene.uuid)
	assert_eq(_editor.get_current_level(), "sequences")

func test_navigate_back_from_scenes():
	var story = StoryScript.new()
	story.title = "Test"
	story.author = "Auteur"
	var ch = ChapterScript.new()
	ch.chapter_name = "Ch1"
	story.chapters.append(ch)
	_editor.open_story(story)
	_editor.navigate_to_chapter(ch.uuid)
	_editor.navigate_back()
	assert_eq(_editor.get_current_level(), "chapters")

func test_navigate_back_from_sequences():
	var story = StoryScript.new()
	story.title = "Test"
	story.author = "Auteur"
	var ch = ChapterScript.new()
	ch.chapter_name = "Ch1"
	var scene = SceneDataScript.new()
	scene.scene_name = "S1"
	ch.scenes.append(scene)
	story.chapters.append(ch)
	_editor.open_story(story)
	_editor.navigate_to_chapter(ch.uuid)
	_editor.navigate_to_scene(scene.uuid)
	_editor.navigate_back()
	assert_eq(_editor.get_current_level(), "scenes")

func test_get_breadcrumb_path():
	var story = StoryScript.new()
	story.title = "Mon Histoire"
	story.author = "Auteur"
	var ch = ChapterScript.new()
	ch.chapter_name = "Chapitre 1"
	var scene = SceneDataScript.new()
	scene.scene_name = "Scène A"
	ch.scenes.append(scene)
	story.chapters.append(ch)
	_editor.open_story(story)
	_editor.navigate_to_chapter(ch.uuid)
	_editor.navigate_to_scene(scene.uuid)
	var path = _editor.get_breadcrumb_path()
	assert_eq(path, ["Mon Histoire", "Chapitre 1", "Scène A"])

func _setup_full_hierarchy() -> Dictionary:
	var story = StoryScript.new()
	story.title = "Mon Histoire"
	story.author = "Auteur"
	var ch = ChapterScript.new()
	ch.chapter_name = "Chapitre 1"
	var scene = SceneDataScript.new()
	scene.scene_name = "Scène A"
	var seq = SequenceScript.new()
	seq.seq_name = "Séquence 1"
	scene.sequences.append(seq)
	ch.scenes.append(scene)
	story.chapters.append(ch)
	_editor.open_story(story)
	_editor.navigate_to_chapter(ch.uuid)
	_editor.navigate_to_scene(scene.uuid)
	return {"story": story, "chapter": ch, "scene": scene, "sequence": seq}

func test_navigate_to_sequence():
	var data = _setup_full_hierarchy()
	_editor.navigate_to_sequence(data["sequence"].uuid)
	assert_eq(_editor.get_current_level(), "sequence_edit")
	assert_not_null(_editor._current_sequence)
	assert_eq(_editor._current_sequence.seq_name, "Séquence 1")

func test_navigate_back_from_sequence_edit():
	var data = _setup_full_hierarchy()
	_editor.navigate_to_sequence(data["sequence"].uuid)
	_editor.navigate_back()
	assert_eq(_editor.get_current_level(), "sequences")
	assert_null(_editor._current_sequence)

func test_touch_updates_updated_at():
	var story = StoryScript.new()
	story.updated_at = "2000-01-01T00:00:00Z"
	_editor.open_story(story)
	story.touch()
	assert_ne(story.updated_at, "2000-01-01T00:00:00Z", "updated_at doit changer après touch()")

# --- Guard clause tests ---

func test_navigate_to_chapter_without_story():
	_editor.navigate_to_chapter("fake-uuid")
	assert_eq(_editor.get_current_level(), "none", "Level stays none when story is null")
	assert_null(_editor._current_chapter)

func test_navigate_to_scene_without_chapter():
	var story = StoryScript.new()
	_editor.open_story(story)
	_editor.navigate_to_scene("fake-uuid")
	assert_eq(_editor.get_current_level(), "chapters", "Level stays chapters when chapter is null")
	assert_null(_editor._current_scene)

func test_navigate_to_sequence_without_scene():
	var story = StoryScript.new()
	_editor.open_story(story)
	_editor.navigate_to_sequence("fake-uuid")
	assert_eq(_editor.get_current_level(), "chapters", "Level stays chapters when scene is null")
	assert_null(_editor._current_sequence)

# --- Condition navigation ---

func test_navigate_to_condition():
	var ConditionScript = load("res://src/models/condition.gd")
	var data = _setup_full_hierarchy()
	var cond = ConditionScript.new()
	cond.condition_name = "Condition 1"
	data["scene"].conditions.append(cond)
	_editor.navigate_to_condition(cond.uuid)
	assert_eq(_editor.get_current_level(), "condition_edit")
	assert_eq(_editor._current_condition.condition_name, "Condition 1")
	assert_null(_editor._current_sequence, "Sequence is cleared when navigating to condition")

func test_navigate_back_from_condition_edit():
	var ConditionScript = load("res://src/models/condition.gd")
	var data = _setup_full_hierarchy()
	var cond = ConditionScript.new()
	cond.condition_name = "Condition 1"
	data["scene"].conditions.append(cond)
	_editor.navigate_to_condition(cond.uuid)
	_editor.navigate_back()
	assert_eq(_editor.get_current_level(), "sequences")
	assert_null(_editor._current_condition)

# --- Map navigation ---

func test_navigate_to_map_and_back():
	var data = _setup_full_hierarchy()
	_editor.navigate_to_map()
	assert_eq(_editor.get_current_level(), "map")
	_editor.navigate_back()
	assert_eq(_editor.get_current_level(), "sequences", "Back from map restores previous level")
	assert_eq(_editor._current_chapter.chapter_name, "Chapitre 1", "Back from map restores chapter")
	assert_eq(_editor._current_scene.scene_name, "Scène A", "Back from map restores scene")

# --- Utility functions ---

func test_get_create_button_label():
	var story = StoryScript.new()
	story.title = "Test"
	_editor.open_story(story)
	assert_eq(_editor.get_create_button_label(), "+ Nouveau chapitre")
	assert_true(_editor.is_create_button_visible())

	var ch = ChapterScript.new()
	ch.chapter_name = "Ch1"
	story.chapters.append(ch)
	_editor.navigate_to_chapter(ch.uuid)
	assert_eq(_editor.get_create_button_label(), "+ Nouvelle scène")
	assert_true(_editor.is_create_button_visible())

	var scene = SceneDataScript.new()
	scene.scene_name = "S1"
	ch.scenes.append(scene)
	_editor.navigate_to_scene(scene.uuid)
	assert_eq(_editor.get_create_button_label(), "+ Nouvelle séquence")
	assert_true(_editor.is_create_button_visible())

func test_compute_next_position():
	assert_eq(_editor.compute_next_position([]), Vector2(100, 100), "Empty array returns default position")
	var items = [
		{"position": Vector2(100, 50)},
		{"position": Vector2(400, 200)},
		{"position": Vector2(250, 100)},
	]
	assert_eq(_editor.compute_next_position(items), Vector2(700, 100), "Returns max_x + 300")
