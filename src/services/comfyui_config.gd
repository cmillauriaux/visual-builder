extends RefCounted

## Persistance de la configuration ComfyUI (URL + token) via ConfigFile.

const DEFAULT_URL := "http://localhost:8188"
const DEFAULT_TOKEN := ""
const DEFAULT_PATH := "user://comfyui_config.cfg"

var _url: String = DEFAULT_URL
var _token: String = ""

func get_url() -> String:
	return _url

func set_url(url: String) -> void:
	_url = url

func get_token() -> String:
	return _token

func set_token(token: String) -> void:
	_token = token

func get_full_url(endpoint: String) -> String:
	var base = _url.rstrip("/")
	return base + endpoint

func get_auth_headers() -> PackedStringArray:
	if _token != "":
		return PackedStringArray(["Authorization: Bearer " + _token])
	return PackedStringArray([])

func save_to(path: String = DEFAULT_PATH) -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("comfyui", "url", _url)
	cfg.set_value("comfyui", "token", _token)
	cfg.save(path)

func load_from(path: String = DEFAULT_PATH) -> void:
	var cfg = ConfigFile.new()
	var err = cfg.load(path)
	if err != OK:
		return
	_url = cfg.get_value("comfyui", "url", DEFAULT_URL)
	_token = cfg.get_value("comfyui", "token", DEFAULT_TOKEN)
