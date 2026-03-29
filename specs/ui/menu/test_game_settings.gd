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
	assert_true(settings.voice_enabled)
	assert_eq(settings.voice_volume, 100)
	assert_eq(settings.voice_language, "")
	assert_true(settings.fx_enabled)
	assert_eq(settings.fx_volume, 100)
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


func test_save_and_load_voice_settings():
	var path = "user://test_settings_voice.cfg"
	var settings = GameSettingsScript.new()
	settings.voice_enabled = false
	settings.voice_volume = 50
	settings.voice_language = "en"
	settings.save_settings(path)
	var loaded = GameSettingsScript.new()
	loaded.load_settings(path)
	assert_false(loaded.voice_enabled)
	assert_eq(loaded.voice_volume, 50)
	assert_eq(loaded.voice_language, "en")
	DirAccess.remove_absolute(path)


func test_save_and_load_game_plugins_enabled():
	var path = "user://test_settings_plugins.cfg"
	var settings = GameSettingsScript.new()
	settings.game_plugins_enabled = {"lora_plugin": true, "voice_plugin": false}
	settings.save_settings(path)
	var loaded = GameSettingsScript.new()
	loaded.load_settings(path)
	assert_eq(loaded.game_plugins_enabled.get("lora_plugin"), true)
	assert_eq(loaded.game_plugins_enabled.get("voice_plugin"), false)
	DirAccess.remove_absolute(path)


func test_save_and_load_pwa_prompt_dismissed():
	var path = "user://test_settings_pwa.cfg"
	var settings = GameSettingsScript.new()
	settings.pwa_prompt_dismissed = true
	settings.save_settings(path)
	var loaded = GameSettingsScript.new()
	loaded.load_settings(path)
	assert_true(loaded.pwa_prompt_dismissed)
	DirAccess.remove_absolute(path)


func test_is_mobile_browser_returns_false_on_non_web():
	# On desktop (non-Web), _is_mobile_browser should always return false
	assert_false(GameSettingsScript._is_mobile_browser())


func test_apply_settings_does_not_crash():
	var settings = GameSettingsScript.new()
	settings.language = "fr"  # Éviter set_locale("") qui provoque une erreur engine
	settings.apply_settings()
	assert_true(true, "apply_settings ne doit pas crasher")


func test_apply_settings_fullscreen():
	var settings = GameSettingsScript.new()
	settings.fullscreen = true
	settings.language = "en"
	settings.apply_settings()
	# Remettre en mode fenêtré après le test
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	assert_true(true, "apply_settings fullscreen ne doit pas crasher")


func test_save_empty_plugins_does_not_write_key():
	var path = "user://test_settings_empty_plugins.cfg"
	var settings = GameSettingsScript.new()
	# game_plugins_enabled est {} par défaut → ne doit pas écrire la clé
	settings.save_settings(path)
	var cfg = ConfigFile.new()
	cfg.load(path)
	assert_false(cfg.has_section_key("plugins", "enabled_states"),
		"plugins.enabled_states ne doit pas être écrit si vide")
	DirAccess.remove_absolute(path)


func test_load_settings_with_non_dict_plugins_json():
	var path = "user://test_settings_non_dict_plugins.cfg"
	var cfg = ConfigFile.new()
	cfg.set_value("plugins", "enabled_states", "[1,2,3]")
	cfg.save(path)
	var settings = GameSettingsScript.new()
	settings.load_settings(path)
	assert_true(settings.game_plugins_enabled.is_empty(),
		"JSON non-dict ne doit pas écraser game_plugins_enabled")
	DirAccess.remove_absolute(path)
