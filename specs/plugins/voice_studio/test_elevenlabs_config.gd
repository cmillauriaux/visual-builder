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


func test_default_model_id_is_eleven_v3() -> void:
	assert_eq(_config.get_model_id(), "eleven_v3")


func test_default_language_code_is_empty() -> void:
	assert_eq(_config.get_language_code(), "")


# ── Getters / Setters ────────────────────────────────────────────────────────

func test_set_and_get_api_key() -> void:
	_config.set_api_key("test-key-123")
	assert_eq(_config.get_api_key(), "test-key-123")


func test_set_and_get_model_id() -> void:
	_config.set_model_id("eleven_turbo_v2_5")
	assert_eq(_config.get_model_id(), "eleven_turbo_v2_5")


func test_set_and_get_language_code() -> void:
	_config.set_language_code("fr")
	assert_eq(_config.get_language_code(), "fr")


# ── Auth headers ──────────────────────────────────────────────────────────────

func test_auth_headers_with_key() -> void:
	_config.set_api_key("my-key")
	var headers := _config.get_auth_headers()
	assert_true(headers.size() >= 2)
	var has_content_type := false
	var has_api_key := false
	for h in headers:
		if h == "Content-Type: application/json":
			has_content_type = true
		if h == "xi-api-key: my-key":
			has_api_key = true
	assert_true(has_content_type, "Should include Content-Type header")
	assert_true(has_api_key, "Should include xi-api-key header")


func test_auth_headers_without_key() -> void:
	var headers := _config.get_auth_headers()
	assert_eq(headers.size(), 1, "Only Content-Type when no API key")
	assert_eq(headers[0], "Content-Type: application/json")


# ── Persistance ───────────────────────────────────────────────────────────────

func test_save_and_load() -> void:
	_config.set_api_key("persisted-key")
	_config.set_model_id("custom_model")
	_config.set_language_code("es")
	_config.save_to(TEST_PATH)

	var loaded := ElevenLabsConfig.new()
	loaded.load_from(TEST_PATH)
	assert_eq(loaded.get_api_key(), "persisted-key")
	assert_eq(loaded.get_model_id(), "custom_model")
	assert_eq(loaded.get_language_code(), "es")


func test_load_missing_file_keeps_defaults() -> void:
	_config.load_from("user://nonexistent_elevenlabs.cfg")
	assert_eq(_config.get_api_key(), "")
	assert_eq(_config.get_model_id(), "eleven_v3")
	assert_eq(_config.get_language_code(), "")


func test_save_then_modify_then_reload() -> void:
	_config.set_api_key("key1")
	_config.save_to(TEST_PATH)
	_config.set_api_key("key2")
	assert_eq(_config.get_api_key(), "key2")
	_config.load_from(TEST_PATH)
	assert_eq(_config.get_api_key(), "key1")
