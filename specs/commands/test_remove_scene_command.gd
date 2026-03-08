extends GutTest

const ChapterScript = preload("res://src/models/chapter.gd")
const SceneDataScript = preload("res://src/models/scene_data.gd")
const RemoveSceneCommand = preload("res://src/commands/remove_scene_command.gd")


func test_execute_removes_scene():
	var chapter = ChapterScript.new()
	var scene = SceneDataScript.new()
	scene.scene_name = "Scène 1"
	chapter.scenes = [scene]
	var cmd = RemoveSceneCommand.new(chapter, scene)
	cmd.execute()
	assert_eq(chapter.scenes.size(), 0)


func test_undo_restores_scene_at_correct_index():
	var chapter = ChapterScript.new()
	var s1 = SceneDataScript.new()
	s1.scene_name = "A"
	var s2 = SceneDataScript.new()
	s2.scene_name = "B"
	chapter.scenes = [s1, s2]
	var cmd = RemoveSceneCommand.new(chapter, s1)
	cmd.execute()
	cmd.undo()
	assert_eq(chapter.scenes.size(), 2)
	assert_eq(chapter.scenes[0].scene_name, "A")


func test_get_label():
	var chapter = ChapterScript.new()
	var scene = SceneDataScript.new()
	scene.scene_name = "Ma Scène"
	chapter.scenes = [scene]
	var cmd = RemoveSceneCommand.new(chapter, scene)
	assert_string_contains(cmd.get_label(), "Ma Scène")
