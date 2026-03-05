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
