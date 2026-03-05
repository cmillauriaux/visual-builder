extends PanelContainer

## Sous-menu Options : affichage, audio, langue.

const GameSettings = preload("res://src/ui/menu/game_settings.gd")
const StoryI18nService = preload("res://src/services/story_i18n_service.gd")
const GameTheme = preload("res://src/ui/themes/game_theme.gd")

signal closed
signal applied

const LANGUAGE_CODES := ["fr", "en"]

# Contrôles
var _close_button: Button
var _apply_button: Button
var _resolution_option: OptionButton
var _fullscreen_check: CheckButton
var _music_enabled_check: CheckButton
var _music_volume_slider: HSlider
var _fx_enabled_check: CheckButton
var _fx_volume_slider: HSlider
var _language_option: OptionButton
var _auto_play_enabled_check: CheckButton
var _auto_play_delay_option: OptionButton
var _typewriter_speed_option: OptionButton
var _dialogue_opacity_slider: HSlider

const AUTO_PLAY_DELAYS := [1.0, 2.0, 3.0, 5.0]
const AUTO_PLAY_DELAY_LABELS := ["1s", "2s", "3s", "5s"]
const TYPEWRITER_SPEEDS := [0.06, 0.03, 0.015, 0.0]
const TYPEWRITER_SPEED_LABELS := ["Lent", "Normal", "Rapide", "Instantané"]

# Référence aux settings pour apply
var _current_settings: RefCounted
var _settings_path: String = GameSettings.SETTINGS_PATH

# Paires [Control, source_string] pour les traductions UI
var _ui_label_pairs: Array = []


func build_ui() -> void:
	visible = false
	custom_minimum_size = Vector2(600, 500)

	var root_vbox = VBoxContainer.new()
	add_child(root_vbox)

	# Barre de titre
	var title_bar = HBoxContainer.new()
	root_vbox.add_child(title_bar)

	var title_label = Label.new()
	title_label.text = "Options"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 22)
	title_bar.add_child(title_label)
	_ui_label_pairs.append([title_label, "Options"])

	_close_button = Button.new()
	_close_button.text = "✕"
	_close_button.pressed.connect(_on_close)
	GameTheme.apply_close_style(_close_button)
	title_bar.add_child(_close_button)

	root_vbox.add_child(HSeparator.new())

	# Scroll
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(scroll)

	var content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

	# Section Affichage
	_add_section_label(content, "Affichage")
	_resolution_option = _add_option_row(content, "Résolution", GameSettings.RESOLUTION_LABELS)
	_fullscreen_check = _add_check_row(content, "Plein écran")
	_dialogue_opacity_slider = _add_slider_row(content, "Opacité dialogue")

	content.add_child(HSeparator.new())

	# Section Audio
	_add_section_label(content, "Audio")
	_music_enabled_check = _add_check_row(content, "Musique")
	_music_volume_slider = _add_slider_row(content, "Volume musique")
	_music_enabled_check.toggled.connect(_on_music_toggled)
	_fx_enabled_check = _add_check_row(content, "Effets sonores")
	_fx_volume_slider = _add_slider_row(content, "Volume effets")
	_fx_enabled_check.toggled.connect(_on_fx_toggled)

	content.add_child(HSeparator.new())

	# Section Langue
	_add_section_label(content, "Langue")
	_language_option = _add_option_row(content, "Langue", ["Français", "English"])

	content.add_child(HSeparator.new())

	# Section Gameplay
	_add_section_label(content, "Gameplay")
	_auto_play_enabled_check = _add_check_row(content, "Auto-play")
	_auto_play_delay_option = _add_option_row(content, "Delai auto-play", AUTO_PLAY_DELAY_LABELS)
	_auto_play_enabled_check.toggled.connect(_on_auto_play_toggled)
	_typewriter_speed_option = _add_option_row(content, "Vitesse texte", TYPEWRITER_SPEED_LABELS)

	# Bouton Appliquer
	_apply_button = Button.new()
	_apply_button.text = "Appliquer"
	_apply_button.pressed.connect(_on_apply)
	root_vbox.add_child(_apply_button)
	_ui_label_pairs.append([_apply_button, "Appliquer"])


func load_from_settings(settings: RefCounted) -> void:
	_current_settings = settings

	# Résolution
	var res_idx = _find_resolution_index(settings.resolution)
	_resolution_option.selected = res_idx

	# Plein écran
	_fullscreen_check.button_pressed = settings.fullscreen

	# Opacité dialogue
	_dialogue_opacity_slider.value = settings.dialogue_opacity

	# Audio
	_music_enabled_check.button_pressed = settings.music_enabled
	_music_volume_slider.value = settings.music_volume
	_music_volume_slider.editable = settings.music_enabled
	_fx_enabled_check.button_pressed = settings.fx_enabled
	_fx_volume_slider.value = settings.fx_volume
	_fx_volume_slider.editable = settings.fx_enabled

	# Langue
	var lang_idx = LANGUAGE_CODES.find(settings.language)
	_language_option.selected = max(lang_idx, 0)

	# Auto-play
	_auto_play_enabled_check.button_pressed = settings.auto_play_enabled
	var delay_idx = AUTO_PLAY_DELAYS.find(settings.auto_play_delay)
	_auto_play_delay_option.selected = max(delay_idx, 0)
	_auto_play_delay_option.disabled = not settings.auto_play_enabled

	# Vitesse texte
	var speed_idx = TYPEWRITER_SPEEDS.find(settings.typewriter_speed)
	_typewriter_speed_option.selected = max(speed_idx, 0)


func apply_to_settings(settings: RefCounted, path: String = GameSettings.SETTINGS_PATH) -> void:
	var res_idx = _resolution_option.selected
	if res_idx >= 0 and res_idx < GameSettings.AVAILABLE_RESOLUTIONS.size():
		settings.resolution = GameSettings.AVAILABLE_RESOLUTIONS[res_idx]
	settings.fullscreen = _fullscreen_check.button_pressed
	settings.dialogue_opacity = int(_dialogue_opacity_slider.value)
	settings.music_enabled = _music_enabled_check.button_pressed
	settings.music_volume = int(_music_volume_slider.value)
	settings.fx_enabled = _fx_enabled_check.button_pressed
	settings.fx_volume = int(_fx_volume_slider.value)
	var lang_idx = _language_option.selected
	if lang_idx >= 0 and lang_idx < LANGUAGE_CODES.size():
		settings.language = LANGUAGE_CODES[lang_idx]
	settings.auto_play_enabled = _auto_play_enabled_check.button_pressed
	var delay_idx = _auto_play_delay_option.selected
	if delay_idx >= 0 and delay_idx < AUTO_PLAY_DELAYS.size():
		settings.auto_play_delay = AUTO_PLAY_DELAYS[delay_idx]
	var speed_idx = _typewriter_speed_option.selected
	if speed_idx >= 0 and speed_idx < TYPEWRITER_SPEEDS.size():
		settings.typewriter_speed = TYPEWRITER_SPEEDS[speed_idx]
	settings.save_settings(path)
	settings.apply_settings()


func _on_close() -> void:
	visible = false
	closed.emit()


func _on_apply() -> void:
	if _current_settings:
		apply_to_settings(_current_settings, _settings_path)
	visible = false
	applied.emit()


func _on_music_toggled(enabled: bool) -> void:
	_music_volume_slider.editable = enabled


func _on_fx_toggled(enabled: bool) -> void:
	_fx_volume_slider.editable = enabled


func _on_auto_play_toggled(enabled: bool) -> void:
	_auto_play_delay_option.disabled = not enabled


# --- Helpers UI ---

func apply_ui_translations(i18n_dict: Dictionary) -> void:
	for pair in _ui_label_pairs:
		pair[0].text = StoryI18nService.get_ui_string(pair[1], i18n_dict)


func _add_section_label(parent: Control, text: String) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", GameTheme.COLOR_TEXT_SECONDARY)
	parent.add_child(label)
	_ui_label_pairs.append([label, text])
	return label


func _add_option_row(parent: Control, label_text: String, items: Array) -> OptionButton:
	var hbox = HBoxContainer.new()
	parent.add_child(hbox)
	var label = Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)
	_ui_label_pairs.append([label, label_text])
	var option = OptionButton.new()
	for item in items:
		option.add_item(item)
	hbox.add_child(option)
	return option


func _add_check_row(parent: Control, label_text: String) -> CheckButton:
	var hbox = HBoxContainer.new()
	parent.add_child(hbox)
	var label = Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)
	_ui_label_pairs.append([label, label_text])
	var check = CheckButton.new()
	hbox.add_child(check)
	return check


func _add_slider_row(parent: Control, label_text: String) -> HSlider:
	var hbox = HBoxContainer.new()
	parent.add_child(hbox)
	var label = Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)
	_ui_label_pairs.append([label, label_text])
	var slider = HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = 80
	slider.custom_minimum_size.x = 200
	hbox.add_child(slider)
	return slider


func _find_resolution_index(res: Vector2i) -> int:
	for i in range(GameSettings.AVAILABLE_RESOLUTIONS.size()):
		if GameSettings.AVAILABLE_RESOLUTIONS[i] == res:
			return i
	return 0
