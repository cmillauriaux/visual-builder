extends RefCounted

## Persistance de la configuration ElevenLabs (API key, modèle, voice settings) via ConfigFile.

const DEFAULT_API_KEY := ""
const DEFAULT_MODEL_ID := "eleven_v3"
const DEFAULT_LANGUAGE_CODE := ""
const DEFAULT_OUTPUT_FORMAT := "mp3_44100_128"
const DEFAULT_STABILITY := 0.5
const DEFAULT_SIMILARITY_BOOST := 0.75
const DEFAULT_STYLE := 0.0
const DEFAULT_SPEED := 1.0
const DEFAULT_USE_SPEAKER_BOOST := true
const DEFAULT_PATH := "user://elevenlabs_config.cfg"

const OUTPUT_FORMATS := [
	"mp3_22050_32", "mp3_44100_32", "mp3_44100_64", "mp3_44100_96",
	"mp3_44100_128", "mp3_44100_192",
	"pcm_16000", "pcm_22050", "pcm_24000", "pcm_44100",
	"wav_44100",
]

var _api_key: String = DEFAULT_API_KEY
var _model_id: String = DEFAULT_MODEL_ID
var _language_code: String = DEFAULT_LANGUAGE_CODE
var _output_format: String = DEFAULT_OUTPUT_FORMAT
var _stability: float = DEFAULT_STABILITY
var _similarity_boost: float = DEFAULT_SIMILARITY_BOOST
var _style: float = DEFAULT_STYLE
var _speed: float = DEFAULT_SPEED
var _use_speaker_boost: bool = DEFAULT_USE_SPEAKER_BOOST


func get_api_key() -> String: return _api_key
func set_api_key(v: String) -> void: _api_key = v

func get_model_id() -> String: return _model_id
func set_model_id(v: String) -> void: _model_id = v

func get_language_code() -> String: return _language_code
func set_language_code(v: String) -> void: _language_code = v

func get_output_format() -> String: return _output_format
func set_output_format(v: String) -> void: _output_format = v

func get_stability() -> float: return _stability
func set_stability(v: float) -> void: _stability = v

func get_similarity_boost() -> float: return _similarity_boost
func set_similarity_boost(v: float) -> void: _similarity_boost = v

func get_style() -> float: return _style
func set_style(v: float) -> void: _style = v

func get_speed() -> float: return _speed
func set_speed(v: float) -> void: _speed = v

func get_use_speaker_boost() -> bool: return _use_speaker_boost
func set_use_speaker_boost(v: bool) -> void: _use_speaker_boost = v


func get_voice_settings() -> Dictionary:
	return {
		"stability": _stability,
		"similarity_boost": _similarity_boost,
		"style": _style,
		"speed": _speed,
		"use_speaker_boost": _use_speaker_boost,
	}


func get_auth_headers() -> PackedStringArray:
	var headers := PackedStringArray(["Content-Type: application/json"])
	if _api_key != "":
		headers.append("xi-api-key: " + _api_key)
	return headers


func save_to(path: String = DEFAULT_PATH) -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("elevenlabs", "api_key", _api_key)
	cfg.set_value("elevenlabs", "model_id", _model_id)
	cfg.set_value("elevenlabs", "language_code", _language_code)
	cfg.set_value("elevenlabs", "output_format", _output_format)
	cfg.set_value("voice", "stability", _stability)
	cfg.set_value("voice", "similarity_boost", _similarity_boost)
	cfg.set_value("voice", "style", _style)
	cfg.set_value("voice", "speed", _speed)
	cfg.set_value("voice", "use_speaker_boost", _use_speaker_boost)
	cfg.save(path)


func load_from(path: String = DEFAULT_PATH) -> void:
	var cfg = ConfigFile.new()
	if cfg.load(path) != OK:
		return
	_api_key = cfg.get_value("elevenlabs", "api_key", DEFAULT_API_KEY)
	_model_id = cfg.get_value("elevenlabs", "model_id", DEFAULT_MODEL_ID)
	_language_code = cfg.get_value("elevenlabs", "language_code", DEFAULT_LANGUAGE_CODE)
	_output_format = cfg.get_value("elevenlabs", "output_format", DEFAULT_OUTPUT_FORMAT)
	_stability = cfg.get_value("voice", "stability", DEFAULT_STABILITY)
	_similarity_boost = cfg.get_value("voice", "similarity_boost", DEFAULT_SIMILARITY_BOOST)
	_style = cfg.get_value("voice", "style", DEFAULT_STYLE)
	_speed = cfg.get_value("voice", "speed", DEFAULT_SPEED)
	_use_speaker_boost = cfg.get_value("voice", "use_speaker_boost", DEFAULT_USE_SPEAKER_BOOST)
