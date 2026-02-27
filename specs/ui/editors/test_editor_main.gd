extends GutTest

# Tests pour le conteneur principal EditorMain

const EditorMain = preload("res://src/ui/editors/editor_main.gd")
const Story = preload("res://src/models/story.gd")
const Chapter = preload("res://src/models/chapter.gd")
const SceneData = preload("res://src/models/scene_data.gd")
const Sequence = preload("res://src/models/sequence.gd")

var _editor: Control = null

func before_each():
	_editor = Control.new()
	_editor.set_script(EditorMain)
	add_child_autofree(_editor)

func test_initial_state():
	assert_eq(_editor.get_current_level(), "none")

func test_load_story():
	var story = Story.new()
	story.title = "Test"
	story.author = "Auteur"
	_editor.open_story(story)
	assert_eq(_editor.get_current_level(), "chapters")

func test_navigate_to_scenes():
	var story = Story.new()
	story.title = "Test"
	story.author = "Auteur"
	var ch = Chapter.new()
	ch.chapter_name = "Ch1"
	story.chapters.append(ch)
	_editor.open_story(story)
	_editor.navigate_to_chapter(ch.uuid)
	assert_eq(_editor.get_current_level(), "scenes")

func test_navigate_to_sequences():
	var story = Story.new()
	story.title = "Test"
	story.author = "Auteur"
	var ch = Chapter.new()
	ch.chapter_name = "Ch1"
	var scene = SceneData.new()
	scene.scene_name = "S1"
	ch.scenes.append(scene)
	story.chapters.append(ch)
	_editor.open_story(story)
	_editor.navigate_to_chapter(ch.uuid)
	_editor.navigate_to_scene(scene.uuid)
	assert_eq(_editor.get_current_level(), "sequences")

func test_navigate_back_from_scenes():
	var story = Story.new()
	story.title = "Test"
	story.author = "Auteur"
	var ch = Chapter.new()
	ch.chapter_name = "Ch1"
	story.chapters.append(ch)
	_editor.open_story(story)
	_editor.navigate_to_chapter(ch.uuid)
	_editor.navigate_back()
	assert_eq(_editor.get_current_level(), "chapters")

func test_navigate_back_from_sequences():
	var story = Story.new()
	story.title = "Test"
	story.author = "Auteur"
	var ch = Chapter.new()
	ch.chapter_name = "Ch1"
	var scene = SceneData.new()
	scene.scene_name = "S1"
	ch.scenes.append(scene)
	story.chapters.append(ch)
	_editor.open_story(story)
	_editor.navigate_to_chapter(ch.uuid)
	_editor.navigate_to_scene(scene.uuid)
	_editor.navigate_back()
	assert_eq(_editor.get_current_level(), "scenes")

func test_get_breadcrumb_path():
	var story = Story.new()
	story.title = "Mon Histoire"
	story.author = "Auteur"
	var ch = Chapter.new()
	ch.chapter_name = "Chapitre 1"
	var scene = SceneData.new()
	scene.scene_name = "Scène A"
	ch.scenes.append(scene)
	story.chapters.append(ch)
	_editor.open_story(story)
	_editor.navigate_to_chapter(ch.uuid)
	_editor.navigate_to_scene(scene.uuid)
	var path = _editor.get_breadcrumb_path()
	assert_eq(path, ["Mon Histoire", "Chapitre 1", "Scène A"])

func _setup_full_hierarchy() -> Dictionary:
	var story = Story.new()
	story.title = "Mon Histoire"
	story.author = "Auteur"
	var ch = Chapter.new()
	ch.chapter_name = "Chapitre 1"
	var scene = SceneData.new()
	scene.scene_name = "Scène A"
	var seq = Sequence.new()
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

func test_breadcrumb_path_at_sequence_edit():
	var data = _setup_full_hierarchy()
	_editor.navigate_to_sequence(data["sequence"].uuid)
	var path = _editor.get_breadcrumb_path()
	assert_eq(path.size(), 4)
	assert_eq(path, ["Mon Histoire", "Chapitre 1", "Scène A", "Séquence 1"])

func test_touch_updates_updated_at():
	var story = Story.new()
	story.title = "Test"
	story.author = "Auteur"
	_editor.open_story(story)
	var old_updated_at = story.updated_at
	# Attendre un instant pour que le timestamp change
	await get_tree().create_timer(1.1).timeout
	story.touch()
	assert_ne(story.updated_at, old_updated_at, "updated_at doit changer après touch()")
