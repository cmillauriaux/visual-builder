extends Control

## Popup d'invitation à installer la PWA sur iOS / Android.
## Détecte la plateforme via user-agent et affiche les instructions adaptées.

const GameTheme = preload("res://src/ui/themes/game_theme.gd")
const UIScale = preload("res://src/ui/themes/ui_scale.gd")
const StoryI18nService = preload("res://src/services/story_i18n_service.gd")

var _i18n_dict: Dictionary = {}
var _title_label: Label
var _ok_btn: Button

signal closed(dont_show_again: bool)

enum Platform { NONE, IOS, ANDROID }

var _dont_show_check: CheckButton
var _platform: int = Platform.NONE


func build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

	# Fond semi-transparent
	var bg = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.6)
	add_child(bg)

	# Centre
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# Panel
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(UIScale.scale(460), 0)
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UIScale.scale(12))
	panel.add_child(vbox)

	# Titre
	_title_label = Label.new()
	_title_label.text = StoryI18nService.get_ui_string("Installer l'application", _i18n_dict)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", UIScale.scale(24))
	vbox.add_child(_title_label)

	# Séparateur
	vbox.add_child(HSeparator.new())

	# Message (sera rempli selon la plateforme)
	var message = RichTextLabel.new()
	message.name = "Message"
	message.bbcode_enabled = true
	message.fit_content = true
	message.scroll_active = false
	message.custom_minimum_size = Vector2(UIScale.scale(400), 0)
	message.add_theme_font_size_override("normal_font_size", UIScale.scale(16))
	vbox.add_child(message)

	# Séparateur
	vbox.add_child(HSeparator.new())

	# Case à cocher
	_dont_show_check = CheckButton.new()
	_dont_show_check.text = StoryI18nService.get_ui_string("Ne plus afficher ce message", _i18n_dict)
	vbox.add_child(_dont_show_check)

	# Bouton Compris
	_ok_btn = Button.new()
	_ok_btn.text = StoryI18nService.get_ui_string("Compris", _i18n_dict)
	_ok_btn.custom_minimum_size = Vector2(0, UIScale.scale(44))
	_ok_btn.pressed.connect(_on_ok_pressed)
	vbox.add_child(_ok_btn)


func apply_ui_translations(i18n_dict: Dictionary) -> void:
	_i18n_dict = i18n_dict
	if _title_label:
		_title_label.text = StoryI18nService.get_ui_string("Installer l'application", _i18n_dict)
	if _dont_show_check:
		_dont_show_check.text = StoryI18nService.get_ui_string("Ne plus afficher ce message", _i18n_dict)
	if _ok_btn:
		_ok_btn.text = StoryI18nService.get_ui_string("Compris", _i18n_dict)


## Affiche la popup si les conditions sont remplies.
## Retourne true si la popup est affichée, false sinon.
func show_if_needed(pwa_prompt_dismissed: bool) -> bool:
	if pwa_prompt_dismissed:
		return false

	if OS.get_name() != "Web":
		return false

	if _is_standalone():
		return false

	_platform = _detect_platform()
	if _platform == Platform.NONE:
		return false

	_update_message()
	visible = true
	return true


## Détecte la plateforme mobile via le user-agent.
static func _detect_platform() -> int:
	var ua := _get_user_agent()
	if ua.is_empty():
		return Platform.NONE
	if ua.contains("iphone") or ua.contains("ipad"):
		return Platform.IOS
	if ua.contains("android"):
		return Platform.ANDROID
	return Platform.NONE


## Récupère le user-agent via JavaScriptBridge.
static func _get_user_agent() -> String:
	if not ClassDB.class_exists(&"JavaScriptBridge"):
		return ""
	var expr := Expression.new()
	if expr.parse("JavaScriptBridge.eval('navigator.userAgent || \"\"')") != OK:
		return ""
	var result = expr.execute([], null, false)
	if expr.has_execute_failed() or result == null:
		return ""
	return str(result).to_lower()


## Vérifie si l'app tourne déjà en mode standalone (PWA installée).
static func _is_standalone() -> bool:
	if not ClassDB.class_exists(&"JavaScriptBridge"):
		return false
	var expr := Expression.new()
	var js_code := "JavaScriptBridge.eval('window.navigator.standalone === true || window.matchMedia(\"(display-mode: standalone)\").matches')"
	if expr.parse(js_code) != OK:
		return false
	var result = expr.execute([], null, false)
	if expr.has_execute_failed() or result == null:
		return false
	return result == true


func _update_message() -> void:
	var msg_node = find_child("Message", true, false) as RichTextLabel
	if msg_node == null:
		return
	if _platform == Platform.IOS:
		msg_node.text = StoryI18nService.get_ui_string("Pour une meilleure expérience (plein écran, mode hors ligne), installez l'application :\n\n1. Appuyez sur le bouton de partage (⎙)\n2. Sélectionnez « Sur l'écran d'accueil »", _i18n_dict)
	elif _platform == Platform.ANDROID:
		msg_node.text = StoryI18nService.get_ui_string("Pour une meilleure expérience (plein écran, mode hors ligne), installez l'application :\n\n1. Ouvrez le menu (⋮) de votre navigateur\n2. Sélectionnez « Installer l'application » ou « Ajouter à l'écran d'accueil »", _i18n_dict)


func _on_ok_pressed() -> void:
	visible = false
	closed.emit(_dont_show_check.button_pressed)


func get_platform() -> int:
	return _platform
