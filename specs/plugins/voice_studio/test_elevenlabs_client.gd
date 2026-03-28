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


# ── Validation generate_voice (single dialogue) ──────────────────────────────

func test_generate_voice_fails_without_config() -> void:
	watch_signals(_client)
	_client.generate_voice("voice-id", "Hello", "test-uuid")
	assert_signal_emitted(_client, "generation_failed")


func test_generate_voice_fails_without_api_key() -> void:
	var config := ElevenLabsConfig.new()
	_client.setup(config)
	watch_signals(_client)
	_client.generate_voice("voice-id", "Hello", "test-uuid")
	assert_signal_emitted(_client, "generation_failed")


func test_generate_voice_fails_with_empty_voice_id() -> void:
	var config := ElevenLabsConfig.new()
	config.set_api_key("test-key")
	_client.setup(config)
	watch_signals(_client)
	_client.generate_voice("", "Hello", "test-uuid")
	assert_signal_emitted(_client, "generation_failed")


func test_generate_voice_fails_with_empty_text() -> void:
	var config := ElevenLabsConfig.new()
	config.set_api_key("test-key")
	_client.setup(config)
	watch_signals(_client)
	_client.generate_voice("voice-id", "   ", "test-uuid")
	assert_signal_emitted(_client, "generation_failed")


# ── Validation generate_dialogue (multi-input) ───────────────────────────────

func test_generate_dialogue_fails_without_config() -> void:
	watch_signals(_client)
	_client.generate_dialogue([{"text": "Hello", "voice_id": "v1"}], "req-1")
	assert_signal_emitted(_client, "generation_failed")


func test_generate_dialogue_fails_with_empty_inputs() -> void:
	var config := ElevenLabsConfig.new()
	config.set_api_key("test-key")
	_client.setup(config)
	watch_signals(_client)
	_client.generate_dialogue([], "req-1")
	assert_signal_emitted(_client, "generation_failed")


func test_generate_dialogue_fails_with_missing_voice_id() -> void:
	var config := ElevenLabsConfig.new()
	config.set_api_key("test-key")
	_client.setup(config)
	watch_signals(_client)
	_client.generate_dialogue([{"text": "Hello", "voice_id": ""}], "req-1")
	assert_signal_emitted(_client, "generation_failed")


func test_generate_dialogue_fails_with_empty_text_in_input() -> void:
	var config := ElevenLabsConfig.new()
	config.set_api_key("test-key")
	_client.setup(config)
	watch_signals(_client)
	_client.generate_dialogue([{"text": "  ", "voice_id": "v1"}], "req-1")
	assert_signal_emitted(_client, "generation_failed")


# ── Static save/delete ────────────────────────────────────────────────────────

func test_save_mp3_creates_file() -> void:
	var data := PackedByteArray([0xFF, 0xFB, 0x90, 0x00])  # Fake MP3 header
	var result := ElevenLabsClientScript.save_mp3(data, TEST_MP3_PATH)
	assert_true(result, "save_mp3 should return true")
	assert_true(FileAccess.file_exists(TEST_MP3_PATH))
	var file := FileAccess.open(TEST_MP3_PATH, FileAccess.READ)
	assert_eq(file.get_length(), 4)
	file.close()


func test_delete_voice_file_removes_existing() -> void:
	var file := FileAccess.open(TEST_MP3_PATH, FileAccess.WRITE)
	file.store_8(0xFF)
	file.close()
	assert_true(FileAccess.file_exists(TEST_MP3_PATH))
	var result := ElevenLabsClientScript.delete_voice_file(TEST_MP3_PATH)
	assert_true(result)
	assert_false(FileAccess.file_exists(TEST_MP3_PATH))


func test_delete_nonexistent_file_returns_true() -> void:
	var result := ElevenLabsClientScript.delete_voice_file("user://nonexistent_voice.mp3")
	assert_true(result)
