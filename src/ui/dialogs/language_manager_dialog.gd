# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends AcceptDialog

## Dialog de gestion des langues de l'histoire.
## Permet d'ajouter/supprimer des langues et d'en désigner une par défaut (langue source).

const StoryI18nService = preload("res://src/services/story_i18n_service.gd")

signal languages_changed

var _story_path: String = ""
var _config: Dictionary = {}  # { default, languages }

var _list: VBoxContainer
var _button_group: ButtonGroup
var _code_edit: LineEdit
var _error_label: Label
var _add_btn: Button


func _ready() -> void:
	title = tr("Langues de l'histoire")
	ok_button_text = tr("Fermer")
	_build_ui()


func setup(story_path: String) -> void:
	_story_path = story_path
	_config = StoryI18nService.load_languages_config(story_path)
	_rebuild_list()


func get_languages() -> Array:
	return _config.get("languages", []).duplicate()


func get_default_language() -> String:
	return _config.get("default", "fr")


func add_language(code: String) -> String:
	code = code.strip_edges().to_lower()
	if code == "":
		return tr("Le code de langue ne peut pas être vide.")
	if not code.is_valid_identifier() and not _is_valid_lang_code(code):
		return tr("Code invalide. Utilisez 2-5 lettres (ex: fr, en, zh_TW).")
	var langs: Array = _config.get("languages", [])
	if langs.has(code):
		return tr("La langue « %s » est déjà dans la liste.") % code
	langs.append(code)
	langs.sort()
	_config["languages"] = langs
	if langs.size() == 1:
		_config["default"] = code
	_save_and_refresh()
	return ""


func remove_language(code: String) -> String:
	if code == _config.get("default", ""):
		return tr("Impossible de supprimer la langue par défaut (source).")
	var langs: Array = _config.get("languages", [])
	langs.erase(code)
	_config["languages"] = langs
	_save_and_refresh()
	return ""


func set_default_language(code: String) -> void:
	_config["default"] = code
	_save_and_refresh()


# --- Private ---

func _build_ui() -> void:
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(420, 280)
	add_child(vbox)

	var desc = Label.new()
	desc.text = tr("La langue par défaut est la langue source (texte dans les YAML d'histoire).\nLes autres langues sont les langues cibles à traduire.")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc)

	vbox.add_child(HSeparator.new())

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 120)
	vbox.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	_button_group = ButtonGroup.new()

	vbox.add_child(HSeparator.new())

	var add_row = HBoxContainer.new()
	vbox.add_child(add_row)

	var code_label = Label.new()
	code_label.text = tr("Code :")
	add_row.add_child(code_label)

	_code_edit = LineEdit.new()
	_code_edit.placeholder_text = "fr, en, de, zh_TW…"
	_code_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code_edit.max_length = 10
	add_row.add_child(_code_edit)

	_add_btn = Button.new()
	_add_btn.text = tr("+ Ajouter")
	_add_btn.pressed.connect(_on_add_pressed)
	add_row.add_child(_add_btn)

	_error_label = Label.new()
	_error_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_error_label.visible = false
	vbox.add_child(_error_label)


func _rebuild_list() -> void:
	if _list == null:
		return
	for child in _list.get_children():
		child.queue_free()
	var langs: Array = _config.get("languages", [])
	var default_lang: String = _config.get("default", "fr")
	for lang in langs:
		_list.add_child(_create_row(lang, lang == default_lang))


func _create_row(code: String, is_default: bool) -> HBoxContainer:
	var row = HBoxContainer.new()

	var radio = CheckBox.new()
	radio.button_group = _button_group
	radio.toggle_mode = true
	radio.button_pressed = is_default
	radio.text = ""
	radio.tooltip_text = tr("Définir comme langue source (défaut)")
	radio.toggled.connect(_on_default_toggled.bind(code))
	row.add_child(radio)

	var lbl = Label.new()
	lbl.text = code
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)

	if is_default:
		var badge = Label.new()
		badge.text = "(source)"
		badge.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
		row.add_child(badge)

	var del_btn = Button.new()
	del_btn.text = "×"
	del_btn.disabled = is_default
	del_btn.tooltip_text = tr("Supprimer cette langue") if not is_default else tr("Impossible de supprimer la langue source")
	del_btn.pressed.connect(_on_delete_pressed.bind(code))
	row.add_child(del_btn)

	return row


func _save_and_refresh() -> void:
	if _story_path != "":
		StoryI18nService.save_languages_config(_config, _story_path)
	_rebuild_list()
	_error_label.visible = false
	languages_changed.emit()


func _show_error(msg: String) -> void:
	_error_label.text = msg
	_error_label.visible = true


func _on_add_pressed() -> void:
	var error = add_language(_code_edit.text)
	if error != "":
		_show_error(error)
	else:
		_code_edit.text = ""
		_error_label.visible = false


func _on_delete_pressed(code: String) -> void:
	var error = remove_language(code)
	if error != "":
		_show_error(error)


func _on_default_toggled(pressed: bool, code: String) -> void:
	if pressed:
		set_default_language(code)


func _is_valid_lang_code(code: String) -> bool:
	if code.length() < 2 or code.length() > 10:
		return false
	for c in code:
		if not (c >= 'a' and c <= 'z') and not (c >= 'A' and c <= 'Z') and c != '_':
			return false
	return true