extends GutTest

const GameSaveManager = preload("res://src/persistence/game_save_manager.gd")

var _test_slot := 5  # Dernier slot dans NUM_SLOTS (0-5)

func after_each():
	# Nettoyer les fichiers créés pendant les tests
	GameSaveManager.delete_save(_test_slot)
	GameSaveManager.delete_quicksave()


# --- Instance API (déjà couverte partiellement) ---

func test_get_saves_list_empty():
	var mgr = GameSaveManager.new()
	var saves = mgr.get_saves_list()
	assert_true(saves is Array, "Saves list should be an Array")

func test_save_game_null_story():
	var mgr = GameSaveManager.new()
	var ok = mgr.save_game(null, 1)
	assert_false(ok, "Saving a null story should return false")

func test_load_game_invalid_slot():
	var mgr = GameSaveManager.new()
	var data = mgr.load_game(999)
	assert_eq(data, {}, "Loading an invalid slot should return an empty dictionary")

func test_delete_save():
	var mgr = GameSaveManager.new()
	mgr.delete_save(1)
	pass_test("Deleting a nonexistent save should not crash")


# --- Path builders (méthodes statiques pures) ---

func test_get_slot_dir_format():
	assert_eq(GameSaveManager.get_slot_dir(0), "user://saves/slot_0")
	assert_eq(GameSaveManager.get_slot_dir(3), "user://saves/slot_3")

func test_get_save_path_format():
	assert_eq(GameSaveManager.get_save_path(0), "user://saves/slot_0/save.json")
	assert_eq(GameSaveManager.get_save_path(5), "user://saves/slot_5/save.json")

func test_get_screenshot_path_format():
	assert_eq(GameSaveManager.get_screenshot_path(0), "user://saves/slot_0/screenshot.png")
	assert_eq(GameSaveManager.get_screenshot_path(2), "user://saves/slot_2/screenshot.png")

func test_get_autosave_dir_format():
	assert_eq(GameSaveManager.get_autosave_dir(0), "user://saves/autosave_0")
	assert_eq(GameSaveManager.get_autosave_dir(9), "user://saves/autosave_9")

func test_get_autosave_save_path_format():
	assert_eq(GameSaveManager.get_autosave_save_path(0), "user://saves/autosave_0/save.json")

func test_get_autosave_screenshot_path_format():
	assert_eq(GameSaveManager.get_autosave_screenshot_path(0), "user://saves/autosave_0/screenshot.png")


# --- Existence checks ---

func test_slot_exists_false_when_no_file():
	assert_false(GameSaveManager.slot_exists(99), "Slot 99 should not exist")

func test_slot_exists_true_after_save():
	GameSaveManager.save_game_state(_test_slot, {"story_path": ""}, null)
	assert_true(GameSaveManager.slot_exists(_test_slot))

func test_quicksave_exists_false_when_no_quicksave():
	GameSaveManager.delete_quicksave()
	assert_false(GameSaveManager.quicksave_exists())

func test_quicksave_exists_true_after_quicksave():
	GameSaveManager.quicksave({"key": "val"}, null)
	assert_true(GameSaveManager.quicksave_exists())


# --- _story_path_valid ---

func test_story_path_valid_false_for_nonexistent():
	assert_false(GameSaveManager._story_path_valid("nonexistent/path/to/story"))

func test_story_path_valid_false_for_empty():
	# chemin vide → story.yaml n'existe pas → false
	assert_false(GameSaveManager._story_path_valid(""))

func test_story_path_valid_with_yaml_extension():
	# chemin .yaml inexistant → false
	assert_false(GameSaveManager._story_path_valid("nonexistent/story.yaml"))


# --- load_autosave / quickload (slots vides) ---

func test_load_autosave_nonexistent_returns_empty():
	assert_eq(GameSaveManager.load_autosave(99), {})

func test_quickload_when_no_quicksave_returns_empty():
	GameSaveManager.delete_quicksave()
	assert_eq(GameSaveManager.quickload(), {})


# --- delete_quicksave ---

func test_delete_quicksave_no_crash():
	GameSaveManager.delete_quicksave()
	pass_test("delete_quicksave should not crash when no quicksave exists")

func test_delete_quicksave_removes_file():
	GameSaveManager.quicksave({"k": "v"}, null)
	assert_true(GameSaveManager.quicksave_exists())
	GameSaveManager.delete_quicksave()
	assert_false(GameSaveManager.quicksave_exists())


# --- quicksave / quickload roundtrip ---

func test_quicksave_returns_true():
	var ok = GameSaveManager.quicksave({"chapter_name": "Ch1"}, null)
	assert_true(ok)

func test_quicksave_and_quickload_roundtrip():
	var state := {"chapter_name": "Quick Chapter", "scene_name": "Quick Scene", "story_path": ""}
	GameSaveManager.quicksave(state, null)
	var loaded = GameSaveManager.quickload()
	assert_eq(loaded.get("chapter_name", ""), "Quick Chapter")
	assert_eq(loaded.get("scene_name", ""), "Quick Scene")


# --- save_game_state / load_game roundtrip ---

func test_save_game_state_returns_true():
	var ok = GameSaveManager.save_game_state(_test_slot, {"story_path": ""}, null)
	assert_true(ok)

func test_save_game_state_and_load_roundtrip():
	var state := {
		"chapter_name": "Chapitre Test",
		"scene_name": "Scène Test",
		"story_path": ""
	}
	GameSaveManager.save_game_state(_test_slot, state, null)
	var loaded = GameSaveManager.load_game(_test_slot)
	assert_eq(loaded.get("chapter_name", ""), "Chapitre Test")
	assert_eq(loaded.get("scene_name", ""), "Scène Test")

func test_save_game_state_adds_version():
	GameSaveManager.save_game_state(_test_slot, {}, null)
	var loaded = GameSaveManager.load_game(_test_slot)
	assert_true(loaded.has("version"), "save.json doit contenir 'version'")
	assert_eq(loaded.get("version"), GameSaveManager.SAVE_VERSION)

func test_delete_save_removes_file():
	GameSaveManager.save_game_state(_test_slot, {}, null)
	assert_true(GameSaveManager.slot_exists(_test_slot))
	GameSaveManager.delete_save(_test_slot)
	assert_false(GameSaveManager.slot_exists(_test_slot))


# --- list_saves ---

func test_list_saves_has_num_slots_entries():
	var saves = GameSaveManager.list_saves()
	assert_eq(saves.size(), GameSaveManager.NUM_SLOTS)

func test_list_saves_entries_have_required_keys():
	var saves = GameSaveManager.list_saves()
	for entry in saves:
		assert_true(entry.has("slot_index"))
		assert_true(entry.has("has_data"))
		assert_true(entry.has("has_screenshot"))
		assert_true(entry.has("data"))

func test_list_saves_shows_saved_entry():
	GameSaveManager.save_game_state(_test_slot, {"chapter_name": "Test", "story_path": ""}, null)
	var found = false
	for entry in GameSaveManager.list_saves():
		if entry.get("slot_index") == _test_slot and entry.get("has_data"):
			found = true
			break
	assert_true(found, "Le slot %d doit apparaître dans list_saves" % _test_slot)


# --- autosave / load_autosave roundtrip ---

func test_autosave_returns_true():
	var ok = GameSaveManager.autosave({"chapter_name": "AutoCh"}, null)
	assert_true(ok)

func test_autosave_and_load_roundtrip():
	var state := {"chapter_name": "Auto Chapter", "story_path": ""}
	GameSaveManager.autosave(state, null)
	var autosaves = GameSaveManager.list_autosaves()
	assert_gt(autosaves.size(), 0, "Doit avoir au moins 1 autosave après autosave()")
	var latest = autosaves[0]
	assert_eq(latest.get("data", {}).get("chapter_name", ""), "Auto Chapter")


# --- list_autosaves ---

func test_list_autosaves_returns_array():
	var result = GameSaveManager.list_autosaves()
	assert_true(result is Array)

func test_list_autosaves_after_multiple_saves():
	GameSaveManager.autosave({"chapter_name": "Save1"}, null)
	GameSaveManager.autosave({"chapter_name": "Save2"}, null)
	var autosaves = GameSaveManager.list_autosaves()
	assert_gte(autosaves.size(), 2)
	# Le plus récent doit être en premier
	assert_eq(autosaves[0].get("data", {}).get("chapter_name", ""), "Save2")
