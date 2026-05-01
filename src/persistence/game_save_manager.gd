# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends RefCounted

## Gère les sauvegardes de progression en jeu.
## Stocke les données dans user://saves/slot_N/ (save.json + screenshot.png).
## Toutes les méthodes sont statiques.

const SAVE_VERSION: int = 1
const NUM_SLOTS: int = 6
const SAVE_DIR: String = "user://saves"
const QUICKSAVE_DIR: String = "user://saves/quicksave"
const NUM_AUTOSAVE_SLOTS: int = 10
const AUTOSAVE_INDEX_PATH: String = "user://saves/autosave_index.dat"

static var _autosave_mutex: Mutex = Mutex.new()


static func get_autosave_dir(slot_index: int) -> String:
	return "%s/autosave_%d" % [SAVE_DIR, slot_index]


static func get_autosave_save_path(slot_index: int) -> String:
	return "%s/save.json" % get_autosave_dir(slot_index)


static func get_autosave_screenshot_path(slot_index: int) -> String:
	return "%s/screenshot.png" % get_autosave_dir(slot_index)


## Lit l'index courant de rotation des auto-saves (0–9). Retourne 0 par défaut.
static func _get_current_autosave_index() -> int:
	if not FileAccess.file_exists(AUTOSAVE_INDEX_PATH):
		return 0
	var file := FileAccess.open(AUTOSAVE_INDEX_PATH, FileAccess.READ)
	if file == null:
		return 0
	var content := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(content)
	if parsed == null or not parsed is float and not parsed is int:
		return 0
	return int(parsed)


## Persiste l'index courant dans autosave_index.dat.
static func _save_autosave_index(index: int) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
	var file := FileAccess.open(AUTOSAVE_INDEX_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(index))
	file.close()


## Sauvegarde automatique avec rotation sur NUM_AUTOSAVE_SLOTS slots.
## Retourne true si la sauvegarde a réussi.
static func autosave(state: Dictionary, screenshot: Image) -> bool:
	_autosave_mutex.lock()
	var index := _get_current_autosave_index()
	var slot := index % NUM_AUTOSAVE_SLOTS
	var dir_path := get_autosave_dir(slot)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))

	var save_path := get_autosave_save_path(slot)
	var data := _prepare_save_data(state)
	if not _write_json_atomic(save_path, data):
		_autosave_mutex.unlock()
		return false

	if screenshot != null:
		screenshot.save_png(get_autosave_screenshot_path(slot))

	_save_autosave_index((index + 1) % NUM_AUTOSAVE_SLOTS)
	_autosave_mutex.unlock()
	return true


## Charge les données d'un slot autosave. Retourne {} si le slot est vide ou invalide.
static func load_autosave(slot_index: int) -> Dictionary:
	if slot_index < 0 or slot_index >= NUM_AUTOSAVE_SLOTS:
		return {}
	var save_path := get_autosave_save_path(slot_index)
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


## Retourne la liste de toutes les auto-saves existantes, triées de la plus récente à la plus ancienne.
## Chaque entrée : { slot_index, data, has_screenshot }
static func list_autosaves() -> Array:
	var result: Array = []

	for i in range(NUM_AUTOSAVE_SLOTS):
		var slot := i
		var save_path := get_autosave_save_path(slot)
		if not FileAccess.file_exists(save_path):
			continue
		var data := load_autosave(slot)
		if data.is_empty():
			continue
		result.append({
			"slot_index": slot,
			"data": data,
			"has_screenshot": FileAccess.file_exists(get_autosave_screenshot_path(slot)),
			"_sort_time": data.get("_saved_at_unix", FileAccess.get_modified_time(save_path)),
		})

	result.sort_custom(func(a, b): return float(a.get("_sort_time", 0.0)) > float(b.get("_sort_time", 0.0)))
	for entry in result:
		entry.erase("_sort_time")
	return result


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
static func save_game_state(slot_index: int, state: Dictionary, screenshot: Image) -> bool:
	var dir_path := get_slot_dir(slot_index)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))

	var save_path := get_save_path(slot_index)
	var data := _prepare_save_data(state)
	if not _write_json_atomic(save_path, data):
		return false

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
	var data := _prepare_save_data(state)
	if not _write_json_atomic(save_path, data):
		return false
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


static func _prepare_save_data(state: Dictionary) -> Dictionary:
	var data := state.duplicate(true)
	data["version"] = SAVE_VERSION
	data["_saved_at_unix"] = Time.get_unix_time_from_system()
	return data


static func _write_json_atomic(path: String, data: Dictionary) -> bool:
	var tmp_path := path + ".tmp"
	var backup_path := path + ".bak"
	var tmp_global := ProjectSettings.globalize_path(tmp_path)
	var path_global := ProjectSettings.globalize_path(path)
	var backup_global := ProjectSettings.globalize_path(backup_path)

	if FileAccess.file_exists(tmp_path):
		DirAccess.remove_absolute(tmp_global)
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_global)

	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

	var had_existing := FileAccess.file_exists(path)
	if had_existing:
		var backup_err := DirAccess.rename_absolute(path_global, backup_global)
		if backup_err != OK:
			DirAccess.remove_absolute(tmp_global)
			return false

	var replace_err := DirAccess.rename_absolute(tmp_global, path_global)
	if replace_err != OK:
		if had_existing:
			DirAccess.rename_absolute(backup_global, path_global)
		if FileAccess.file_exists(tmp_path):
			DirAccess.remove_absolute(tmp_global)
		return false

	if had_existing and FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_global)
	return true


## Vérifie si la story_path pointe vers un fichier de story existant.
static func _story_path_valid(story_path: String) -> bool:
	# La story peut être stockée comme répertoire (story.yaml à l'intérieur) ou comme fichier direct.
	var yaml_path := story_path.path_join("story.yaml") if not story_path.ends_with(".yaml") else story_path
	return FileAccess.file_exists(yaml_path)


# ── Instance API (pour les tests et usages en objet) ─────────────────────────

var _autosave_enabled: bool = true

const AUTOSAVE_INTERVAL_SECONDS: float = 300.0


func get_saves_list() -> Array:
	return list_saves()


## Sauvegarde depuis un objet story. Retourne false si story est null.
func save_game(story, slot_index: int) -> bool:
	if story == null:
		return false
	return save_game_state(slot_index, {}, null)


func is_autosave_enabled() -> bool:
	return _autosave_enabled


func set_autosave_enabled(enabled: bool) -> void:
	_autosave_enabled = enabled


func get_autosave_interval() -> float:
	return AUTOSAVE_INTERVAL_SECONDS
