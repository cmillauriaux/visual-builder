# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends Control

## Conteneur principal de l'éditeur avec navigation hiérarchique.

const ChapterScript = preload("res://src/models/chapter.gd")
const SceneDataScript = preload("res://src/models/scene_data.gd")

var _story = null
var _current_level: String = "none"
var _current_chapter = null
var _current_scene = null
var _current_sequence = null
var _current_condition = null

# Contexte sauvegardé avant ouverture de la map
var _pre_map_level: String = "chapters"
var _pre_map_chapter = null
var _pre_map_scene = null

func get_current_level() -> String:
	return _current_level

func open_story(story) -> void:
	_story = story
	_current_level = "chapters"
	_current_chapter = null
	_current_scene = null
	_current_sequence = null
	_current_condition = null
	EventBus.story_loaded.emit(_story)

func navigate_to_chapter(chapter_uuid: String) -> void:
	if _story == null:
		return
	_current_chapter = _story.find_chapter(chapter_uuid)
	if _current_chapter:
		_current_level = "scenes"
		_current_scene = null
		_current_sequence = null
		_current_condition = null

func navigate_to_scene(scene_uuid: String) -> void:
	if _current_chapter == null:
		return
	_current_scene = _current_chapter.find_scene(scene_uuid)
	if _current_scene:
		_current_level = "sequences"
		_current_sequence = null
		_current_condition = null

func navigate_to_sequence(sequence_uuid: String) -> void:
	if _current_scene == null:
		return
	var seq = _current_scene.find_sequence(sequence_uuid)
	if seq:
		_current_level = "sequence_edit"
		_current_sequence = seq
		_current_condition = null

func navigate_to_condition(condition_uuid: String) -> void:
	if _current_scene == null:
		return
	var cond = _current_scene.find_condition(condition_uuid)
	if cond:
		_current_level = "condition_edit"
		_current_condition = cond
		_current_sequence = null

func navigate_to_map() -> void:
	_pre_map_level = _current_level
	_pre_map_chapter = _current_chapter
	_pre_map_scene = _current_scene
	_current_level = "map"


## Navigation directe depuis la map vers une séquence ou condition spécifique.
func navigate_from_map(chapter_uuid: String, scene_uuid: String, item_uuid: String, is_condition: bool) -> void:
	_current_chapter = _story.find_chapter(chapter_uuid)
	if _current_chapter == null:
		return
	_current_scene = _current_chapter.find_scene(scene_uuid)
	if _current_scene == null:
		return
	if is_condition:
		var cond = _current_scene.find_condition(item_uuid)
		if cond:
			_current_condition = cond
			_current_sequence = null
			_current_level = "condition_edit"
	else:
		var seq = _current_scene.find_sequence(item_uuid)
		if seq:
			_current_sequence = seq
			_current_condition = null
			_current_level = "sequence_edit"


func navigate_back() -> void:
	if _current_level == "map":
		_current_level = _pre_map_level
		_current_chapter = _pre_map_chapter
		_current_scene = _pre_map_scene
		return
	if _current_level == "condition_edit":
		_current_level = "sequences"
		_current_condition = null
	elif _current_level == "sequence_edit":
		_current_level = "sequences"
		_current_sequence = null
	elif _current_level == "sequences":
		_current_level = "scenes"
		_current_scene = null
	elif _current_level == "scenes":
		_current_level = "chapters"
		_current_chapter = null

func get_breadcrumb_path() -> Array:
	var path := []
	if _story:
		path.append(_story.title)
	if _current_chapter:
		path.append(_current_chapter.chapter_name)
	if _current_scene:
		path.append(_current_scene.scene_name)
	if _current_sequence:
		path.append(_current_sequence.seq_name)
	if _current_condition:
		path.append(_current_condition.condition_name)
	return path

func get_create_button_label() -> String:
	match _current_level:
		"chapters":
			return "+ Nouveau chapitre"
		"scenes":
			return "+ Nouvelle scène"
		"sequences":
			return "+ Nouvelle séquence"
	return ""

func is_create_button_visible() -> bool:
	return _current_level in ["chapters", "scenes", "sequences"]

func compute_next_position(items: Array) -> Vector2:
	if items.is_empty():
		return Vector2(100, 100)
	var max_x := -INF
	for item in items:
		if item.position.x > max_x:
			max_x = item.position.x
	return Vector2(max_x + 300, 100)

func get_next_item_name() -> String:
	match _current_level:
		"chapters":
			return "Chapitre %d" % (_story.chapters.size() + 1)
		"scenes":
			return "Scène %d" % (_current_chapter.scenes.size() + 1)
		"sequences":
			return "Séquence %d" % (_current_scene.sequences.size() + 1)
	return ""

func get_next_condition_name() -> String:
	if _current_scene == null:
		return "Condition 1"
	return "Condition %d" % (_current_scene.conditions.size() + 1)