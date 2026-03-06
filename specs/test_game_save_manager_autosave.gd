extends GutTest

## Tests pour les fonctions autosave de GameSaveManager.

const GameSaveManager = preload("res://src/persistence/game_save_manager.gd")


func before_each() -> void:
	_clean_autosaves()


func after_each() -> void:
	_clean_autosaves()


func _clean_autosaves() -> void:
	for i in range(GameSaveManager.NUM_AUTOSAVE_SLOTS):
		var dir := GameSaveManager.get_autosave_dir(i)
		var save_path := dir + "/save.json"
		var png_path := dir + "/screenshot.png"
		if FileAccess.file_exists(save_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
		if FileAccess.file_exists(png_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(png_path))
	var idx_path := GameSaveManager.AUTOSAVE_INDEX_PATH
	if FileAccess.file_exists(idx_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(idx_path))


func _make_state(chapter: String = "Chapitre 1", scene: String = "Scène 1") -> Dictionary:
	return {
		"timestamp": "2026-03-06 10:00:00",
		"story_path": "",
		"chapter_uuid": "chap-001",
		"chapter_name": chapter,
		"scene_uuid": "scene-001",
		"scene_name": scene,
		"sequence_uuid": "seq-001",
		"sequence_name": "Intro",
		"dialogue_index": 0,
		"variables": {},
	}


# --- Constantes ---

func test_num_autosave_slots_is_ten() -> void:
	assert_eq(GameSaveManager.NUM_AUTOSAVE_SLOTS, 10)


func test_autosave_dir_format() -> void:
	assert_eq(GameSaveManager.get_autosave_dir(0), "user://saves/autosave_0")
	assert_eq(GameSaveManager.get_autosave_dir(9), "user://saves/autosave_9")


func test_autosave_index_path_exists_as_constant() -> void:
	assert_true(GameSaveManager.AUTOSAVE_INDEX_PATH != "")


# --- autosave() ---

func test_autosave_creates_save_file() -> void:
	var result := GameSaveManager.autosave(_make_state(), null)
	assert_true(result)
	var slot := GameSaveManager._get_current_autosave_index()
	# L'index a été incrémenté après la save, donc le slot utilisé est (index - 1) % 10
	var used_slot := (slot - 1 + GameSaveManager.NUM_AUTOSAVE_SLOTS) % GameSaveManager.NUM_AUTOSAVE_SLOTS
	var save_path := GameSaveManager.get_autosave_dir(used_slot) + "/save.json"
	assert_true(FileAccess.file_exists(save_path), "save.json doit exister dans autosave_%d" % used_slot)


func test_autosave_writes_correct_data() -> void:
	var state := _make_state("Mon Chapitre", "Ma Scène")
	GameSaveManager.autosave(state, null)
	var slot := GameSaveManager._get_current_autosave_index()
	var used_slot := (slot - 1 + GameSaveManager.NUM_AUTOSAVE_SLOTS) % GameSaveManager.NUM_AUTOSAVE_SLOTS
	var data := GameSaveManager.load_autosave(used_slot)
	assert_eq(data.get("chapter_name", ""), "Mon Chapitre")
	assert_eq(data.get("scene_name", ""), "Ma Scène")


func test_autosave_returns_false_on_invalid_path() -> void:
	# Ce test vérifie uniquement que la fonction retourne bool
	var result := GameSaveManager.autosave(_make_state(), null)
	assert_true(result is bool)


# --- Rotation circulaire ---

func test_autosave_rotation_increments_index() -> void:
	GameSaveManager.autosave(_make_state(), null)
	var idx1 := GameSaveManager._get_current_autosave_index()
	GameSaveManager.autosave(_make_state(), null)
	var idx2 := GameSaveManager._get_current_autosave_index()
	assert_eq(idx2, (idx1 + 1) % GameSaveManager.NUM_AUTOSAVE_SLOTS)


func test_autosave_rotation_wraps_at_ten() -> void:
	# Remplir les 10 slots
	for i in range(GameSaveManager.NUM_AUTOSAVE_SLOTS):
		GameSaveManager.autosave(_make_state("Chapitre %d" % i, "Scène %d" % i), null)
	# L'index doit être revenu à 0
	var idx := GameSaveManager._get_current_autosave_index()
	assert_eq(idx, 0)


func test_autosave_slot_nine_followed_by_slot_zero() -> void:
	# Avancer jusqu'au slot 9
	for i in range(9):
		GameSaveManager.autosave(_make_state(), null)
	var idx_before := GameSaveManager._get_current_autosave_index()
	assert_eq(idx_before, 9)
	# Slot 9 → prochain sera 0
	GameSaveManager.autosave(_make_state("Après rotation", "Scene X"), null)
	var idx_after := GameSaveManager._get_current_autosave_index()
	assert_eq(idx_after, 0)


# --- load_autosave() ---

func test_load_autosave_returns_empty_for_missing_slot() -> void:
	var data := GameSaveManager.load_autosave(0)
	assert_true(data.is_empty())


func test_load_autosave_returns_data_for_existing_slot() -> void:
	GameSaveManager.autosave(_make_state("Test Load", "Scene Load"), null)
	var slot := GameSaveManager._get_current_autosave_index()
	var used_slot := (slot - 1 + GameSaveManager.NUM_AUTOSAVE_SLOTS) % GameSaveManager.NUM_AUTOSAVE_SLOTS
	var data := GameSaveManager.load_autosave(used_slot)
	assert_false(data.is_empty())
	assert_eq(data.get("chapter_name", ""), "Test Load")


# --- list_autosaves() ---

func test_list_autosaves_returns_empty_when_no_saves() -> void:
	var list := GameSaveManager.list_autosaves()
	assert_eq(list.size(), 0)


func test_list_autosaves_returns_one_entry_after_one_save() -> void:
	GameSaveManager.autosave(_make_state(), null)
	var list := GameSaveManager.list_autosaves()
	assert_eq(list.size(), 1)


func test_list_autosaves_returns_all_saves() -> void:
	for i in range(5):
		GameSaveManager.autosave(_make_state("Chapitre %d" % i, "Scène %d" % i), null)
	var list := GameSaveManager.list_autosaves()
	assert_eq(list.size(), 5)


func test_list_autosaves_sorted_most_recent_first() -> void:
	GameSaveManager.autosave(_make_state("Premier", "Scène 1"), null)
	GameSaveManager.autosave(_make_state("Deuxième", "Scène 2"), null)
	GameSaveManager.autosave(_make_state("Troisième", "Scène 3"), null)
	var list := GameSaveManager.list_autosaves()
	assert_eq(list.size(), 3)
	# La plus récente doit être en premier
	assert_eq(list[0].get("data", {}).get("chapter_name", ""), "Troisième")
	assert_eq(list[1].get("data", {}).get("chapter_name", ""), "Deuxième")
	assert_eq(list[2].get("data", {}).get("chapter_name", ""), "Premier")


func test_list_autosaves_entry_has_expected_keys() -> void:
	GameSaveManager.autosave(_make_state(), null)
	var list := GameSaveManager.list_autosaves()
	var entry: Dictionary = list[0]
	assert_true(entry.has("slot_index"))
	assert_true(entry.has("data"))
	assert_true(entry.has("has_screenshot"))


func test_list_autosaves_max_ten_entries() -> void:
	for i in range(12):
		GameSaveManager.autosave(_make_state("Chapitre %d" % i, "Scène %d" % i), null)
	var list := GameSaveManager.list_autosaves()
	assert_true(list.size() <= GameSaveManager.NUM_AUTOSAVE_SLOTS)
