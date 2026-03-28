extends RefCounted

## Persistance de la configuration ElevenLabs (API key) via ConfigFile.

const DEFAULT_API_KEY := ""
const DEFAULT_MODEL_ID := "eleven_multilingual_v2"
const DEFAULT_PATH := "user://elevenlabs_config.cfg"

var _api_key: String = DEFAULT_API_KEY
var _model_id: String = DEFAULT_MODEL_ID


func get_api_key() -> String:
	return _api_key


func set_api_key(key: String) -> void:
	_api_key = key


func get_model_id() -> String:
	return _model_id


func set_model_id(model: String) -> void:
	_model_id = model


func get_auth_headers() -> PackedStringArray:
	var headers := PackedStringArray([
		"Content-Type: application/json",
	])
	if _api_key != "":
		headers.append("xi-api-key: " + _api_key)
	return headers


func save_to(path: String = DEFAULT_PATH) -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("elevenlabs", "api_key", _api_key)
	cfg.set_value("elevenlabs", "model_id", _model_id)
	cfg.save(path)


func load_from(path: String = DEFAULT_PATH) -> void:
	var cfg = ConfigFile.new()
	var err = cfg.load(path)
	if err != OK:
		return
	_api_key = cfg.get_value("elevenlabs", "api_key", DEFAULT_API_KEY)
	_model_id = cfg.get_value("elevenlabs", "model_id", DEFAULT_MODEL_ID)
