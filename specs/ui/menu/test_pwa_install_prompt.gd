extends GutTest

var PwaInstallPromptScript = load("res://src/ui/menu/pwa_install_prompt.gd")
var GameSettings = load("res://src/ui/menu/game_settings.gd")

var _prompt: Control
var _test_cfg_path := "user://test_pwa_settings.cfg"


func before_each():
	_prompt = Control.new()
	_prompt.set_script(PwaInstallPromptScript)
	_prompt.build_ui()
	add_child_autofree(_prompt)


func after_each():
	if FileAccess.file_exists(_test_cfg_path):
		DirAccess.remove_absolute(_test_cfg_path)


# --- Construction UI ---

func test_build_ui_creates_prompt():
	assert_not_null(_prompt)

func test_prompt_initially_hidden():
	assert_false(_prompt.visible)

func test_prompt_has_message_node():
	var msg = _prompt.find_child("Message", true, false)
	assert_not_null(msg, "Le prompt doit contenir un noeud Message")


# --- Détection de plateforme (hors web) ---

func test_detect_platform_returns_none_on_non_web():
	# En mode headless (non-web), _detect_platform retourne NONE
	if OS.get_name() != "Web":
		var platform = PwaInstallPromptScript._detect_platform()
		assert_eq(platform, PwaInstallPromptScript.Platform.NONE)

func test_get_user_agent_returns_empty_on_non_web():
	# En mode headless, JavaScriptBridge n'existe pas
	if OS.get_name() != "Web":
		var ua = PwaInstallPromptScript._get_user_agent()
		assert_eq(ua, "")

func test_is_standalone_returns_false_on_non_web():
	if OS.get_name() != "Web":
		assert_false(PwaInstallPromptScript._is_standalone())


# --- show_if_needed ---

func test_show_if_needed_returns_false_when_dismissed():
	var result = _prompt.show_if_needed(true)
	assert_false(result, "Doit retourner false si dismissed")
	assert_false(_prompt.visible)

func test_show_if_needed_returns_false_on_non_web():
	if OS.get_name() != "Web":
		var result = _prompt.show_if_needed(false)
		assert_false(result, "Doit retourner false hors web")
		assert_false(_prompt.visible)


# --- Signal closed ---

func test_ok_button_emits_closed_signal():
	_prompt.visible = true
	var result := [null]
	_prompt.closed.connect(func(dont_show: bool): result[0] = dont_show)

	var ok_btn := _find_button_by_text(_prompt, "Compris")
	assert_not_null(ok_btn, "Doit trouver le bouton Compris")
	if ok_btn:
		ok_btn.pressed.emit()
		assert_false(_prompt.visible, "Le prompt doit se fermer")
		assert_eq(result[0], false, "Par défaut, dont_show est false")

func test_ok_button_with_checkbox_emits_true():
	_prompt.visible = true
	var result := [null]
	_prompt.closed.connect(func(dont_show: bool): result[0] = dont_show)

	# Cocher la case
	_prompt._dont_show_check.button_pressed = true

	var ok_btn := _find_button_by_text(_prompt, "Compris")
	if ok_btn:
		ok_btn.pressed.emit()
		assert_eq(result[0], true, "Avec la case cochée, dont_show doit être true")


# --- Platform enum ---

func test_platform_enum_values():
	assert_eq(PwaInstallPromptScript.Platform.NONE, 0)
	assert_eq(PwaInstallPromptScript.Platform.IOS, 1)
	assert_eq(PwaInstallPromptScript.Platform.ANDROID, 2)

func test_get_platform_default_none():
	assert_eq(_prompt.get_platform(), PwaInstallPromptScript.Platform.NONE)


# --- GameSettings pwa_prompt_dismissed ---

func test_settings_default_pwa_prompt_dismissed():
	var settings = GameSettings.new()
	assert_eq(settings.pwa_prompt_dismissed, false)

func test_settings_save_and_load_pwa_prompt_dismissed_true():
	var settings = GameSettings.new()
	settings.pwa_prompt_dismissed = true
	settings.save_settings(_test_cfg_path)
	var loaded = GameSettings.new()
	loaded.load_settings(_test_cfg_path)
	assert_eq(loaded.pwa_prompt_dismissed, true)

func test_settings_save_and_load_pwa_prompt_dismissed_false():
	var settings = GameSettings.new()
	settings.pwa_prompt_dismissed = false
	settings.save_settings(_test_cfg_path)
	var loaded = GameSettings.new()
	loaded.load_settings(_test_cfg_path)
	assert_eq(loaded.pwa_prompt_dismissed, false)


# --- Helper ---

func _find_button_by_text(node: Node, text: String) -> Button:
	if node is Button and node.text == text:
		return node
	for child in node.get_children():
		var found = _find_button_by_text(child, text)
		if found:
			return found
	return null
