extends RefCounted

## Modèle de données des réglages du jeu + persistance via ConfigFile.

const SETTINGS_PATH := "user://settings.cfg"

const AVAILABLE_RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1920, 1080),
	Vector2i(1600, 900),
	Vector2i(1280, 720),
	Vector2i(1024, 576),
]

const RESOLUTION_LABELS: Array[String] = [
	"1920×1080 (Full HD)",
	"1600×900",
	"1280×720 (HD)",
	"1024×576",
]

var resolution: Vector2i = Vector2i(1920, 1080)
var fullscreen: bool = false
var music_enabled: bool = true
var music_volume: int = 80
var fx_enabled: bool = true
var fx_volume: int = 80
var language: String = "fr"
var auto_play_enabled: bool = false
var auto_play_delay: float = 2.0


func load_settings(path: String = SETTINGS_PATH) -> void:
	var cfg = ConfigFile.new()
	if cfg.load(path) != OK:
		return
	resolution.x = cfg.get_value("display", "resolution_x", 1920)
	resolution.y = cfg.get_value("display", "resolution_y", 1080)
	fullscreen = cfg.get_value("display", "fullscreen", false)
	music_enabled = cfg.get_value("audio", "music_enabled", true)
	music_volume = cfg.get_value("audio", "music_volume", 80)
	fx_enabled = cfg.get_value("audio", "fx_enabled", true)
	fx_volume = cfg.get_value("audio", "fx_volume", 80)
	language = cfg.get_value("general", "language", "fr")
	auto_play_enabled = cfg.get_value("gameplay", "auto_play_enabled", false)
	auto_play_delay = cfg.get_value("gameplay", "auto_play_delay", 2.0)


func save_settings(path: String = SETTINGS_PATH) -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("display", "resolution_x", resolution.x)
	cfg.set_value("display", "resolution_y", resolution.y)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("audio", "music_enabled", music_enabled)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "fx_enabled", fx_enabled)
	cfg.set_value("audio", "fx_volume", fx_volume)
	cfg.set_value("general", "language", language)
	cfg.set_value("gameplay", "auto_play_enabled", auto_play_enabled)
	cfg.set_value("gameplay", "auto_play_delay", auto_play_delay)
	cfg.save(path)


func apply_settings() -> void:
	# Résolution
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(resolution)

	# Audio — Music bus
	var music_idx = AudioServer.get_bus_index("Music")
	if music_idx >= 0:
		AudioServer.set_bus_mute(music_idx, not music_enabled)
		AudioServer.set_bus_volume_db(music_idx, linear_to_db(music_volume / 100.0))

	# Audio — FX bus
	var fx_idx = AudioServer.get_bus_index("FX")
	if fx_idx >= 0:
		AudioServer.set_bus_mute(fx_idx, not fx_enabled)
		AudioServer.set_bus_volume_db(fx_idx, linear_to_db(fx_volume / 100.0))

	# Langue
	TranslationServer.set_locale(language)
