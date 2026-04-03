# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends Control

## Écran de fin plein-écran (Game Over ou To Be Continued).
## Affiche un background, titre, sous-titre, et boutons Patreon / itch.io / Retour menu.

const TextureLoader = preload("res://src/ui/shared/texture_loader.gd")
const GameTheme = preload("res://src/ui/themes/game_theme.gd")
const UIScale = preload("res://src/ui/themes/ui_scale.gd")
const StoryI18nService = preload("res://src/services/story_i18n_service.gd")

var _i18n_dict: Dictionary = {}

signal back_to_menu_pressed
signal load_last_autosave_pressed
signal external_link_opened(link_type: String, context: String)

var _default_title: String = ""
var _background: TextureRect
var _title_label: Label
var _subtitle_label: Label
var _load_autosave_button: Button
var _patreon_button: Button
var _itchio_button: Button
var _links_hbox: HBoxContainer
var _back_button: Button

var _patreon_url: String = ""
var _itchio_url: String = ""


func build_ui(default_title: String = "") -> void:
	_default_title = default_title
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

	_background = TextureRect.new()
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(_background)

	var overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.5)
	add_child(overlay)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	center.add_child(vbox)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", UIScale.scale(80))
	_title_label.add_theme_color_override("font_color", Color.WHITE)
	_title_label.text = _default_title
	vbox.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.add_theme_font_size_override("font_size", UIScale.scale(36))
	_subtitle_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	vbox.add_child(_subtitle_label)

	var spacer = Control.new()
	spacer.custom_minimum_size.y = UIScale.scale(60)
	vbox.add_child(spacer)

	_load_autosave_button = _create_button(StoryI18nService.get_ui_string("Charger la dernière sauvegarde", _i18n_dict))
	_load_autosave_button.pressed.connect(func(): load_last_autosave_pressed.emit())
	_load_autosave_button.visible = false
	vbox.add_child(_load_autosave_button)

	_links_hbox = HBoxContainer.new()
	_links_hbox.visible = false
	vbox.add_child(_links_hbox)

	_patreon_button = _create_button(StoryI18nService.get_ui_string("Patreon", _i18n_dict))
	_patreon_button.pressed.connect(_on_patreon_pressed)
	_patreon_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	GameTheme.apply_link_style(_patreon_button, Color("#FF424D"))
	_patreon_button.visible = false
	_links_hbox.add_child(_patreon_button)

	_itchio_button = _create_button(StoryI18nService.get_ui_string("itch.io", _i18n_dict))
	_itchio_button.pressed.connect(_on_itchio_pressed)
	_itchio_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	GameTheme.apply_link_style(_itchio_button, Color("#FA5C5C"))
	_itchio_button.visible = false
	_links_hbox.add_child(_itchio_button)

	_back_button = _create_button(StoryI18nService.get_ui_string("Retour au menu principal", _i18n_dict))
	_back_button.pressed.connect(func(): back_to_menu_pressed.emit())
	vbox.add_child(_back_button)


func apply_ui_translations(i18n_dict: Dictionary) -> void:
	_i18n_dict = i18n_dict
	if _load_autosave_button:
		_load_autosave_button.text = StoryI18nService.get_ui_string("Charger la dernière sauvegarde", _i18n_dict)
	if _patreon_button:
		_patreon_button.text = StoryI18nService.get_ui_string("Patreon", _i18n_dict)
	if _itchio_button:
		_itchio_button.text = StoryI18nService.get_ui_string("itch.io", _i18n_dict)
	if _back_button:
		_back_button.text = StoryI18nService.get_ui_string("Retour au menu principal", _i18n_dict)
	if _title_label and _title_label.text == _default_title:
		_title_label.text = StoryI18nService.get_ui_string(_default_title, _i18n_dict)


func setup(title: String, subtitle: String, background: String, base_path: String, patreon_url: String, itchio_url: String) -> void:
	_title_label.text = title if title != "" else _default_title
	_subtitle_label.text = subtitle

	if background != "":
		var full_path = base_path.path_join(background)
		var tex = TextureLoader.load_texture(full_path)
		if tex:
			_background.texture = tex
		else:
			_background.texture = TextureLoader.load_texture(background)
	else:
		_background.texture = null

	_patreon_url = patreon_url
	_itchio_url = itchio_url
	_patreon_button.visible = patreon_url != ""
	_itchio_button.visible = itchio_url != ""
	_links_hbox.visible = _patreon_button.visible or _itchio_button.visible


func set_load_autosave_visible(visible: bool) -> void:
	_load_autosave_button.visible = visible


func show_screen() -> void:
	visible = true


func hide_screen() -> void:
	visible = false


func _on_patreon_pressed() -> void:
	if _patreon_url != "":
		OS.shell_open(_patreon_url)
		external_link_opened.emit("patreon", "ending")


func _on_itchio_pressed() -> void:
	if _itchio_url != "":
		OS.shell_open(_itchio_url)
		external_link_opened.emit("itchio", "ending")


func _create_button(text: String) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(UIScale.scale(300), UIScale.scale(50))
	return btn