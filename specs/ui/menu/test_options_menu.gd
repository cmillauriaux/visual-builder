extends GutTest

const OptionsMenuScript = preload("res://src/ui/menu/options_menu.gd")
const GameSettings = preload("res://src/ui/menu/game_settings.gd")

var _menu: PanelContainer
var _settings: RefCounted
var _test_cfg_path := "user://test_options_settings.cfg"


func before_each():
	_settings = GameSettings.new()
	_menu = PanelContainer.new()
	_menu.set_script(OptionsMenuScript)
	add_child_autofree(_menu)
	_menu.build_ui()


func after_each():
	if FileAccess.file_exists(_test_cfg_path):
		DirAccess.remove_absolute(_test_cfg_path)


# --- Structure UI ---

func test_options_menu_is_panel_container():
	assert_is(_menu, PanelContainer)

func test_hidden_by_default():
	assert_false(_menu.visible)

func test_has_close_button():
	assert_not_null(_menu._close_button)

func test_has_apply_button():
	assert_not_null(_menu._apply_button)

func test_has_resolution_option():
	assert_not_null(_menu._resolution_option)
	assert_is(_menu._resolution_option, OptionButton)

func test_has_fullscreen_check():
	assert_not_null(_menu._fullscreen_check)
	assert_is(_menu._fullscreen_check, CheckButton)

func test_has_music_enabled_check():
	assert_not_null(_menu._music_enabled_check)
	assert_is(_menu._music_enabled_check, CheckButton)

func test_has_music_volume_slider():
	assert_not_null(_menu._music_volume_slider)
	assert_is(_menu._music_volume_slider, HSlider)

func test_has_fx_enabled_check():
	assert_not_null(_menu._fx_enabled_check)
	assert_is(_menu._fx_enabled_check, CheckButton)

func test_has_fx_volume_slider():
	assert_not_null(_menu._fx_volume_slider)
	assert_is(_menu._fx_volume_slider, HSlider)

func test_has_language_option():
	assert_not_null(_menu._language_option)
	assert_is(_menu._language_option, OptionButton)


# --- Résolutions ---

func test_resolution_option_has_4_items():
	assert_eq(_menu._resolution_option.item_count, 4)

func test_resolution_labels_match():
	for i in range(GameSettings.RESOLUTION_LABELS.size()):
		assert_eq(_menu._resolution_option.get_item_text(i), GameSettings.RESOLUTION_LABELS[i])


# --- Langues ---

func test_language_option_has_2_items():
	assert_eq(_menu._language_option.item_count, 2)

func test_language_option_labels():
	assert_eq(_menu._language_option.get_item_text(0), "Français")
	assert_eq(_menu._language_option.get_item_text(1), "English")


# --- Chargement des valeurs ---

func test_load_values_resolution():
	_settings.resolution = Vector2i(1280, 720)
	_menu.load_from_settings(_settings)
	assert_eq(_menu._resolution_option.selected, 2)  # Index de 1280x720

func test_load_values_fullscreen():
	_settings.fullscreen = true
	_menu.load_from_settings(_settings)
	assert_true(_menu._fullscreen_check.button_pressed)

func test_load_values_music_enabled():
	_settings.music_enabled = false
	_menu.load_from_settings(_settings)
	assert_false(_menu._music_enabled_check.button_pressed)

func test_load_values_music_volume():
	_settings.music_volume = 50
	_menu.load_from_settings(_settings)
	assert_eq(int(_menu._music_volume_slider.value), 50)

func test_load_values_fx_enabled():
	_settings.fx_enabled = false
	_menu.load_from_settings(_settings)
	assert_false(_menu._fx_enabled_check.button_pressed)

func test_load_values_fx_volume():
	_settings.fx_volume = 30
	_menu.load_from_settings(_settings)
	assert_eq(int(_menu._fx_volume_slider.value), 30)

func test_load_values_language():
	_settings.language = "en"
	_menu.load_from_settings(_settings)
	assert_eq(_menu._language_option.selected, 1)  # Index de English


# --- Volume grisé quand audio désactivé ---

func test_music_volume_disabled_when_music_off():
	_settings.music_enabled = false
	_menu.load_from_settings(_settings)
	assert_false(_menu._music_volume_slider.editable)

func test_music_volume_enabled_when_music_on():
	_settings.music_enabled = true
	_menu.load_from_settings(_settings)
	assert_true(_menu._music_volume_slider.editable)

func test_fx_volume_disabled_when_fx_off():
	_settings.fx_enabled = false
	_menu.load_from_settings(_settings)
	assert_false(_menu._fx_volume_slider.editable)

func test_fx_volume_enabled_when_fx_on():
	_settings.fx_enabled = true
	_menu.load_from_settings(_settings)
	assert_true(_menu._fx_volume_slider.editable)


# --- Appliquer ---

func test_apply_writes_to_settings():
	_menu.load_from_settings(_settings)
	# Modifier les contrôles
	_menu._resolution_option.selected = 2  # 1280x720
	_menu._fullscreen_check.button_pressed = true
	_menu._music_enabled_check.button_pressed = false
	_menu._music_volume_slider.value = 40
	_menu._fx_enabled_check.button_pressed = false
	_menu._fx_volume_slider.value = 20
	_menu._language_option.selected = 1  # en

	_menu.apply_to_settings(_settings, _test_cfg_path)
	assert_eq(_settings.resolution, Vector2i(1280, 720))
	assert_eq(_settings.fullscreen, true)
	assert_eq(_settings.music_enabled, false)
	assert_eq(_settings.music_volume, 40)
	assert_eq(_settings.fx_enabled, false)
	assert_eq(_settings.fx_volume, 20)
	assert_eq(_settings.language, "en")

func test_apply_saves_to_file():
	_menu.load_from_settings(_settings)
	_menu.apply_to_settings(_settings, _test_cfg_path)
	assert_true(FileAccess.file_exists(_test_cfg_path))


# --- Fermer sans appliquer ---

func test_close_emits_closed_signal():
	watch_signals(_menu)
	_menu.visible = true
	_menu._close_button.emit_signal("pressed")
	assert_signal_emitted(_menu, "closed")

func test_close_hides_menu():
	_menu.visible = true
	_menu._close_button.emit_signal("pressed")
	assert_false(_menu.visible)


# --- Signal applied ---

func test_apply_emits_applied_signal():
	watch_signals(_menu)
	_menu.load_from_settings(_settings)
	_menu._apply_button.emit_signal("pressed")
	assert_signal_emitted(_menu, "applied")
