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


# --- ui_scale_mode ---

func test_default_ui_scale_mode():
	assert_eq(_settings.ui_scale_mode, -1, "ui_scale_mode vaut -1 avant chargement (défaut plateforme)")

func test_save_and_load_ui_scale_mode_medium():
	_settings.ui_scale_mode = 1
	_settings.save_settings(_test_cfg_path)
	var loaded = GameSettings.new()
	loaded.load_settings(_test_cfg_path)
	assert_eq(loaded.ui_scale_mode, 1)

func test_save_and_load_ui_scale_mode_large():
	_settings.ui_scale_mode = 2
	_settings.save_settings(_test_cfg_path)
	var loaded = GameSettings.new()
	loaded.load_settings(_test_cfg_path)
	assert_eq(loaded.ui_scale_mode, 2)

func test_ui_scale_factors_count():
	assert_eq(GameSettings.UI_SCALE_FACTORS.size(), 3)

func test_ui_scale_factors_values():
	assert_eq(GameSettings.UI_SCALE_FACTORS[0], 1.25)
	assert_eq(GameSettings.UI_SCALE_FACTORS[1], 1.5)
	assert_eq(GameSettings.UI_SCALE_FACTORS[2], 2.0)

func test_ui_scale_labels_count():
	assert_eq(GameSettings.UI_SCALE_LABELS.size(), 3)

func test_ui_scale_labels_values():
	assert_eq(GameSettings.UI_SCALE_LABELS[0], "Petit")
	assert_eq(GameSettings.UI_SCALE_LABELS[1], "Moyen")
	assert_eq(GameSettings.UI_SCALE_LABELS[2], "Gros")

func test_get_ui_scale_factor_small():
	_settings.ui_scale_mode = 0
	assert_eq(_settings.get_ui_scale_factor(), 1.25)

func test_get_ui_scale_factor_medium():
	_settings.ui_scale_mode = 1
	assert_eq(_settings.get_ui_scale_factor(), 1.5)

func test_get_ui_scale_factor_large():
	_settings.ui_scale_mode = 2
	assert_eq(_settings.get_ui_scale_factor(), 2.0)

func test_get_ui_scale_factor_invalid_returns_default():
	_settings.ui_scale_mode = 99
	assert_eq(_settings.get_ui_scale_factor(), 1.0)

func test_get_ui_scale_factor_minus_one_uses_platform_default():
	_settings.ui_scale_mode = -1
	var expected_mode := GameSettings.get_default_ui_scale_mode()
	assert_eq(_settings.get_ui_scale_factor(), GameSettings.UI_SCALE_FACTORS[expected_mode])

func test_get_default_ui_scale_mode_returns_valid_index():
	var mode := GameSettings.get_default_ui_scale_mode()
	assert_true(mode >= 0 and mode < GameSettings.UI_SCALE_FACTORS.size(),
		"default mode %d doit être un index valide" % mode)

func test_load_without_file_uses_platform_default():
	_settings.load_settings("user://nonexistent_ui_scale_test.cfg")
	var expected := GameSettings.get_default_ui_scale_mode()
	assert_eq(_settings.ui_scale_mode, expected,
		"Sans fichier config, ui_scale_mode doit être le défaut plateforme")


# --- toolbar_visible ---

func test_default_toolbar_visible():
	assert_eq(_settings.toolbar_visible, true)

func test_save_and_load_toolbar_visible_false():
	_settings.toolbar_visible = false
	_settings.save_settings(_test_cfg_path)
	var loaded = GameSettings.new()
	loaded.load_settings(_test_cfg_path)
	assert_eq(loaded.toolbar_visible, false)

func test_save_and_load_toolbar_visible_true():
	_settings.toolbar_visible = true
	_settings.save_settings(_test_cfg_path)
	var loaded = GameSettings.new()
	loaded.load_settings(_test_cfg_path)
	assert_eq(loaded.toolbar_visible, true)
