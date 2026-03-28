extends GutTest

const ElevenLabsClientScript = preload("res://plugins/voice_studio/elevenlabs_client.gd")
const ElevenLabsConfig = preload("res://plugins/voice_studio/elevenlabs_config.gd")

var _client: Node
const TEST_MP3_PATH := "user://test_voice.mp3"


func before_each() -> void:
	_client = Node.new()
	_client.set_script(ElevenLabsClientScript)
	add_child_autofree(_client)


func after_each() -> void:
	if FileAccess.file_exists(TEST_MP3_PATH):
		DirAccess.remove_absolute(TEST_MP3_PATH)


# ── Setup ─────────────────────────────────────────────────────────────────────

func test_is_not_generating_by_default() -> void:
	assert_false(_client.is_generating())

func test_setup_stores_config() -> void:
	var config := ElevenLabsConfig.new()
	_client.setup(config)
	assert_false(_client.is_generating())


# ── Validation ────────────────────────────────────────────────────────────────

func test_fails_without_config() -> void:
	watch_signals(_client)
	_client.generate_voice("vid", "Hello", "uuid-1")
	assert_signal_emitted(_client, "generation_failed")

func test_fails_without_api_key() -> void:
	_client.setup(ElevenLabsConfig.new())
	watch_signals(_client)
	_client.generate_voice("vid", "Hello", "uuid-1")
	assert_signal_emitted(_client, "generation_failed")

func test_fails_with_empty_voice_id() -> void:
	var c := ElevenLabsConfig.new()
	c.set_api_key("k")
	_client.setup(c)
	watch_signals(_client)
	_client.generate_voice("", "Hello", "uuid-1")
	assert_signal_emitted(_client, "generation_failed")

func test_fails_with_empty_text() -> void:
	var c := ElevenLabsConfig.new()
	c.set_api_key("k")
	_client.setup(c)
	watch_signals(_client)
	_client.generate_voice("vid", "   ", "uuid-1")
	assert_signal_emitted(_client, "generation_failed")

func test_accepts_voice_settings_override() -> void:
	var c := ElevenLabsConfig.new()
	c.set_api_key("k")
	_client.setup(c)
	# Should not fail validation (will fail at HTTP level but that's fine)
	watch_signals(_client)
	_client.generate_voice("vid", "Hello", "uuid-1", {"speed": 1.5}, "prev", "next", ["rid1"])
	# generation_progress should be emitted since validation passed
	assert_signal_emitted(_client, "generation_progress")


# ── Request ID extraction ─────────────────────────────────────────────────────

func test_extract_request_id_from_headers() -> void:
	var headers := PackedStringArray([
		"Content-Type: audio/mpeg",
		"request-id: abc-123-def",
	])
	assert_eq(ElevenLabsClientScript._extract_request_id(headers), "abc-123-def")

func test_extract_request_id_x_prefix() -> void:
	var headers := PackedStringArray([
		"X-Request-Id: xyz-789",
	])
	assert_eq(ElevenLabsClientScript._extract_request_id(headers), "xyz-789")

func test_extract_request_id_missing() -> void:
	var headers := PackedStringArray(["Content-Type: audio/mpeg"])
	assert_eq(ElevenLabsClientScript._extract_request_id(headers), "")


# ── Static save/delete ────────────────────────────────────────────────────────

func test_save_mp3_creates_file() -> void:
	var data := PackedByteArray([0xFF, 0xFB, 0x90, 0x00])
	assert_true(ElevenLabsClientScript.save_mp3(data, TEST_MP3_PATH))
	assert_true(FileAccess.file_exists(TEST_MP3_PATH))

func test_delete_voice_file_removes_existing() -> void:
	var file := FileAccess.open(TEST_MP3_PATH, FileAccess.WRITE)
	file.store_8(0xFF)
	file.close()
	assert_true(ElevenLabsClientScript.delete_voice_file(TEST_MP3_PATH))
	assert_false(FileAccess.file_exists(TEST_MP3_PATH))

func test_delete_nonexistent_returns_true() -> void:
	assert_true(ElevenLabsClientScript.delete_voice_file("user://nope.mp3"))
