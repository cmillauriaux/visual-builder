# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends RefCounted

## Helper partagé pour la gestion des cibles de conséquences (endings, conditions).

const ConsequenceScript = preload("res://src/models/consequence.gd")

const CONSEQUENCE_TYPES = ConsequenceScript.VALID_TYPES
const CONSEQUENCE_LABELS = ["Séquence", "Condition", "Scène", "Chapitre", "Game Over", "To be continued", "The End"]
const REDIRECT_TYPES = ConsequenceScript.REDIRECT_TYPES

const NEW_TARGET_META = "__new__"
const NEW_LABEL_MAP = {
	"redirect_sequence": "✚ Nouvelle séquence...",
	"redirect_scene": "✚ Nouvelle scène...",
	"redirect_chapter": "✚ Nouveau chapitre...",
}

var available_sequences: Array = []   # [{uuid, name}]
var available_conditions: Array = []  # [{uuid, name}]
var available_scenes: Array = []      # [{uuid, name}]
var available_chapters: Array = []    # [{uuid, name}]
var variable_names: Array = []        # [String]

func set_available_targets(sequences: Array, scenes: Array, chapters: Array, conditions: Array = []) -> void:
	available_sequences = sequences
	available_conditions = conditions
	available_scenes = scenes
	available_chapters = chapters

func get_targets_for_type(ctype: String) -> Array:
	match ctype:
		"redirect_sequence":
			return available_sequences
		"redirect_condition":
			return available_conditions
		"redirect_scene":
			return available_scenes
		"redirect_chapter":
			return available_chapters
	return []

func populate_target_dropdown(dropdown: OptionButton, ctype: String) -> void:
	dropdown.clear()
	if ctype in NEW_LABEL_MAP:
		dropdown.add_item(NEW_LABEL_MAP[ctype])
		dropdown.set_item_metadata(0, NEW_TARGET_META)
	var items = get_targets_for_type(ctype)
	for item in items:
		dropdown.add_item(item["name"])
		dropdown.set_item_metadata(dropdown.item_count - 1, item["uuid"])

static func is_new_target_meta(meta) -> bool:
	return meta == NEW_TARGET_META