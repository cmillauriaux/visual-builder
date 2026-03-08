extends GutTest

const ChapterScript = preload("res://src/models/chapter.gd")
const AddSceneCommand = preload("res://src/commands/add_scene_command.gd")


func test_execute_adds_scene_to_chapter():
	var chapter = ChapterScript.new()
	var cmd = AddSceneCommand.new(chapter, "Scène 1", Vector2(10, 20))
	cmd.execute()
	assert_eq(chapter.scenes.size(), 1)
	assert_eq(chapter.scenes[0].scene_name, "Scène 1")
	assert_eq(chapter.scenes[0].position, Vector2(10, 20))


func test_undo_removes_scene():
	var chapter = ChapterScript.new()
	var cmd = AddSceneCommand.new(chapter, "Scène 1", Vector2.ZERO)
	cmd.execute()
	cmd.undo()
	assert_eq(chapter.scenes.size(), 0)


func test_get_label():
	var chapter = ChapterScript.new()
	var cmd = AddSceneCommand.new(chapter, "Ma Scène", Vector2.ZERO)
	assert_string_contains(cmd.get_label(), "Ma Scène")
