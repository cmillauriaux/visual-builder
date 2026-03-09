extends GutTest

var ChapterScript
var AddSceneCommandScript

func before_each():
	ChapterScript = load("res://src/models/chapter.gd")
	AddSceneCommandScript = load("res://src/commands/add_scene_command.gd")

func test_execute_adds_scene_to_chapter():
	var chapter = ChapterScript.new()
	var cmd = AddSceneCommandScript.new(chapter, "Nouvelle Scène", Vector2(50, 50))
	cmd.execute()
	assert_eq(chapter.scenes.size(), 1)
	assert_eq(chapter.scenes[0].scene_name, "Nouvelle Scène")

func test_undo_removes_scene():
	var chapter = ChapterScript.new()
	var cmd = AddSceneCommandScript.new(chapter, "Nouvelle Scène", Vector2(50, 50))
	cmd.execute()
	cmd.undo()
	assert_eq(chapter.scenes.size(), 0)

func test_get_label():
	var chapter = ChapterScript.new()
	var cmd = AddSceneCommandScript.new(chapter, "Ma Scène", Vector2.ZERO)
	assert_string_contains(cmd.get_label(), "Ma Scène")
