extends GutTest

const GameSettings = preload("res://src/ui/menu/game_settings.gd")

var _settings: RefCounted
var _test_cfg_path := "user://test_settings.cfg"


func before_each():
	_settings = GameSettings.new()
	# Nettoyer le fichier de test
	if FileAccess.file_exists(_test_cfg_path):
		DirAccess.remove_absolute(_test_cfg_path)


func after_each():
	if FileAccess.file_exists(_test_cfg_path):
		DirAccess.remove_absolute(_test_cfg_path)


# --- Valeurs par défaut ---

func test_default_resolution():
	assert_eq(_settings.resolution, Vector2i(1920, 1080))

func test_default_fullscreen():
	assert_eq(_settings.fullscreen, false)

func test_default_music_enabled():
	assert_eq(_settings.music_enabled, true)

func test_default_music_volume():
	assert_eq(_settings.music_volume, 80)

func test_default_fx_enabled():
	assert_eq(_settings.fx_enabled, true)

func test_default_fx_volume():
	assert_eq(_settings.fx_volume, 80)

func test_default_language():
	assert_eq(_settings.language, "fr")

func test_default_auto_play_enabled():
	assert_eq(_settings.auto_play_enabled, false)

func test_default_auto_play_delay():
	assert_eq(_settings.auto_play_delay, 2.0)

func test_default_typewriter_speed():
	assert_eq(_settings.typewriter_speed, 0.03)

func test_default_dialogue_opacity():
	assert_eq(_settings.dialogue_opacity, 80)


# --- Sauvegarde et chargement ---

func test_save_creates_file():
	_settings.save_settings(_test_cfg_path)
	assert_true(FileAccess.file_exists(_test_cfg_path), "Le fichier settings.cfg doit être créé")

func test_save_and_load_resolution():
	_settings.resolution = Vector2i(1280, 720)
	_settings.save_settings(_test_cfg_path)
	var loaded = GameSettings.new()
	loaded.load_settings(_test_cfg_path)
	assert_eq(loaded.resolution, Vector2i(1280, 720))

func test_save_and_load_fullscreen():
	_settings.fullscreen = true
	_settings.save_settings(_test_cfg_path)
	var loaded = GameSettings.new()
	loaded.load_settings(_test_cfg_path)
	assert_eq(loaded.fullscreen, true)

func test_save_and_load_music_enabled():
	_settings.music_enabled = false
	_settings.save_settings(_test_cfg_path)
	var loaded = GameSettings.new()
	loaded.load_settings(_test_cfg_path)
	assert_eq(loaded.music_enabled, false)

func test_save_and_load_music_volume():
	_settings.music_volume = 50
	_settings.save_settings(_test_cfg_path)
	var loaded = GameSettings.new()
	loaded.load_settings(_test_cfg_path)
	assert_eq(loaded.music_volume, 50)

func test_save_and_load_fx_enabled():
	_settings.fx_enabled = false
	_settings.save_settings(_test_cfg_path)
	var loaded = GameSettings.new()
	loaded.load_settings(_test_cfg_path)
	assert_eq(loaded.fx_enabled, false)

func test_save_and_load_fx_volume():
	_settings.fx_volume = 30
	_settings.save_settings(_test_cfg_path)
	var loaded = GameSettings.new()
	loaded.load_settings(_test_cfg_path)
	assert_eq(loaded.fx_volume, 30)

func test_save_and_load_language():
	_settings.language = "en"
	_settings.save_settings(_test_cfg_path)
	var loaded = GameSettings.new()
	loaded.load_settings(_test_cfg_path)
	assert_eq(loaded.language, "en")

func test_save_and_load_auto_play_enabled():
	_settings.auto_play_enabled = true
	_settings.save_settings(_test_cfg_path)
	var loaded = GameSettings.new()
	loaded.load_settings(_test_cfg_path)
	assert_eq(loaded.auto_play_enabled, true)

func test_save_and_load_auto_play_delay():
	_settings.auto_play_delay = 3.0
	_settings.save_settings(_test_cfg_path)
	var loaded = GameSettings.new()
	loaded.load_settings(_test_cfg_path)
	assert_eq(loaded.auto_play_delay, 3.0)

func test_save_and_load_typewriter_speed_slow():
	_settings.typewriter_speed = 0.06
	_settings.save_settings(_test_cfg_path)
	var loaded = GameSettings.new()
	loaded.load_settings(_test_cfg_path)
	assert_eq(loaded.typewriter_speed, 0.06)

func test_save_and_load_typewriter_speed_fast():
	_settings.typewriter_speed = 0.015
	_settings.save_settings(_test_cfg_path)
	var loaded = GameSettings.new()
	loaded.load_settings(_test_cfg_path)
	assert_eq(loaded.typewriter_speed, 0.015)

func test_save_and_load_typewriter_speed_instant():
	_settings.typewriter_speed = 0.0
	_settings.save_settings(_test_cfg_path)
	var loaded = GameSettings.new()
	loaded.load_settings(_test_cfg_path)
	assert_eq(loaded.typewriter_speed, 0.0)

func test_save_and_load_dialogue_opacity():
	_settings.dialogue_opacity = 50
	_settings.save_settings(_test_cfg_path)
	var loaded = GameSettings.new()
	loaded.load_settings(_test_cfg_path)
	assert_eq(loaded.dialogue_opacity, 50)

func test_save_and_load_dialogue_opacity_zero():
	_settings.dialogue_opacity = 0
	_settings.save_settings(_test_cfg_path)
	var loaded = GameSettings.new()
	loaded.load_settings(_test_cfg_path)
	assert_eq(loaded.dialogue_opacity, 0)

func test_save_and_load_dialogue_opacity_full():
	_settings.dialogue_opacity = 100
	_settings.save_settings(_test_cfg_path)
	var loaded = GameSettings.new()
	loaded.load_settings(_test_cfg_path)
	assert_eq(loaded.dialogue_opacity, 100)

func test_load_nonexistent_file_uses_defaults():
	_settings.load_settings("user://nonexistent_test_settings.cfg")
	assert_eq(_settings.resolution, Vector2i(1920, 1080))
	assert_eq(_settings.fullscreen, false)
	assert_eq(_settings.music_enabled, true)
	assert_eq(_settings.music_volume, 80)
	assert_eq(_settings.fx_enabled, true)
	assert_eq(_settings.fx_volume, 80)
	assert_eq(_settings.language, "fr")

func test_save_and_load_all_settings():
	_settings.resolution = Vector2i(1600, 900)
	_settings.fullscreen = true
	_settings.music_enabled = false
	_settings.music_volume = 10
	_settings.fx_enabled = false
	_settings.fx_volume = 0
	_settings.language = "en"
	_settings.save_settings(_test_cfg_path)

	var loaded = GameSettings.new()
	loaded.load_settings(_test_cfg_path)
	assert_eq(loaded.resolution, Vector2i(1600, 900))
	assert_eq(loaded.fullscreen, true)
	assert_eq(loaded.music_enabled, false)
	assert_eq(loaded.music_volume, 10)
	assert_eq(loaded.fx_enabled, false)
	assert_eq(loaded.fx_volume, 0)
	assert_eq(loaded.language, "en")


# --- Résolutions disponibles ---

func test_available_resolutions():
	var resolutions = GameSettings.AVAILABLE_RESOLUTIONS
	assert_eq(resolutions.size(), 4)
	assert_eq(resolutions[0], Vector2i(1920, 1080))
	assert_eq(resolutions[1], Vector2i(1600, 900))
	assert_eq(resolutions[2], Vector2i(1280, 720))
	assert_eq(resolutions[3], Vector2i(1024, 576))

func test_resolution_labels():
	var labels = GameSettings.RESOLUTION_LABELS
	assert_eq(labels.size(), 4)
	assert_true(labels[0].find("1920") >= 0)
	assert_true(labels[2].find("1280") >= 0)


# --- Vitesse typewriter ---

func test_typewriter_speeds_count():
	assert_eq(GameSettings.TYPEWRITER_SPEEDS.size(), 4)
	assert_eq(GameSettings.TYPEWRITER_SPEED_LABELS.size(), 4)

func test_typewriter_speed_values():
	assert_eq(GameSettings.TYPEWRITER_SPEEDS[0], 0.06)
	assert_eq(GameSettings.TYPEWRITER_SPEEDS[1], 0.03)
	assert_eq(GameSettings.TYPEWRITER_SPEEDS[2], 0.015)
	assert_eq(GameSettings.TYPEWRITER_SPEEDS[3], 0.0)


# --- autosave_enabled ---

func test_default_autosave_enabled():
	assert_eq(_settings.autosave_enabled, true)

func test_save_and_load_autosave_enabled_false():
	_settings.autosave_enabled = false
	_settings.save_settings(_test_cfg_path)
	var loaded = GameSettings.new()
	loaded.load_settings(_test_cfg_path)
	assert_eq(loaded.autosave_enabled, false)

func test_save_and_load_autosave_enabled_true():
	_settings.autosave_enabled = true
	_settings.save_settings(_test_cfg_path)
	var loaded = GameSettings.new()
	loaded.load_settings(_test_cfg_path)
	assert_eq(loaded.autosave_enabled, true)
