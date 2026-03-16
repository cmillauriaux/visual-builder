extends GutTest

var GameSettingsScript

func before_each():
	GameSettingsScript = load("res://src/ui/menu/game_settings.gd")

func test_default_values():
	var settings = GameSettingsScript.new()
	assert_eq(settings.resolution, Vector2i(1920, 1080))
	assert_false(settings.fullscreen)
	assert_true(settings.music_enabled)
	assert_eq(settings.music_volume, 80)
	assert_true(settings.fx_enabled)
	assert_eq(settings.fx_volume, 80)
	assert_eq(settings.language, "")
	assert_true(settings.autosave_enabled)

func test_get_ui_scale_factor():
	var settings = GameSettingsScript.new()
	settings.ui_scale_mode = 0
	assert_eq(settings.get_ui_scale_factor(), 1.25)
	settings.ui_scale_mode = 1
	assert_eq(settings.get_ui_scale_factor(), 1.5)
	settings.ui_scale_mode = 2
	assert_eq(settings.get_ui_scale_factor(), 2.0)

func test_is_language_auto():
	var settings = GameSettingsScript.new()
	settings.language = ""
	assert_true(settings.is_language_auto())
	settings.language = "fr"
	assert_false(settings.is_language_auto())

func test_save_and_load_settings():
	var path = "user://test_settings.cfg"
	var settings = GameSettingsScript.new()
	settings.music_volume = 42
	settings.fullscreen = true
	settings.language = "eo"
	settings.save_settings(path)
	
	var settings_loaded = GameSettingsScript.new()
	settings_loaded.load_settings(path)
	assert_eq(settings_loaded.music_volume, 42)
	assert_true(settings_loaded.fullscreen)
	assert_eq(settings_loaded.language, "eo")
	
	DirAccess.remove_absolute(path)

func test_get_default_ui_scale_mode():
	# Standard desktop should return 1
	assert_eq(GameSettingsScript.get_default_ui_scale_mode(), 1)

func test_load_settings_nonexistent_sets_default_scale():
	var settings = GameSettingsScript.new()
	settings.load_settings("user://totally_nonexistent_settings_file.cfg")
	assert_eq(settings.ui_scale_mode, GameSettingsScript.get_default_ui_scale_mode())

func test_get_ui_scale_factor_negative_mode_uses_default():
	var settings = GameSettingsScript.new()
	settings.ui_scale_mode = -1
	var factor = settings.get_ui_scale_factor()
	assert_true(factor > 0.0)

func test_get_ui_scale_factor_out_of_range_returns_one():
	var settings = GameSettingsScript.new()
	settings.ui_scale_mode = 99
	assert_eq(settings.get_ui_scale_factor(), 1.0)

func test_save_all_settings_fields():
	var path = "user://test_settings_full.cfg"
	var settings = GameSettingsScript.new()
	settings.auto_play_enabled = true
	settings.auto_play_delay = 3.0
	settings.typewriter_speed = 0.06
	settings.dialogue_opacity = 60
	settings.toolbar_visible = false
	settings.ui_scale_mode = 2
	settings.save_settings(path)
	var loaded = GameSettingsScript.new()
	loaded.load_settings(path)
	assert_true(loaded.auto_play_enabled)
	assert_eq(loaded.auto_play_delay, 3.0)
	assert_eq(loaded.typewriter_speed, 0.06)
	assert_eq(loaded.dialogue_opacity, 60)
	assert_false(loaded.toolbar_visible)
	assert_eq(loaded.ui_scale_mode, 2)
	DirAccess.remove_absolute(path)
