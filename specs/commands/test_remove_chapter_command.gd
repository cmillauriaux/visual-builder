extends GutTest

var StoryScript
var ChapterScript
var RemoveChapterCommandScript

func before_each():
	StoryScript = load("res://src/models/story.gd")
	ChapterScript = load("res://src/models/chapter.gd")
	RemoveChapterCommandScript = load("res://src/commands/remove_chapter_command.gd")

func test_execute_removes_chapter():
	var story = StoryScript.new()
	var chapter = ChapterScript.new()
	chapter.chapter_name = "Chapter to remove"
	story.chapters.append(chapter)
	var cmd = RemoveChapterCommandScript.new(story, chapter)
	cmd.execute()
	assert_eq(story.chapters.size(), 0)

func test_undo_restores_chapter():
	var story = StoryScript.new()
	var chapter = ChapterScript.new()
	chapter.chapter_name = "Chapter to remove"
	story.chapters.append(chapter)
	var cmd = RemoveChapterCommandScript.new(story, chapter)
	cmd.execute()
	cmd.undo()
	assert_eq(story.chapters.size(), 1)
	assert_eq(story.chapters[0].chapter_name, "Chapter to remove")
