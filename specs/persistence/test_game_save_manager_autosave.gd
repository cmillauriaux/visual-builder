extends GutTest

var GameSaveManagerScript

func before_each():
	GameSaveManagerScript = load("res://src/persistence/game_save_manager.gd")

func test_autosave_enabled_by_default():
	var mgr = GameSaveManagerScript.new()
	assert_true(mgr.is_autosave_enabled())

func test_toggle_autosave():
	var mgr = GameSaveManagerScript.new()
	mgr.set_autosave_enabled(false)
	assert_false(mgr.is_autosave_enabled())
	mgr.set_autosave_enabled(true)
	assert_true(mgr.is_autosave_enabled())

func test_get_autosave_interval():
	var mgr = GameSaveManagerScript.new()
	assert_gt(mgr.get_autosave_interval(), 0)
