extends RefCounted

## Gère les sauvegardes de progression en jeu.
## Stocke les données dans user://saves/slot_N/ (save.json + screenshot.png).
## Toutes les méthodes sont statiques.

const SAVE_VERSION: int = 1
const NUM_SLOTS: int = 6
const SAVE_DIR: String = "user://saves"
const QUICKSAVE_DIR: String = "user://saves/quicksave"


static func get_slot_dir(slot_index: int) -> String:
	return "%s/slot_%d" % [SAVE_DIR, slot_index]


static func get_save_path(slot_index: int) -> String:
	return "%s/save.json" % get_slot_dir(slot_index)


static func get_screenshot_path(slot_index: int) -> String:
	return "%s/screenshot.png" % get_slot_dir(slot_index)


static func slot_exists(slot_index: int) -> bool:
	return FileAccess.file_exists(get_save_path(slot_index))


## Sauvegarde l'état du jeu dans le slot donné.
## state doit contenir : version, timestamp, story_path, chapter_uuid, chapter_name,
## scene_uuid, scene_name, sequence_uuid, sequence_name, dialogue_index, variables.
static func save_game(slot_index: int, state: Dictionary, screenshot: Image) -> bool:
	var dir_path := get_slot_dir(slot_index)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))

	# Écrire save.json
	var save_path := get_save_path(slot_index)
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return false
	var data := state.duplicate()
	data["version"] = SAVE_VERSION
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

	# Écrire screenshot.png
	if screenshot != null:
		var png_path := get_screenshot_path(slot_index)
		screenshot.save_png(png_path)

	return true


## Charge les données de sauvegarde d'un slot. Retourne {} si le slot est vide ou invalide.
static func load_game(slot_index: int) -> Dictionary:
	var save_path := get_save_path(slot_index)
	if not FileAccess.file_exists(save_path):
		return {}
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return {}
	var content := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(content)
	if parsed == null or not parsed is Dictionary:
		return {}
	return parsed


## Supprime tous les fichiers d'un slot.
static func delete_save(slot_index: int) -> void:
	var save_path := get_save_path(slot_index)
	var png_path := get_screenshot_path(slot_index)
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	if FileAccess.file_exists(png_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(png_path))


## Retourne la liste de tous les slots (0 à NUM_SLOTS-1).
## Chaque entrée : { slot_index, has_data, has_screenshot, data }
## Les sauvegardes dont la story_path est introuvable sont automatiquement supprimées.
static func list_saves() -> Array:
	var result: Array = []
	for i in range(NUM_SLOTS):
		var entry := { "slot_index": i, "has_data": false, "has_screenshot": false, "data": {} }
		if slot_exists(i):
			var data := load_game(i)
			if data.is_empty():
				entry["has_data"] = false
			else:
				# Vérifier que la story_path existe encore
				var story_path: String = data.get("story_path", "")
				if story_path != "" and not _story_path_valid(story_path):
					delete_save(i)
				else:
					entry["has_data"] = true
					entry["data"] = data
					entry["has_screenshot"] = FileAccess.file_exists(get_screenshot_path(i))
		result.append(entry)
	return result


## Vérifie si une sauvegarde rapide existe.
static func quicksave_exists() -> bool:
	return FileAccess.file_exists("%s/save.json" % QUICKSAVE_DIR)


## Sauvegarde rapide dans le slot dédié. Écrase silencieusement la précédente.
static func quicksave(state: Dictionary, screenshot: Image) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(QUICKSAVE_DIR))
	var save_path := "%s/save.json" % QUICKSAVE_DIR
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return false
	var data := state.duplicate()
	data["version"] = SAVE_VERSION
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	if screenshot != null:
		screenshot.save_png("%s/screenshot.png" % QUICKSAVE_DIR)
	return true


## Charge la sauvegarde rapide. Retourne {} si aucune sauvegarde.
static func quickload() -> Dictionary:
	var save_path := "%s/save.json" % QUICKSAVE_DIR
	if not FileAccess.file_exists(save_path):
		return {}
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return {}
	var content := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(content)
	if parsed == null or not parsed is Dictionary:
		return {}
	return parsed


## Supprime la sauvegarde rapide.
static func delete_quicksave() -> void:
	var save_path := "%s/save.json" % QUICKSAVE_DIR
	var png_path := "%s/screenshot.png" % QUICKSAVE_DIR
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	if FileAccess.file_exists(png_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(png_path))


## Vérifie si la story_path pointe vers un fichier de story existant.
static func _story_path_valid(story_path: String) -> bool:
	# La story peut être stockée comme répertoire (story.yaml à l'intérieur) ou comme fichier direct.
	var yaml_path := story_path.path_join("story.yaml") if not story_path.ends_with(".yaml") else story_path
	return FileAccess.file_exists(yaml_path)
