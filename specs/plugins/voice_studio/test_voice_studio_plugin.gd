extends GutTest

const VoiceStudioPlugin = preload("res://plugins/voice_studio/plugin.gd")
const VoiceStudioGamePlugin = preload("res://plugins/voice_studio/game_plugin.gd")
const Contributions = preload("res://src/plugins/contributions.gd")


# ── Editor Plugin ─────────────────────────────────────────────────────────────

func test_plugin_name() -> void:
	var plugin := VoiceStudioPlugin.new()
	assert_eq(plugin.get_plugin_name(), "voice_studio")


func test_plugin_has_sequence_tab() -> void:
	var plugin := VoiceStudioPlugin.new()
	var tabs := plugin.get_sequence_tabs()
	assert_eq(tabs.size(), 1)
	assert_eq(tabs[0].title, "Voix")


func test_sequence_tab_has_create_callback() -> void:
	var plugin := VoiceStudioPlugin.new()
	var tabs := plugin.get_sequence_tabs()
	assert_true(tabs[0].create_tab.is_valid())


# ── Game Plugin ───────────────────────────────────────────────────────────────

func test_game_plugin_name() -> void:
	var plugin := VoiceStudioGamePlugin.new()
	assert_eq(plugin.get_plugin_name(), "voice_studio")


func test_game_plugin_description() -> void:
	var plugin := VoiceStudioGamePlugin.new()
	assert_ne(plugin.get_plugin_description(), "")


func test_game_plugin_not_configurable() -> void:
	var plugin := VoiceStudioGamePlugin.new()
	assert_false(plugin.is_configurable())


func test_game_plugin_folder() -> void:
	var plugin := VoiceStudioGamePlugin.new()
	assert_eq(plugin.get_plugin_folder(), "voice_studio")


func test_game_plugin_has_editor_config() -> void:
	var plugin := VoiceStudioGamePlugin.new()
	var controls := plugin.get_editor_config_controls()
	assert_eq(controls.size(), 1)
	assert_true(controls[0].create_control.is_valid())


# ── Voice ID lookup ───────────────────────────────────────────────────────────

func test_get_voice_id_for_known_character() -> void:
	var settings := {
		"characters": [
			{"name": "Narrateur", "voice_id": "abc123"},
			{"name": "Héros", "voice_id": "def456"},
		]
	}
	assert_eq(VoiceStudioGamePlugin.get_voice_id_for_character(settings, "Narrateur"), "abc123")
	assert_eq(VoiceStudioGamePlugin.get_voice_id_for_character(settings, "Héros"), "def456")


func test_get_voice_id_for_unknown_character() -> void:
	var settings := {
		"characters": [
			{"name": "Narrateur", "voice_id": "abc123"},
		]
	}
	assert_eq(VoiceStudioGamePlugin.get_voice_id_for_character(settings, "Inconnu"), "")


func test_get_voice_id_with_empty_settings() -> void:
	assert_eq(VoiceStudioGamePlugin.get_voice_id_for_character({}, "Test"), "")


func test_get_voice_id_with_no_characters_key() -> void:
	var settings := {"other": "value"}
	assert_eq(VoiceStudioGamePlugin.get_voice_id_for_character(settings, "Test"), "")


# ── Editor config read/write ──────────────────────────────────────────────────

func test_editor_config_creates_control() -> void:
	var plugin := VoiceStudioGamePlugin.new()
	var settings := {"characters": [{"name": "Hero", "voice_id": "v1"}]}
	var controls := plugin.get_editor_config_controls()
	var ctrl: Control = controls[0].create_control.call(settings)
	assert_not_null(ctrl)
	assert_true(ctrl.has_meta("read_config"))
	ctrl.queue_free()


func test_editor_config_roundtrip() -> void:
	var plugin := VoiceStudioGamePlugin.new()
	var initial := {"characters": [{"name": "Knight", "voice_id": "kn-001"}]}
	var controls := plugin.get_editor_config_controls()
	var ctrl: Control = controls[0].create_control.call(initial)
	# Need to add to scene tree for deferred operations
	add_child_autofree(ctrl)
	await get_tree().process_frame
	var result := plugin.read_editor_config(ctrl)
	assert_true(result.has("characters"))
	assert_eq(result["characters"].size(), 1)
	assert_eq(result["characters"][0]["name"], "Knight")
	assert_eq(result["characters"][0]["voice_id"], "kn-001")


func test_read_editor_config_null_returns_empty() -> void:
	var plugin := VoiceStudioGamePlugin.new()
	assert_eq(plugin.read_editor_config(null), {})
