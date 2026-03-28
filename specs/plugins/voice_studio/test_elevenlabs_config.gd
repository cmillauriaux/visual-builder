extends GutTest

const ElevenLabsConfig = preload("res://plugins/voice_studio/elevenlabs_config.gd")

var _config: ElevenLabsConfig
const TEST_PATH := "user://test_elevenlabs_config.cfg"


func before_each() -> void:
	_config = ElevenLabsConfig.new()


func after_each() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(TEST_PATH)


# ── Defaults ─────────────────────────────────────────────────────────────────

func test_default_api_key_is_empty() -> void:
	assert_eq(_config.get_api_key(), "")

func test_default_model_id() -> void:
	assert_eq(_config.get_model_id(), "eleven_v3")

func test_default_output_format() -> void:
	assert_eq(_config.get_output_format(), "mp3_44100_128")

func test_default_stability() -> void:
	assert_almost_eq(_config.get_stability(), 0.5, 0.001)

func test_default_similarity_boost() -> void:
	assert_almost_eq(_config.get_similarity_boost(), 0.75, 0.001)

func test_default_style() -> void:
	assert_almost_eq(_config.get_style(), 0.0, 0.001)

func test_default_speed() -> void:
	assert_almost_eq(_config.get_speed(), 1.0, 0.001)

func test_default_use_speaker_boost() -> void:
	assert_true(_config.get_use_speaker_boost())

func test_default_language_code() -> void:
	assert_eq(_config.get_language_code(), "")


# ── Getters / Setters ────────────────────────────────────────────────────────

func test_set_and_get_api_key() -> void:
	_config.set_api_key("test-key-123")
	assert_eq(_config.get_api_key(), "test-key-123")

func test_set_and_get_speed() -> void:
	_config.set_speed(1.5)
	assert_almost_eq(_config.get_speed(), 1.5, 0.001)

func test_set_and_get_output_format() -> void:
	_config.set_output_format("mp3_44100_192")
	assert_eq(_config.get_output_format(), "mp3_44100_192")


# ── Voice settings dict ──────────────────────────────────────────────────────

func test_get_voice_settings() -> void:
	_config.set_stability(0.3)
	_config.set_speed(1.2)
	var vs := _config.get_voice_settings()
	assert_almost_eq(vs["stability"], 0.3, 0.001)
	assert_almost_eq(vs["speed"], 1.2, 0.001)
	assert_true(vs.has("similarity_boost"))
	assert_true(vs.has("style"))
	assert_true(vs.has("use_speaker_boost"))


# ── Auth headers ──────────────────────────────────────────────────────────────

func test_auth_headers_with_key() -> void:
	_config.set_api_key("my-key")
	var headers := _config.get_auth_headers()
	var has_api_key := false
	for h in headers:
		if h == "xi-api-key: my-key":
			has_api_key = true
	assert_true(has_api_key)

func test_auth_headers_without_key() -> void:
	var headers := _config.get_auth_headers()
	assert_eq(headers.size(), 1)


# ── Persistance ───────────────────────────────────────────────────────────────

func test_save_and_load_all_fields() -> void:
	_config.set_api_key("pk")
	_config.set_model_id("m1")
	_config.set_language_code("fr")
	_config.set_output_format("wav_44100")
	_config.set_stability(0.2)
	_config.set_similarity_boost(0.9)
	_config.set_style(0.4)
	_config.set_speed(1.8)
	_config.set_use_speaker_boost(false)
	_config.save_to(TEST_PATH)

	var loaded := ElevenLabsConfig.new()
	loaded.load_from(TEST_PATH)
	assert_eq(loaded.get_api_key(), "pk")
	assert_eq(loaded.get_model_id(), "m1")
	assert_eq(loaded.get_language_code(), "fr")
	assert_eq(loaded.get_output_format(), "wav_44100")
	assert_almost_eq(loaded.get_stability(), 0.2, 0.001)
	assert_almost_eq(loaded.get_similarity_boost(), 0.9, 0.001)
	assert_almost_eq(loaded.get_style(), 0.4, 0.001)
	assert_almost_eq(loaded.get_speed(), 1.8, 0.001)
	assert_false(loaded.get_use_speaker_boost())

func test_load_missing_file_keeps_defaults() -> void:
	_config.load_from("user://nonexistent.cfg")
	assert_eq(_config.get_api_key(), "")
	assert_eq(_config.get_model_id(), "eleven_v3")
	assert_almost_eq(_config.get_speed(), 1.0, 0.001)
