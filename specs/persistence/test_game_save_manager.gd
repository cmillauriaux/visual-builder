extends GutTest

# Tests pour GameSaveManager (sauvegarde/chargement de la progression en jeu)

const GameSaveManager = preload("res://src/persistence/game_save_manager.gd")

var _original_save_dir: String = ""

func before_each():
	# Réinitialiser les slots de test en nettoyant user://saves/slot_0 à slot_5
	for i in range(GameSaveManager.NUM_SLOTS):
		GameSaveManager.delete_save(i)

func after_each():
	# Nettoyage après chaque test
	for i in range(GameSaveManager.NUM_SLOTS):
		GameSaveManager.delete_save(i)


func _make_state(story_path: String = "user://stories/test") -> Dictionary:
	return {
		"timestamp": "2026-03-04 10:00:00",
		"story_path": story_path,
		"chapter_uuid": "chap-001",
		"chapter_name": "Chapitre 1",
		"scene_uuid": "scene-001",
		"scene_name": "Scène 1",
		"sequence_uuid": "seq-001",
		"sequence_name": "Intro",
		"dialogue_index": 2,
		"variables": {"hero_trust": 5, "choice_made": "peace"},
	}


func _make_dummy_image() -> Image:
	var img := Image.create(4, 4, false, Image.FORMAT_RGB8)
	img.fill(Color.RED)
	return img


# --- slot_exists ---

func test_slot_exists_returns_false_for_empty_slot():
	assert_false(GameSaveManager.slot_exists(0))


func test_slot_exists_returns_true_after_save():
	GameSaveManager.save_game(0, _make_state(), null)
	assert_true(GameSaveManager.slot_exists(0))


# --- save_game ---

func test_save_creates_json_file():
	GameSaveManager.save_game(0, _make_state(), null)
	assert_true(FileAccess.file_exists(GameSaveManager.get_save_path(0)))


func test_save_creates_screenshot_file():
	GameSaveManager.save_game(0, _make_state(), _make_dummy_image())
	assert_true(FileAccess.file_exists(GameSaveManager.get_screenshot_path(0)))


func test_save_injects_version():
	GameSaveManager.save_game(0, _make_state(), null)
	var data := GameSaveManager.load_game(0)
	assert_eq(data.get("version"), GameSaveManager.SAVE_VERSION)


func test_save_returns_true_on_success():
	var ok := GameSaveManager.save_game(0, _make_state(), null)
	assert_true(ok)


func test_save_preserves_all_state_fields():
	var state := _make_state()
	GameSaveManager.save_game(0, state, null)
	var loaded := GameSaveManager.load_game(0)
	assert_eq(loaded.get("chapter_uuid"), "chap-001")
	assert_eq(loaded.get("scene_uuid"), "scene-001")
	assert_eq(loaded.get("sequence_uuid"), "seq-001")
	assert_eq(loaded.get("dialogue_index"), 2)
	assert_eq(loaded.get("story_path"), "user://stories/test")


func test_save_preserves_variables():
	var state := _make_state()
	GameSaveManager.save_game(0, state, null)
	var loaded := GameSaveManager.load_game(0)
	var vars = loaded.get("variables", {})
	assert_eq(vars.get("hero_trust"), 5)
	assert_eq(vars.get("choice_made"), "peace")


# --- load_game ---

func test_load_returns_empty_dict_when_slot_empty():
	var data := GameSaveManager.load_game(0)
	assert_eq(data, {})


func test_load_returns_correct_data():
	GameSaveManager.save_game(2, _make_state(), null)
	var loaded := GameSaveManager.load_game(2)
	assert_false(loaded.is_empty())
	assert_eq(loaded.get("chapter_name"), "Chapitre 1")


# --- delete_save ---

func test_delete_removes_json_file():
	GameSaveManager.save_game(1, _make_state(), null)
	GameSaveManager.delete_save(1)
	assert_false(FileAccess.file_exists(GameSaveManager.get_save_path(1)))


func test_delete_removes_screenshot_file():
	GameSaveManager.save_game(1, _make_state(), _make_dummy_image())
	GameSaveManager.delete_save(1)
	assert_false(FileAccess.file_exists(GameSaveManager.get_screenshot_path(1)))


func test_delete_on_empty_slot_does_not_crash():
	GameSaveManager.delete_save(3)
	assert_false(GameSaveManager.slot_exists(3))


# --- save overwrites ---

func test_save_overwrites_existing_slot():
	GameSaveManager.save_game(0, _make_state(), null)
	var state2 := _make_state()
	state2["dialogue_index"] = 99
	GameSaveManager.save_game(0, state2, null)
	var loaded := GameSaveManager.load_game(0)
	assert_eq(loaded.get("dialogue_index"), 99)


# --- list_saves ---

func test_list_saves_returns_six_entries():
	var saves := GameSaveManager.list_saves()
	assert_eq(saves.size(), GameSaveManager.NUM_SLOTS)


func test_list_saves_empty_slots_have_no_data():
	var saves := GameSaveManager.list_saves()
	for entry in saves:
		assert_false(entry.get("has_data", false))


func test_list_saves_filled_slot_has_data():
	# story_path vide = pas de validation de fichier, la save est conservée
	GameSaveManager.save_game(0, _make_state(""), null)
	var saves := GameSaveManager.list_saves()
	assert_true(saves[0].get("has_data", false))


func test_list_saves_slot_with_screenshot_flagged():
	GameSaveManager.save_game(0, _make_state(""), _make_dummy_image())
	var saves := GameSaveManager.list_saves()
	assert_true(saves[0].get("has_screenshot", false))


func test_list_saves_slot_without_screenshot_not_flagged():
	GameSaveManager.save_game(0, _make_state(""), null)
	var saves := GameSaveManager.list_saves()
	assert_false(saves[0].get("has_screenshot", false))


func test_list_saves_auto_deletes_invalid_story_path():
	# Sauvegarder avec une story_path inexistante
	var state := _make_state("user://inexistant_story/xyz")
	GameSaveManager.save_game(0, state, null)
	# list_saves doit supprimer automatiquement et retourner slot vide
	var saves := GameSaveManager.list_saves()
	assert_false(saves[0].get("has_data", false))
	assert_false(GameSaveManager.slot_exists(0))


func test_list_saves_valid_story_path_kept():
	# Sauvegarder avec une story_path vide (cas spécial : pas de vérification)
	var state := _make_state("")
	GameSaveManager.save_game(0, state, null)
	var saves := GameSaveManager.list_saves()
	# story_path vide = pas de vérification, la save est conservée
	assert_true(saves[0].get("has_data", false))
