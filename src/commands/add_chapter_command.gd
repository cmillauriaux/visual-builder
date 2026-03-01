extends "res://src/commands/base_command.gd"

const ChapterScript = preload("res://src/models/chapter.gd")

var _story
var _chapter
var _label: String

func _init(story, chapter_name: String, position: Vector2) -> void:
	_story = story
	_chapter = ChapterScript.new()
	_chapter.chapter_name = chapter_name
	_chapter.position = position
	_label = "Ajout chapitre \"%s\"" % chapter_name

func execute() -> void:
	_story.chapters.append(_chapter)

func undo() -> void:
	_story.chapters.erase(_chapter)

func get_label() -> String:
	return _label
