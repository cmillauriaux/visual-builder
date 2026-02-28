extends Control

## Menu principal du jeu : background, titre, sous-titre et boutons d'action.

const OptionsMenuScript = preload("res://src/ui/menu/options_menu.gd")
const GameSettings = preload("res://src/ui/menu/game_settings.gd")
const TextureLoader = preload("res://src/ui/shared/texture_loader.gd")

signal new_game_pressed
signal load_game_pressed
signal quit_pressed

# UI
var _background: TextureRect
var _overlay: ColorRect
var _title_label: Label
var _subtitle_label: Label
var _new_game_button: Button
var _load_game_button: Button
var _options_button: Button
var _quit_button: Button
var _options_menu: PanelContainer

# Settings partagés
var _settings: RefCounted


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

	# Titre
	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 48)
	vbox.add_child(_title_label)

	# Sous-titre
	_subtitle_label = Label.new()
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.add_theme_font_size_override("font_size", 22)
	_subtitle_label.modulate.a = 0.8
	vbox.add_child(_subtitle_label)

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

	_quit_button = _create_menu_button("Quitter")
	_quit_button.pressed.connect(func(): quit_pressed.emit())
	vbox.add_child(_quit_button)

	# Sous-menu Options
	_options_menu = PanelContainer.new()
	_options_menu.set_script(OptionsMenuScript)
	_options_menu.build_ui()
	_options_menu.visible = false
	add_child(_options_menu)


func setup(story, base_path: String) -> void:
	_title_label.text = story.menu_title if story.menu_title != "" else story.title
	_subtitle_label.text = story.menu_subtitle

	if story.menu_background != "":
		var full_path = base_path + "/assets/" + story.menu_background
		var tex = TextureLoader.load_texture(full_path)
		if tex:
			_background.texture = tex
	else:
		_background.texture = null


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


func _create_menu_button(text: String) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(300, 50)
	return btn
