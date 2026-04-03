# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends Control

## Menu pause in-game : overlay avec options reprendre, sauvegarder, charger, nouvelle partie, quitter.

const StoryI18nService = preload("res://src/services/story_i18n_service.gd")
const GameTheme = preload("res://src/ui/themes/game_theme.gd")
const UIScale = preload("res://src/ui/themes/ui_scale.gd")

var _patreon_url: String = ""
var _itchio_url: String = ""

signal resume_pressed
signal save_pressed
signal load_pressed
signal options_pressed
signal new_game_pressed
signal quit_pressed
signal chapters_scenes_pressed
signal external_link_opened(link_type: String, context: String)

# UI
var _overlay: ColorRect
var _title_label: Label
var _resume_button: Button
var _save_button: Button
var _load_button: Button
var _chapters_scenes_button: Button
var _options_button: Button
var _new_game_button: Button
var _patreon_button: Button
var _itchio_button: Button
var _links_hbox: HBoxContainer
var _quit_button: Button


func build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	# Overlay sombre
	_overlay = ColorRect.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0, 0, 0, 0.6)
	add_child(_overlay)

	# Conteneur centré
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(UIScale.scale(300), 0)
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", UIScale.scale(12))
	panel.add_child(vbox)

	# Titre
	_title_label = Label.new()
	_title_label.text = "Pause"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", UIScale.scale(44))
	vbox.add_child(_title_label)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size.y = UIScale.scale(40)
	vbox.add_child(spacer)

	# Boutons
	_resume_button = _create_menu_button("Reprendre")
	_resume_button.pressed.connect(func(): resume_pressed.emit())
	vbox.add_child(_resume_button)

	_save_button = _create_menu_button("Sauvegarder")
	_save_button.pressed.connect(func(): save_pressed.emit())
	vbox.add_child(_save_button)

	_load_button = _create_menu_button("Charger")
	_load_button.pressed.connect(func(): load_pressed.emit())
	vbox.add_child(_load_button)

	_chapters_scenes_button = _create_menu_button("Chapitres / Scènes")
	_chapters_scenes_button.pressed.connect(func(): chapters_scenes_pressed.emit())
	vbox.add_child(_chapters_scenes_button)

	_options_button = _create_menu_button("Options")
	_options_button.pressed.connect(func(): options_pressed.emit())
	vbox.add_child(_options_button)

	_new_game_button = _create_menu_button("Nouvelle partie")
	_new_game_button.pressed.connect(func(): new_game_pressed.emit())
	vbox.add_child(_new_game_button)

	_links_hbox = HBoxContainer.new()
	_links_hbox.visible = false
	vbox.add_child(_links_hbox)

	_patreon_button = _create_menu_button("Patreon")
	_patreon_button.pressed.connect(_on_patreon_pressed)
	_patreon_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	GameTheme.apply_link_style(_patreon_button, Color("#FF424D"))
	_patreon_button.visible = false
	_links_hbox.add_child(_patreon_button)

	_itchio_button = _create_menu_button("itch.io")
	_itchio_button.pressed.connect(_on_itchio_pressed)
	_itchio_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	GameTheme.apply_link_style(_itchio_button, Color("#FA5C5C"))
	_itchio_button.visible = false
	_links_hbox.add_child(_itchio_button)

	_quit_button = _create_menu_button("Quitter")
	_quit_button.pressed.connect(func(): quit_pressed.emit())
	GameTheme.apply_danger_style(_quit_button)
	if OS.has_feature("web"):
		_quit_button.visible = false
	vbox.add_child(_quit_button)


func apply_custom_theme(story_ui_path: String) -> void:
	if _quit_button:
		GameTheme.apply_danger_style(_quit_button, story_ui_path)


func apply_ui_translations(i18n_dict: Dictionary) -> void:
	_title_label.text = StoryI18nService.get_ui_string("Pause", i18n_dict)
	_resume_button.text = StoryI18nService.get_ui_string("Reprendre", i18n_dict)
	_save_button.text = StoryI18nService.get_ui_string("Sauvegarder", i18n_dict)
	_load_button.text = StoryI18nService.get_ui_string("Charger", i18n_dict)
	_chapters_scenes_button.text = StoryI18nService.get_ui_string("Chapitres / Scènes", i18n_dict)
	_options_button.text = StoryI18nService.get_ui_string("Options", i18n_dict)
	_new_game_button.text = StoryI18nService.get_ui_string("Nouvelle partie", i18n_dict)
	_patreon_button.text = StoryI18nService.get_ui_string("Patreon", i18n_dict)
	_itchio_button.text = StoryI18nService.get_ui_string("itch.io", i18n_dict)
	_quit_button.text = StoryI18nService.get_ui_string("Quitter", i18n_dict)


func show_menu() -> void:
	visible = true


func hide_menu() -> void:
	visible = false


func set_external_links(patreon_url: String, itchio_url: String) -> void:
	_patreon_url = patreon_url
	_itchio_url = itchio_url
	_patreon_button.visible = patreon_url != ""
	_itchio_button.visible = itchio_url != ""
	_links_hbox.visible = _patreon_button.visible or _itchio_button.visible


func _on_patreon_pressed() -> void:
	if _patreon_url != "":
		OS.shell_open(_patreon_url)
		external_link_opened.emit("patreon", "pause")


func _on_itchio_pressed() -> void:
	if _itchio_url != "":
		OS.shell_open(_itchio_url)
		external_link_opened.emit("itchio", "pause")


func _create_menu_button(text: String) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(UIScale.scale(300), UIScale.scale(50))
	return btn