extends GutTest

var GameSaveManagerScript
var StoryModelScript

func before_each():
	GameSaveManagerScript = load("res://src/persistence/game_save_manager.gd")
	StoryModelScript = load("res://src/models/story.gd")

func test_get_saves_list_empty():
	var mgr = GameSaveManagerScript.new()
	var saves = mgr.get_saves_list()
	assert_true(saves is Array, "Saves list should be an Array")

func test_save_game_null_story():
	var mgr = GameSaveManagerScript.new()
	var ok = mgr.save_game(null, 1)
	assert_false(ok, "Saving a null story should return false")

func test_load_game_invalid_slot():
	var mgr = GameSaveManagerScript.new()
	var data = mgr.load_game(999)
	assert_eq(data, {}, "Loading an invalid slot should return an empty dictionary")

func test_delete_save():
	var mgr = GameSaveManagerScript.new()
	mgr.delete_save(1)
	assert_true(true, "Deleting a nonexistent save should not crash")
