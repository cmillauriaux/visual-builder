# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends Control

## Menu principal du jeu : background, titre, sous-titre et boutons d'action.

const OptionsMenuScript = preload("res://src/ui/menu/options_menu.gd")
const GameSettings = preload("res://src/ui/menu/game_settings.gd")
const TextureLoader = preload("res://src/ui/shared/texture_loader.gd")
const StoryI18nService = preload("res://src/services/story_i18n_service.gd")
const GameTheme = preload("res://src/ui/themes/game_theme.gd")
const UIScale = preload("res://src/ui/themes/ui_scale.gd")

signal new_game_pressed
signal load_game_pressed
signal chapters_scenes_pressed
signal options_applied
signal quit_pressed
signal external_link_opened(link_type: String, context: String)

# UI
var _background: TextureRect
var _title_label: Label
var _subtitle_label: Label
var _new_game_button: Button
var _load_game_button: Button
var _chapters_scenes_button: Button
var _options_button: Button
var _patreon_button: Button
var _itchio_button: Button
var _links_hbox: HBoxContainer
var _quit_button: Button
var _options_menu: PanelContainer
var _options_center: MarginContainer
var _menu_content: MarginContainer
var _loading_overlay: CenterContainer
var _loading_label: Label
var _banner_wrapper: CenterContainer
var _banner_texture_rect: TextureRect = null

# Settings partagés
var _settings: RefCounted

# Contexte actuel pour la traduction dynamique
var _current_story = null
var _current_base_path: String = ""
var _last_i18n_dict: Dictionary = {}
var _voice_languages: Array = []


func build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Background
	_background = TextureRect.new()
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(_background)

	# Conteneur de contenu (bannière + boutons)
	_menu_content = MarginContainer.new()
	_menu_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu_content.add_theme_constant_override("margin_bottom", UIScale.scale(80))
	add_child(_menu_content)

	var vbox = VBoxContainer.new()
	vbox.size_flags_vertical = Control.SIZE_SHRINK_END
	vbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_theme_constant_override("separation", 12)
	_menu_content.add_child(vbox)

	# Bannière avec titre et sous-titre superposés
	_banner_wrapper = CenterContainer.new()
	var banner_wrapper = _banner_wrapper
	vbox.add_child(banner_wrapper)

	var banner_stack = Control.new()
	banner_stack.custom_minimum_size = Vector2(UIScale.scale(500), UIScale.scale(140))
	banner_wrapper.add_child(banner_stack)

	var banner_tex = load(GameTheme.ASSETS_PATH + "banner_hanging.png")
	if banner_tex:
		var banner = TextureRect.new()
		banner.texture = banner_tex
		banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		banner_stack.add_child(banner)
		_banner_texture_rect = banner

	# Labels centrés sur la bannière
	var label_center = CenterContainer.new()
	label_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	banner_stack.add_child(label_center)

	var label_vbox = VBoxContainer.new()
	label_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	label_vbox.add_theme_constant_override("separation", 2)
	label_center.add_child(label_vbox)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", UIScale.scale(48))
	_title_label.add_theme_color_override("font_color", Color.WHITE)
	label_vbox.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.add_theme_font_size_override("font_size", UIScale.scale(26))
	_subtitle_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	label_vbox.add_child(_subtitle_label)

	# Boutons
	_new_game_button = _create_menu_button("Nouvelle partie")
	_new_game_button.pressed.connect(func(): new_game_pressed.emit())
	vbox.add_child(_new_game_button)

	_load_game_button = _create_menu_button("Charger partie")
	_load_game_button.pressed.connect(func(): load_game_pressed.emit())
	vbox.add_child(_load_game_button)

	_chapters_scenes_button = _create_menu_button("Chapitres / Scènes")
	_chapters_scenes_button.pressed.connect(func(): chapters_scenes_pressed.emit())
	vbox.add_child(_chapters_scenes_button)

	_options_button = _create_menu_button("Options")
	_options_button.pressed.connect(_on_options_pressed)
	vbox.add_child(_options_button)

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

	# Écran de chargement (background du menu visible, boutons cachés, texte centré)
	_loading_overlay = CenterContainer.new()
	_loading_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_loading_overlay.visible = false
	add_child(_loading_overlay)

	_loading_label = Label.new()
	_loading_label.text = StoryI18nService.get_ui_string("Chargement...", _last_i18n_dict)
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_label.add_theme_font_size_override("font_size", UIScale.scale(40))
	_loading_label.add_theme_color_override("font_color", Color.WHITE)
	_loading_overlay.add_child(_loading_label)

	# Label édition (visible uniquement dans le jeu exporté)
	var edition = ProjectSettings.get_setting("application/config/edition", "")
	if edition != "":
		var version_str = ProjectSettings.get_setting("application/config/version", "")
		var release_date = ProjectSettings.get_setting("application/config/release_date", "")
		var edition_label = Label.new()
		edition_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		edition_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		edition_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		edition_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
		var parts = [edition + " edition"]
		if version_str != "":
			parts.append("v" + version_str)
		if release_date != "":
			parts.append(release_date)
		edition_label.text = " — ".join(parts)
		edition_label.add_theme_font_size_override("font_size", UIScale.scale(16))
		edition_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
		edition_label.offset_right = -UIScale.scale(8)
		edition_label.offset_bottom = -UIScale.scale(6)
		add_child(edition_label)

	# Sous-menu Options (plein écran avec marge)
	_options_center = MarginContainer.new()
	var options_center = _options_center
	options_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin_value = UIScale.scale(40)
	options_center.add_theme_constant_override("margin_top", margin_value)
	options_center.add_theme_constant_override("margin_bottom", margin_value)
	options_center.add_theme_constant_override("margin_left", margin_value)
	options_center.add_theme_constant_override("margin_right", margin_value)
	options_center.visible = false
	add_child(options_center)

	_options_menu = PanelContainer.new()
	_options_menu.set_script(OptionsMenuScript)
	_options_menu.build_ui()
	_options_menu.applied.connect(func():
		options_center.visible = false
		options_applied.emit()
	)
	_options_menu.closed.connect(func(): options_center.visible = false)
	options_center.add_child(_options_menu)


func update_banner(story_ui_path: String) -> void:
	var tex = GameTheme._resolve_asset("banner_hanging.png", story_ui_path)
	if tex and _banner_texture_rect:
		_banner_texture_rect.texture = tex


func setup(story, base_path: String) -> void:
	_current_story = story
	_current_base_path = base_path
	_update_display()


func _update_display() -> void:
	if _current_story == null:
		return

	var title_to_use = _current_story.menu_title if _current_story.menu_title != "" else _current_story.title
	_title_label.text = StoryI18nService.get_ui_string(title_to_use, _last_i18n_dict)
	_subtitle_label.text = StoryI18nService.get_ui_string(_current_story.menu_subtitle, _last_i18n_dict)

	var show_banner = _current_story.show_title_banner if _current_story.get("show_title_banner") != null else true
	_banner_wrapper.visible = show_banner

	if _current_story.menu_background != "":
		var full_path = _current_base_path.path_join(_current_story.menu_background)
		var tex = TextureLoader.load_texture(full_path)
		if tex:
			_background.texture = tex
		else:
			_background.texture = TextureLoader.load_texture(_current_story.menu_background)
	else:
		_background.texture = null

	var patreon_url = _current_story.patreon_url if _current_story.get("patreon_url") != null else ""
	var itchio_url = _current_story.itchio_url if _current_story.get("itchio_url") != null else ""
	_patreon_button.visible = patreon_url != ""
	_itchio_button.visible = itchio_url != ""
	_links_hbox.visible = _patreon_button.visible or _itchio_button.visible


func set_settings(settings: RefCounted) -> void:
	_settings = settings


func set_game_plugin_manager(manager: Node) -> void:
	if _options_menu and _options_menu.has_method("set_game_plugin_manager"):
		_options_menu.set_game_plugin_manager(manager)


func show_menu() -> void:
	visible = true


func hide_menu() -> void:
	visible = false


func set_voice_languages(langs: Array) -> void:
	_voice_languages = langs


func _on_options_pressed() -> void:
	if _options_menu.has_method("setup_languages") and _current_base_path != "":
		_options_menu.setup_languages(_current_base_path)
	if _options_menu.has_method("setup_voice_languages"):
		_options_menu.setup_voice_languages(_voice_languages)
	if _settings:
		_options_menu.load_from_settings(_settings)
	_options_menu.visible = true
	_options_center.visible = true


func apply_ui_translations(i18n_dict: Dictionary) -> void:
	_last_i18n_dict = i18n_dict
	_new_game_button.text = StoryI18nService.get_ui_string("Nouvelle partie", i18n_dict)
	_load_game_button.text = StoryI18nService.get_ui_string("Charger partie", i18n_dict)
	_chapters_scenes_button.text = StoryI18nService.get_ui_string("Chapitres / Scènes", i18n_dict)
	_options_button.text = StoryI18nService.get_ui_string("Options", i18n_dict)
	_patreon_button.text = StoryI18nService.get_ui_string("Patreon", i18n_dict)
	_itchio_button.text = StoryI18nService.get_ui_string("itch.io", i18n_dict)
	_quit_button.text = StoryI18nService.get_ui_string("Quitter", i18n_dict)
	_loading_label.text = StoryI18nService.get_ui_string("Chargement...", i18n_dict)
	_options_menu.apply_ui_translations(i18n_dict)
	_update_display()


func set_loading_visible(is_visible: bool) -> void:
	_menu_content.visible = not is_visible
	_loading_overlay.visible = is_visible
	if not is_visible:
		_loading_label.text = StoryI18nService.get_ui_string("Chargement...", _last_i18n_dict)


func update_loading_text(text: String) -> void:
	_loading_label.text = text


func _on_patreon_pressed() -> void:
	if _current_story and _current_story.patreon_url != "":
		OS.shell_open(_current_story.patreon_url)
		external_link_opened.emit("patreon", "main_menu")


func _on_itchio_pressed() -> void:
	if _current_story and _current_story.itchio_url != "":
		OS.shell_open(_current_story.itchio_url)
		external_link_opened.emit("itchio", "main_menu")


func _create_menu_button(text: String) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(UIScale.scale(300), UIScale.scale(50))
	return btn