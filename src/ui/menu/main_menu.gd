extends Control

## Menu principal du jeu : background, titre, sous-titre et boutons d'action.

const OptionsMenuScript = preload("res://src/ui/menu/options_menu.gd")
const GameSettings = preload("res://src/ui/menu/game_settings.gd")
const TextureLoader = preload("res://src/ui/shared/texture_loader.gd")
const StoryI18nService = preload("res://src/services/story_i18n_service.gd")
const GameTheme = preload("res://src/ui/themes/game_theme.gd")

signal new_game_pressed
signal load_game_pressed
signal options_applied
signal quit_pressed

# UI
var _background: TextureRect
var _overlay: ColorRect
var _title_label: Label
var _subtitle_label: Label
var _new_game_button: Button
var _load_game_button: Button
var _options_button: Button
var _patreon_button: Button
var _itchio_button: Button
var _quit_button: Button
var _options_menu: PanelContainer
var _options_center: CenterContainer

# Settings partagés
var _settings: RefCounted

# Contexte actuel pour la traduction dynamique
var _current_story = null
var _current_base_path: String = ""
var _last_i18n_dict: Dictionary = {}


func build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Background
	_background = TextureRect.new()
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(_background)

	# Overlay sombre
	_overlay = ColorRect.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0, 0, 0, 0.4)
	add_child(_overlay)

	# Conteneur centré
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	center.add_child(vbox)

	# Bannière avec titre et sous-titre superposés
	var banner_wrapper = CenterContainer.new()
	vbox.add_child(banner_wrapper)

	var banner_stack = Control.new()
	banner_stack.custom_minimum_size = Vector2(500, 140)
	banner_wrapper.add_child(banner_stack)

	var banner_tex = load(GameTheme.ASSETS_PATH + "banner_hanging.png")
	if banner_tex:
		var banner = TextureRect.new()
		banner.texture = banner_tex
		banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		banner_stack.add_child(banner)

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
	_title_label.add_theme_font_size_override("font_size", 36)
	_title_label.add_theme_color_override("font_color", Color.WHITE)
	label_vbox.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.add_theme_font_size_override("font_size", 18)
	_subtitle_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	label_vbox.add_child(_subtitle_label)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 60
	vbox.add_child(spacer)

	# Boutons
	_new_game_button = _create_menu_button("Nouvelle partie")
	_new_game_button.pressed.connect(func(): new_game_pressed.emit())
	vbox.add_child(_new_game_button)

	_load_game_button = _create_menu_button("Charger partie")
	_load_game_button.pressed.connect(func(): load_game_pressed.emit())
	vbox.add_child(_load_game_button)

	_options_button = _create_menu_button("Options")
	_options_button.pressed.connect(_on_options_pressed)
	vbox.add_child(_options_button)

	_patreon_button = _create_menu_button("Patreon")
	_patreon_button.pressed.connect(_on_patreon_pressed)
	GameTheme.apply_link_style(_patreon_button, Color("#FF424D"))
	_patreon_button.visible = false
	vbox.add_child(_patreon_button)

	_itchio_button = _create_menu_button("itch.io")
	_itchio_button.pressed.connect(_on_itchio_pressed)
	GameTheme.apply_link_style(_itchio_button, Color("#FA5C5C"))
	_itchio_button.visible = false
	vbox.add_child(_itchio_button)

	_quit_button = _create_menu_button("Quitter")
	_quit_button.pressed.connect(func(): quit_pressed.emit())
	GameTheme.apply_danger_style(_quit_button)
	if OS.has_feature("web"):
		_quit_button.visible = false
	vbox.add_child(_quit_button)

	# Sous-menu Options (centré via CenterContainer)
	_options_center = CenterContainer.new()
	var options_center = _options_center
	options_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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


func set_settings(settings: RefCounted) -> void:
	_settings = settings


func show_menu() -> void:
	visible = true


func hide_menu() -> void:
	visible = false


func _on_options_pressed() -> void:
	if _settings:
		_options_menu.load_from_settings(_settings)
	_options_menu.visible = true
	_options_center.visible = true


func apply_ui_translations(i18n_dict: Dictionary) -> void:
	_last_i18n_dict = i18n_dict
	_new_game_button.text = StoryI18nService.get_ui_string("Nouvelle partie", i18n_dict)
	_load_game_button.text = StoryI18nService.get_ui_string("Charger partie", i18n_dict)
	_options_button.text = StoryI18nService.get_ui_string("Options", i18n_dict)
	_patreon_button.text = StoryI18nService.get_ui_string("Patreon", i18n_dict)
	_itchio_button.text = StoryI18nService.get_ui_string("itch.io", i18n_dict)
	_quit_button.text = StoryI18nService.get_ui_string("Quitter", i18n_dict)
	_options_menu.apply_ui_translations(i18n_dict)
	_update_display()


func _on_patreon_pressed() -> void:
	if _current_story and _current_story.patreon_url != "":
		OS.shell_open(_current_story.patreon_url)


func _on_itchio_pressed() -> void:
	if _current_story and _current_story.itchio_url != "":
		OS.shell_open(_current_story.itchio_url)


func _create_menu_button(text: String) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(300, 50)
	return btn
