extends Control

## Menu pause in-game : overlay avec options reprendre, sauvegarder, charger, nouvelle partie, quitter.

const StoryI18nService = preload("res://src/services/story_i18n_service.gd")
const GameTheme = preload("res://src/ui/themes/game_theme.gd")

signal resume_pressed
signal save_pressed
signal load_pressed
signal new_game_pressed
signal quit_pressed
signal auto_play_toggled(enabled: bool)

# UI
var _overlay: ColorRect
var _title_label: Label
var _resume_button: Button
var _save_button: Button
var _load_button: Button
var _new_game_button: Button
var _quit_button: Button
var _auto_play_check: CheckButton


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
	panel.custom_minimum_size = Vector2(300, 0)
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# Titre
	_title_label = Label.new()
	_title_label.text = "Pause"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 32)
	vbox.add_child(_title_label)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 40
	vbox.add_child(spacer)

	# Boutons
	_resume_button = _create_menu_button("Reprendre")
	_resume_button.pressed.connect(func(): resume_pressed.emit())
	vbox.add_child(_resume_button)

	# Auto-play toggle
	var auto_hbox = HBoxContainer.new()
	auto_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	auto_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(auto_hbox)

	var auto_label = Label.new()
	auto_label.text = "Auto-play"
	auto_label.custom_minimum_size = Vector2(200, 0)
	auto_hbox.add_child(auto_label)

	_auto_play_check = CheckButton.new()
	_auto_play_check.button_pressed = false
	_auto_play_check.toggled.connect(func(enabled): auto_play_toggled.emit(enabled))
	auto_hbox.add_child(_auto_play_check)

	_save_button = _create_menu_button("Sauvegarder")
	_save_button.pressed.connect(func(): save_pressed.emit())
	vbox.add_child(_save_button)

	_load_button = _create_menu_button("Charger")
	_load_button.pressed.connect(func(): load_pressed.emit())
	vbox.add_child(_load_button)

	_new_game_button = _create_menu_button("Nouvelle partie")
	_new_game_button.pressed.connect(func(): new_game_pressed.emit())
	vbox.add_child(_new_game_button)

	_quit_button = _create_menu_button("Quitter")
	_quit_button.pressed.connect(func(): quit_pressed.emit())
	GameTheme.apply_danger_style(_quit_button)
	vbox.add_child(_quit_button)


func apply_ui_translations(i18n_dict: Dictionary) -> void:
	_title_label.text = StoryI18nService.get_ui_string("Pause", i18n_dict)
	_resume_button.text = StoryI18nService.get_ui_string("Reprendre", i18n_dict)
	_save_button.text = StoryI18nService.get_ui_string("Sauvegarder", i18n_dict)
	_load_button.text = StoryI18nService.get_ui_string("Charger", i18n_dict)
	_new_game_button.text = StoryI18nService.get_ui_string("Nouvelle partie", i18n_dict)
	_quit_button.text = StoryI18nService.get_ui_string("Quitter", i18n_dict)


func set_auto_play_state(enabled: bool) -> void:
	_auto_play_check.set_pressed_no_signal(enabled)


func show_menu() -> void:
	visible = true


func hide_menu() -> void:
	visible = false


func _create_menu_button(text: String) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(300, 50)
	return btn
