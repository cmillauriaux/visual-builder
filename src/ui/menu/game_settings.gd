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
var language: String = ""  # "" = auto-détection au premier lancement
var auto_play_enabled: bool = false
var auto_play_delay: float = 2.0
var typewriter_speed: float = 0.03
var dialogue_opacity: int = 80
var autosave_enabled: bool = true
var ui_scale_mode: int = -1  # -1 = pas encore initialisé, utilise le défaut plateforme
var toolbar_visible: bool = true
var pwa_prompt_dismissed: bool = false

const TYPEWRITER_SPEEDS: Array[float] = [0.06, 0.03, 0.015, 0.0]
const TYPEWRITER_SPEED_LABELS: Array[String] = ["Lent", "Normal", "Rapide", "Instantané"]

const UI_SCALE_FACTORS: Array[float] = [1.25, 1.5, 2.0]
const UI_SCALE_LABELS: Array[String] = ["Petit", "Moyen", "Gros"]

## Mode Petit=0, Moyen=1, Gros=2
## Mobile (iOS/Android) et web mobile → Gros (2)
## Desktop et web desktop → Moyen (1)
static func get_default_ui_scale_mode() -> int:
	var os_name := OS.get_name()
	if os_name == "iOS" or os_name == "Android":
		return 2
	if os_name == "Web" and _is_mobile_browser():
		return 2
	return 1


static func _is_mobile_browser() -> bool:
	if OS.get_name() != "Web":
		return false
	if not ClassDB.class_exists(&"JavaScriptBridge"):
		return false
	var js = ClassDB.instantiate(&"JavaScriptBridge")
	if js == null:
		return false
	# Utiliser Engine.get_singleton ou un appel direct ne fonctionne pas en GDScript
	# pour les classes non-singleton. On utilise Expression pour évaluer dynamiquement.
	var expr := Expression.new()
	if expr.parse("JavaScriptBridge.eval('navigator.userAgent || \"\"')") != OK:
		return false
	var result = expr.execute()
	if expr.has_execute_failed() or result == null:
		return false
	var ua: String = str(result).to_lower()
	return ua.contains("mobile") or ua.contains("android") or ua.contains("iphone") or ua.contains("ipad")


func load_settings(path: String = SETTINGS_PATH) -> void:
	var cfg = ConfigFile.new()
	if cfg.load(path) != OK:
		ui_scale_mode = get_default_ui_scale_mode()
		return
	resolution.x = cfg.get_value("display", "resolution_x", 1920)
	resolution.y = cfg.get_value("display", "resolution_y", 1080)
	fullscreen = cfg.get_value("display", "fullscreen", false)
	dialogue_opacity = cfg.get_value("display", "dialogue_opacity", 80)
	music_enabled = cfg.get_value("audio", "music_enabled", true)
	music_volume = cfg.get_value("audio", "music_volume", 80)
	fx_enabled = cfg.get_value("audio", "fx_enabled", true)
	fx_volume = cfg.get_value("audio", "fx_volume", 80)
	language = cfg.get_value("general", "language", "")
	auto_play_enabled = cfg.get_value("gameplay", "auto_play_enabled", false)
	auto_play_delay = cfg.get_value("gameplay", "auto_play_delay", 2.0)
	typewriter_speed = cfg.get_value("gameplay", "typewriter_speed", 0.03)
	autosave_enabled = cfg.get_value("gameplay", "autosave_enabled", true)
	ui_scale_mode = cfg.get_value("display", "ui_scale_mode", get_default_ui_scale_mode())
	toolbar_visible = cfg.get_value("display", "toolbar_visible", true)
	pwa_prompt_dismissed = cfg.get_value("display", "pwa_prompt_dismissed", false)


func save_settings(path: String = SETTINGS_PATH) -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("display", "resolution_x", resolution.x)
	cfg.set_value("display", "resolution_y", resolution.y)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "dialogue_opacity", dialogue_opacity)
	cfg.set_value("audio", "music_enabled", music_enabled)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "fx_enabled", fx_enabled)
	cfg.set_value("audio", "fx_volume", fx_volume)
	cfg.set_value("general", "language", language)
	cfg.set_value("gameplay", "auto_play_enabled", auto_play_enabled)
	cfg.set_value("gameplay", "auto_play_delay", auto_play_delay)
	cfg.set_value("gameplay", "typewriter_speed", typewriter_speed)
	cfg.set_value("gameplay", "autosave_enabled", autosave_enabled)
	cfg.set_value("display", "ui_scale_mode", ui_scale_mode)
	cfg.set_value("display", "toolbar_visible", toolbar_visible)
	cfg.set_value("display", "pwa_prompt_dismissed", pwa_prompt_dismissed)
	cfg.save(path)


func get_ui_scale_factor() -> float:
	var mode := ui_scale_mode if ui_scale_mode >= 0 else get_default_ui_scale_mode()
	if mode >= 0 and mode < UI_SCALE_FACTORS.size():
		return UI_SCALE_FACTORS[mode]
	return 1.0


func is_language_auto() -> bool:
	return language == ""


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
