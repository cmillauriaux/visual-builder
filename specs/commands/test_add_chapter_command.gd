extends GutTest

var StoryScript
var AddChapterCommandScript

func before_each():
	StoryScript = load("res://src/models/story.gd")
	AddChapterCommandScript = load("res://src/commands/add_chapter_command.gd")

func test_execute_adds_chapter_to_story():
	var story = StoryScript.new()
	var cmd = AddChapterCommandScript.new(story, "Nouveau Chapitre", Vector2(100, 100))
	cmd.execute()
	assert_eq(story.chapters.size(), 1)
	assert_eq(story.chapters[0].chapter_name, "Nouveau Chapitre")

func test_undo_removes_chapter():
	var story = StoryScript.new()
	var cmd = AddChapterCommandScript.new(story, "Nouveau Chapitre", Vector2(100, 100))
	cmd.execute()
	cmd.undo()
	assert_eq(story.chapters.size(), 0)

func test_get_label():
	var story = StoryScript.new()
	var cmd = AddChapterCommandScript.new(story, "Mon Chapitre", Vector2.ZERO)
	assert_string_contains(cmd.get_label(), "Mon Chapitre")
