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


# ── Voice ID lookup (avec langue) ────────────────────────────────────────────

func test_get_voice_id_for_character_with_language() -> void:
	var settings := {
		"voices": [
			{"character": "Narrateur", "language": "fr", "voice_id": "fr-narr"},
			{"character": "Narrateur", "language": "en", "voice_id": "en-narr"},
			{"character": "Héros", "language": "fr", "voice_id": "fr-hero"},
		]
	}
	assert_eq(VoiceStudioGamePlugin.get_voice_id_for_character(settings, "Narrateur", "fr"), "fr-narr")
	assert_eq(VoiceStudioGamePlugin.get_voice_id_for_character(settings, "Narrateur", "en"), "en-narr")
	assert_eq(VoiceStudioGamePlugin.get_voice_id_for_character(settings, "Héros", "fr"), "fr-hero")


func test_get_voice_id_fallback_without_language() -> void:
	var settings := {
		"voices": [
			{"character": "Narrateur", "language": "fr", "voice_id": "fr-narr"},
		]
	}
	# Sans filtre de langue, retourne le premier match
	assert_eq(VoiceStudioGamePlugin.get_voice_id_for_character(settings, "Narrateur"), "fr-narr")


func test_get_voice_id_for_unknown_character() -> void:
	var settings := {
		"voices": [
			{"character": "Narrateur", "language": "fr", "voice_id": "abc123"},
		]
	}
	assert_eq(VoiceStudioGamePlugin.get_voice_id_for_character(settings, "Inconnu", "fr"), "")


func test_get_voice_id_for_unknown_language() -> void:
	var settings := {
		"voices": [
			{"character": "Narrateur", "language": "fr", "voice_id": "abc123"},
		]
	}
	# Langue inconnue : fallback sur premier match du personnage
	assert_eq(VoiceStudioGamePlugin.get_voice_id_for_character(settings, "Narrateur", "de"), "abc123")


func test_get_voice_id_with_empty_settings() -> void:
	assert_eq(VoiceStudioGamePlugin.get_voice_id_for_character({}, "Test", "fr"), "")


func test_get_voice_id_with_no_voices_key() -> void:
	var settings := {"other": "value"}
	assert_eq(VoiceStudioGamePlugin.get_voice_id_for_character(settings, "Test", "fr"), "")


# ── Available languages ───────────────────────────────────────────────────────

func test_get_available_languages() -> void:
	var settings := {
		"voices": [
			{"character": "A", "language": "fr", "voice_id": "v1"},
			{"character": "A", "language": "en", "voice_id": "v2"},
			{"character": "B", "language": "fr", "voice_id": "v3"},
			{"character": "C", "language": "es", "voice_id": "v4"},
		]
	}
	var langs := VoiceStudioGamePlugin.get_available_languages(settings)
	assert_eq(langs.size(), 3)
	assert_true("fr" in langs)
	assert_true("en" in langs)
	assert_true("es" in langs)


func test_get_available_languages_empty() -> void:
	var langs := VoiceStudioGamePlugin.get_available_languages({})
	assert_eq(langs.size(), 0)


func test_get_available_languages_no_duplicates() -> void:
	var settings := {
		"voices": [
			{"character": "A", "language": "fr", "voice_id": "v1"},
			{"character": "B", "language": "fr", "voice_id": "v2"},
		]
	}
	var langs := VoiceStudioGamePlugin.get_available_languages(settings)
	assert_eq(langs.size(), 1)
	assert_eq(langs[0], "fr")


# ── Editor config read/write ──────────────────────────────────────────────────

func test_editor_config_creates_control() -> void:
	var plugin := VoiceStudioGamePlugin.new()
	var settings := {"voices": [{"character": "Hero", "language": "fr", "voice_id": "v1"}]}
	var controls := plugin.get_editor_config_controls()
	var ctrl: Control = controls[0].create_control.call(settings)
	assert_not_null(ctrl)
	assert_true(ctrl.has_meta("read_config"))
	ctrl.queue_free()


func test_editor_config_roundtrip() -> void:
	var plugin := VoiceStudioGamePlugin.new()
	var initial := {"voices": [{"character": "Knight", "language": "en", "voice_id": "kn-001"}]}
	var controls := plugin.get_editor_config_controls()
	var ctrl: Control = controls[0].create_control.call(initial)
	add_child_autofree(ctrl)
	await get_tree().process_frame
	var result := plugin.read_editor_config(ctrl)
	assert_true(result.has("voices"))
	assert_eq(result["voices"].size(), 1)
	assert_eq(result["voices"][0]["character"], "Knight")
	assert_eq(result["voices"][0]["language"], "en")
	assert_eq(result["voices"][0]["voice_id"], "kn-001")


func test_read_editor_config_null_returns_empty() -> void:
	var plugin := VoiceStudioGamePlugin.new()
	assert_eq(plugin.read_editor_config(null), {})
