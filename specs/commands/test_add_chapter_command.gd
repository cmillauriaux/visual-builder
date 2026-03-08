extends GutTest

const StoryScript = preload("res://src/models/story.gd")
const AddChapterCommand = preload("res://src/commands/add_chapter_command.gd")


func test_execute_adds_chapter_to_story():
	var story = StoryScript.new()
	var cmd = AddChapterCommand.new(story, "Chapitre 1", Vector2(100, 200))
	cmd.execute()
	assert_eq(story.chapters.size(), 1)
	assert_eq(story.chapters[0].chapter_name, "Chapitre 1")
	assert_eq(story.chapters[0].position, Vector2(100, 200))


func test_undo_removes_chapter():
	var story = StoryScript.new()
	var cmd = AddChapterCommand.new(story, "Chapitre 1", Vector2.ZERO)
	cmd.execute()
	cmd.undo()
	assert_eq(story.chapters.size(), 0)


func test_get_label():
	var story = StoryScript.new()
	var cmd = AddChapterCommand.new(story, "Mon Chapitre", Vector2.ZERO)
	assert_string_contains(cmd.get_label(), "Mon Chapitre")
