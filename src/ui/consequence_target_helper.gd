extends RefCounted

## Helper partagé pour la gestion des cibles de conséquences (endings, conditions).

const ConsequenceScript = preload("res://src/models/consequence.gd")

const CONSEQUENCE_TYPES = ConsequenceScript.VALID_TYPES
const CONSEQUENCE_LABELS = ["Séquence", "Condition", "Scène", "Chapitre", "Game Over", "To be continued"]
const REDIRECT_TYPES = ConsequenceScript.REDIRECT_TYPES

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
	var items = get_targets_for_type(ctype)
	for item in items:
		dropdown.add_item(item["name"])
		dropdown.set_item_metadata(dropdown.item_count - 1, item["uuid"])
