extends GutTest

const StoryScript = preload("res://src/models/story.gd")
const ChapterScript = preload("res://src/models/chapter.gd")
const RemoveChapterCommand = preload("res://src/commands/remove_chapter_command.gd")


func test_execute_removes_chapter():
	var story = StoryScript.new()
	var ch = ChapterScript.new()
	ch.chapter_name = "Chapitre 1"
	story.chapters = [ch]
	var cmd = RemoveChapterCommand.new(story, ch)
	cmd.execute()
	assert_eq(story.chapters.size(), 0)


func test_undo_restores_chapter_at_correct_index():
	var story = StoryScript.new()
	var ch1 = ChapterScript.new()
	ch1.chapter_name = "A"
	var ch2 = ChapterScript.new()
	ch2.chapter_name = "B"
	story.chapters = [ch1, ch2]
	var cmd = RemoveChapterCommand.new(story, ch1)
	cmd.execute()
	cmd.undo()
	assert_eq(story.chapters.size(), 2)
	assert_eq(story.chapters[0].chapter_name, "A")


func test_get_label():
	var story = StoryScript.new()
	var ch = ChapterScript.new()
	ch.chapter_name = "Mon Chapitre"
	story.chapters = [ch]
	var cmd = RemoveChapterCommand.new(story, ch)
	assert_string_contains(cmd.get_label(), "Mon Chapitre")
