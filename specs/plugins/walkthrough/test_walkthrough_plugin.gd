extends GutTest

const WalkthroughPlugin = preload("res://plugins/walkthrough/game_plugin.gd")
const Choice = preload("res://src/models/choice.gd")

var _plugin: WalkthroughPlugin


func before_each() -> void:
	_plugin = WalkthroughPlugin.new()
	# Nettoyer le fichier de persistance de test
	if FileAccess.file_exists("user://walkthrough.json"):
		DirAccess.remove_absolute("user://walkthrough.json")


func after_each() -> void:
	if FileAccess.file_exists("user://walkthrough.json"):
		DirAccess.remove_absolute("user://walkthrough.json")


# ── Helpers ───────────────────────────────────────────────────────────────────

func _create_context(activation_code: String = "TEST123") -> RefCounted:
	var story = RefCounted.new()
	var plugin_settings = {}
	if activation_code != "":
		plugin_settings["walkthrough"] = {"activation_code": activation_code}
	story.set_meta("plugin_settings", plugin_settings)
	# Mock minimal de story
	var ctx = RefCounted.new()
	ctx.set_meta("_story", story)
	return ctx


func _create_full_context(activation_code: String = "TEST123") -> Object:
	# Retourne un objet avec la propriété story accessible
	var story_data = {"plugin_settings": {}}
	if activation_code != "":
		story_data["plugin_settings"]["walkthrough"] = {"activation_code": activation_code}

	var ctx = RefCounted.new()
	# Simuler story comme un dict-like
	var story_obj = RefCounted.new()
	story_obj.set_meta("plugin_settings_dict", story_data["plugin_settings"])
	ctx.set_meta("story_obj", story_obj)
	return ctx


func _make_plugin_with_settings(activation_code: String) -> WalkthroughPlugin:
	var p = WalkthroughPlugin.new()
	p.set_meta("_test_settings", {"activation_code": activation_code})
	return p


# ── Tests identité du plugin ──────────────────────────────────────────────────

func test_plugin_name():
	assert_eq(_plugin.get_plugin_name(), "walkthrough")


func test_plugin_description():
	assert_ne(_plugin.get_plugin_description(), "")


func test_not_configurable():
	assert_false(_plugin.is_configurable())


func test_plugin_folder():
	assert_eq(_plugin.get_plugin_folder(), "walkthrough")


# ── Tests constantes nature ───────────────────────────────────────────────────

func test_nature_colors_positive():
	var color = _plugin._get_nature_color("positive")
	assert_ne(color, Color.TRANSPARENT)
	assert_true(color.g > color.r, "Vert doit dominer pour positif")


func test_nature_colors_negative():
	var color = _plugin._get_nature_color("negative")
	assert_ne(color, Color.TRANSPARENT)
	assert_true(color.r > color.g, "Rouge doit dominer pour négatif")


func test_nature_colors_balanced():
	var color = _plugin._get_nature_color("balanced")
	assert_ne(color, Color.TRANSPARENT)
	assert_true(color.r > 0.5 and color.g > 0.5, "Jaune pour équilibré")


func test_nature_colors_empty():
	var color = _plugin._get_nature_color("")
	assert_eq(color, Color.TRANSPARENT)


func test_nature_colors_unknown():
	var color = _plugin._get_nature_color("unknown_nature")
	assert_eq(color, Color.TRANSPARENT)


# ── Tests validation code ─────────────────────────────────────────────────────

func test_is_code_valid_correct():
	_plugin._plugin_settings = {"activation_code": "GUIDE2024"}
	assert_true(_plugin._is_code_valid("GUIDE2024"))


func test_is_code_valid_wrong():
	_plugin._plugin_settings = {"activation_code": "GUIDE2024"}
	assert_false(_plugin._is_code_valid("WRONG"))


func test_is_code_valid_empty_code():
	_plugin._plugin_settings = {"activation_code": "GUIDE2024"}
	assert_false(_plugin._is_code_valid(""))


func test_is_code_valid_no_config():
	_plugin._plugin_settings = {}
	assert_false(_plugin._is_code_valid("GUIDE2024"))


func test_is_code_valid_empty_activation_code():
	_plugin._plugin_settings = {"activation_code": ""}
	assert_false(_plugin._is_code_valid(""))


# ── Tests persistance ─────────────────────────────────────────────────────────

func test_save_and_load_player_data():
	_plugin._validated_code = "TEST123"
	_plugin._enabled = true
	_plugin._save_player_data()
	assert_true(FileAccess.file_exists("user://walkthrough.json"))

	var plugin2 = WalkthroughPlugin.new()
	plugin2._plugin_settings = {"activation_code": "TEST123"}
	plugin2._load_and_revalidate()
	assert_eq(plugin2._validated_code, "TEST123")
	assert_true(plugin2._enabled)


func test_load_revalidates_invalid_code():
	# Sauvegarder un code
	_plugin._validated_code = "OLD_CODE"
	_plugin._enabled = true
	_plugin._save_player_data()

	# Charger avec un code différent dans les settings
	var plugin2 = WalkthroughPlugin.new()
	plugin2._plugin_settings = {"activation_code": "NEW_CODE"}
	plugin2._load_and_revalidate()
	# Le code sauvegardé ne correspond plus → invalidé
	assert_eq(plugin2._validated_code, "")
	assert_false(plugin2._enabled)


func test_load_no_file():
	_plugin._plugin_settings = {"activation_code": "TEST123"}
	_plugin._load_and_revalidate()
	assert_eq(_plugin._validated_code, "")
	assert_false(_plugin._enabled)


func test_load_corrupted_file():
	# Écrire un JSON valide mais sans les champs attendus (not null parsed)
	var file = FileAccess.open("user://walkthrough.json", FileAccess.WRITE)
	file.store_string("[]")
	file.close()
	_plugin._plugin_settings = {"activation_code": "TEST123"}
	_plugin._load_and_revalidate()
	assert_eq(_plugin._validated_code, "")
	assert_false(_plugin._enabled)


func test_save_resets_on_invalid():
	_plugin._validated_code = "OLD_CODE"
	_plugin._enabled = true
	_plugin._save_player_data()

	var plugin2 = WalkthroughPlugin.new()
	plugin2._plugin_settings = {"activation_code": "DIFFERENT"}
	plugin2._load_and_revalidate()
	# Vérifier que le fichier est mis à jour
	assert_false(plugin2._enabled)
	assert_eq(plugin2._validated_code, "")


# ── Tests hook style ──────────────────────────────────────────────────────────

func test_no_style_when_disabled():
	_plugin._enabled = false
	_plugin._validated_code = "TEST123"
	var btn = Button.new()
	var choice = Choice.new()
	choice.nature = "positive"
	_plugin.on_style_choice_button(null, btn, choice, 0)
	assert_false(btn.has_theme_stylebox_override("normal"), "Pas de style si disabled")
	btn.queue_free()


func test_no_style_when_no_code():
	_plugin._enabled = true
	_plugin._validated_code = ""
	var btn = Button.new()
	var choice = Choice.new()
	choice.nature = "positive"
	_plugin.on_style_choice_button(null, btn, choice, 0)
	assert_false(btn.has_theme_stylebox_override("normal"), "Pas de style si pas de code")
	btn.queue_free()


func test_no_style_when_no_nature():
	_plugin._enabled = true
	_plugin._validated_code = "TEST123"
	var btn = Button.new()
	var choice = Choice.new()
	choice.nature = ""
	_plugin.on_style_choice_button(null, btn, choice, 0)
	assert_false(btn.has_theme_stylebox_override("normal"), "Pas de style si nature vide")
	btn.queue_free()


func test_style_applied_for_positive():
	_plugin._enabled = true
	_plugin._validated_code = "TEST123"
	var btn = Button.new()
	var choice = Choice.new()
	choice.nature = "positive"
	_plugin.on_style_choice_button(null, btn, choice, 0)
	assert_true(btn.has_theme_stylebox_override("normal"), "Style doit être appliqué pour positif")
	assert_true(btn.has_theme_stylebox_override("focus"), "Focus style doit être appliqué pour positif")
	btn.queue_free()


func test_style_applied_for_negative():
	_plugin._enabled = true
	_plugin._validated_code = "TEST123"
	var btn = Button.new()
	var choice = Choice.new()
	choice.nature = "negative"
	_plugin.on_style_choice_button(null, btn, choice, 0)
	assert_true(btn.has_theme_stylebox_override("normal"), "Style doit être appliqué pour négatif")
	assert_true(btn.has_theme_stylebox_override("focus"), "Focus style doit être appliqué pour négatif")
	btn.queue_free()


func test_style_applied_for_balanced():
	_plugin._enabled = true
	_plugin._validated_code = "TEST123"
	var btn = Button.new()
	var choice = Choice.new()
	choice.nature = "balanced"
	_plugin.on_style_choice_button(null, btn, choice, 0)
	assert_true(btn.has_theme_stylebox_override("normal"), "Style doit être appliqué pour équilibré")
	assert_true(btn.has_theme_stylebox_override("focus"), "Focus style doit être appliqué pour équilibré")
	btn.queue_free()


func test_is_unlocked_standalone():
	# Sans setting
	assert_false(_plugin._is_unlocked(), "Ne doit pas être débloqué par défaut")
	
	# Simuler standalone
	ProjectSettings.set_setting("application/config/story_path", "res://story")
	assert_true(_plugin._is_unlocked(), "Doit être débloqué en standalone")
	
	# Nettoyer
	ProjectSettings.set_setting("application/config/story_path", null)


func test_style_applied_in_standalone_without_code():
	ProjectSettings.set_setting("application/config/story_path", "res://story")
	_plugin._enabled = true
	_plugin._validated_code = ""
	
	var btn = Button.new()
	var choice = Choice.new()
	choice.nature = "positive"
	_plugin.on_style_choice_button(null, btn, choice, 0)
	
	assert_true(btn.has_theme_stylebox_override("normal"), "Style doit être appliqué en standalone même sans code")
	
	btn.queue_free()
	ProjectSettings.set_setting("application/config/story_path", null)


# ── Tests get_options_controls ────────────────────────────────────────────────

func test_get_options_controls_returns_one():
	var controls = _plugin.get_options_controls()
	assert_eq(controls.size(), 1)


func test_get_editor_config_controls_returns_one():
	var controls = _plugin.get_editor_config_controls()
	assert_eq(controls.size(), 1)


func test_get_export_options_returns_one():
	var options = _plugin.get_export_options()
	assert_eq(options.size(), 1)
	assert_eq(options[0].key, "walkthrough_enabled")


# ── Tests read_editor_config ──────────────────────────────────────────────────

func test_read_editor_config_null():
	var result = _plugin.read_editor_config(null)
	assert_eq(result, {})


func test_read_editor_config_no_meta():
	var ctrl = Control.new()
	var result = _plugin.read_editor_config(ctrl)
	assert_eq(result, {})
	ctrl.queue_free()
