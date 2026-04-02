# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends "res://src/commands/base_command.gd"

var _story
var _chapter
var _index: int
var _label: String

func _init(story, chapter) -> void:
	_story = story
	_chapter = chapter
	_index = story.chapters.find(chapter)
	_label = "Suppression chapitre \"%s\"" % chapter.chapter_name

func execute() -> void:
	_story.chapters.erase(_chapter)

func undo() -> void:
	_story.chapters.insert(_index, _chapter)

func get_label() -> String:
	return _label