extends GutTest

## Test d'intégration pour la fonctionnalité de variables dans main.gd

const MainScene = preload("res://src/main.gd")
const StoryScript = preload("res://src/models/story.gd")
const ChapterScript = preload("res://src/models/chapter.gd")
const SceneDataScript = preload("res://src/models/scene_data.gd")
const SequenceScript = preload("res://src/models/sequence.gd")
const VariableDefinitionScript = preload("res://src/models/variable_definition.gd")

var _main: Control

func before_each():
	_main = Control.new()
	_main.set_script(MainScene)
	add_child(_main)

func after_each():
	_main.queue_free()


# --- Intégration variable names → ending editor ---

func test_variable_names_passed_to_ending_editor():
	var story = _make_story()
	var v = VariableDefinitionScript.new()
	v.var_name = "score"
	v.initial_value = "0"
	story.variables.append(v)
	_main._editor_main.open_story(story)
	_main._editor_main.navigate_to_chapter(story.chapters[0].uuid)
	_main._editor_main.navigate_to_scene(story.chapters[0].scenes[0].uuid)
	var seq = story.chapters[0].scenes[0].sequences[0]
	_main._editor_main.navigate_to_sequence(seq.uuid)
	_main.load_sequence_editors(seq)
	assert_has(_main._ending_editor.get_variable_names(), "score")

# --- Intégration variable names → condition editor ---

func test_variable_names_passed_to_condition_editor():
	var story = _make_story()
	var v = VariableDefinitionScript.new()
	v.var_name = "hp"
	v.initial_value = "100"
	story.variables.append(v)
	_main._editor_main.open_story(story)
	_main._editor_main.navigate_to_chapter(story.chapters[0].uuid)
	_main._editor_main.navigate_to_scene(story.chapters[0].scenes[0].uuid)
	# Ajouter une condition pour tester
	var cond = preload("res://src/models/condition.gd").new()
	cond.condition_name = "Test"
	story.chapters[0].scenes[0].conditions.append(cond)
	_main._editor_main.navigate_to_condition(cond.uuid)
	_main._nav_ctrl.load_condition_editor(cond)
	assert_has(_main._condition_editor.get_variable_names(), "hp")

# --- Helper ---

func _make_story():
	var story = StoryScript.new()
	story.title = "Test"
	var chapter = ChapterScript.new()
	chapter.chapter_name = "Ch1"
	var scene = SceneDataScript.new()
	scene.scene_name = "Sc1"
	var seq = SequenceScript.new()
	seq.seq_name = "Seq1"
	scene.sequences.append(seq)
	scene.entry_point_uuid = seq.uuid
	chapter.scenes.append(scene)
	chapter.entry_point_uuid = scene.uuid
	story.chapters.append(chapter)
	story.entry_point_uuid = chapter.uuid
	return story
