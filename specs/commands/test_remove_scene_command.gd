extends GutTest

var ChapterScript
var SceneDataScript
var RemoveSceneCommandScript

func before_each():
	ChapterScript = load("res://src/models/chapter.gd")
	SceneDataScript = load("res://src/models/scene_data.gd")
	RemoveSceneCommandScript = load("res://src/commands/remove_scene_command.gd")

func test_execute_removes_scene():
	var chapter = ChapterScript.new()
	var scene = SceneDataScript.new()
	chapter.scenes.append(scene)
	var cmd = RemoveSceneCommandScript.new(chapter, scene)
	cmd.execute()
	assert_eq(chapter.scenes.size(), 0)

func test_undo_restores_scene():
	var chapter = ChapterScript.new()
	var scene = SceneDataScript.new()
	chapter.scenes.append(scene)
	var cmd = RemoveSceneCommandScript.new(chapter, scene)
	cmd.execute()
	cmd.undo()
	assert_eq(chapter.scenes.size(), 1)
