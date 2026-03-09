extends GutTest

# Tests pour le composant EndingScreen

var EndingScreenScript = load("res://src/ui/menu/ending_screen.gd")

var _screen: Control = null


func before_each():
	_screen = Control.new()
	_screen.set_script(EndingScreenScript)
	_screen.build_ui("Game Over")
	add_child_autofree(_screen)


# --- Structure UI ---

func test_screen_hidden_by_default():
	assert_false(_screen.visible)


func test_has_title_label():
	assert_not_null(_screen._title_label)


func test_has_subtitle_label():
	assert_not_null(_screen._subtitle_label)


func test_has_back_button():
	assert_not_null(_screen._back_button)


func test_has_patreon_button():
	assert_not_null(_screen._patreon_button)


func test_has_itchio_button():
	assert_not_null(_screen._itchio_button)


func test_has_load_autosave_button():
	assert_not_null(_screen._load_autosave_button)


func test_default_title_shown():
	assert_eq(_screen._title_label.text, "Game Over")


func test_load_autosave_button_hidden_by_default():
	assert_false(_screen._load_autosave_button.visible)


func test_patreon_button_hidden_by_default():
	assert_false(_screen._patreon_button.visible)


func test_itchio_button_hidden_by_default():
	assert_false(_screen._itchio_button.visible)


# --- setup() ---

func test_setup_sets_title():
	_screen.setup("Mon Game Over", "", "", "", "", "")
	assert_eq(_screen._title_label.text, "Mon Game Over")


func test_setup_empty_title_uses_default():
	_screen.setup("", "", "", "", "", "")
	assert_eq(_screen._title_label.text, "Game Over")


func test_setup_sets_subtitle():
	_screen.setup("", "Tu as perdu", "", "", "", "")
	assert_eq(_screen._subtitle_label.text, "Tu as perdu")


func test_setup_shows_patreon_button_when_url_set():
	_screen.setup("", "", "", "", "https://www.patreon.com/test", "")
	assert_true(_screen._patreon_button.visible)


func test_setup_hides_patreon_button_when_url_empty():
	_screen.setup("", "", "", "", "", "")
	assert_false(_screen._patreon_button.visible)


func test_setup_shows_itchio_button_when_url_set():
	_screen.setup("", "", "", "", "", "https://test.itch.io/game")
	assert_true(_screen._itchio_button.visible)


func test_setup_hides_itchio_button_when_url_empty():
	_screen.setup("", "", "", "", "", "")
	assert_false(_screen._itchio_button.visible)


func test_setup_no_background_leaves_texture_null():
	_screen.setup("", "", "", "", "", "")
	assert_null(_screen._background.texture)


# --- set_load_autosave_visible() ---

func test_set_load_autosave_visible_true():
	_screen.set_load_autosave_visible(true)
	assert_true(_screen._load_autosave_button.visible)


func test_set_load_autosave_visible_false():
	_screen.set_load_autosave_visible(true)
	_screen.set_load_autosave_visible(false)
	assert_false(_screen._load_autosave_button.visible)


# --- show_screen / hide_screen ---

func test_show_screen_makes_visible():
	_screen.show_screen()
	assert_true(_screen.visible)


func test_hide_screen_makes_invisible():
	_screen.show_screen()
	_screen.hide_screen()
	assert_false(_screen.visible)


# --- Signaux ---

func test_has_back_to_menu_pressed_signal():
	assert_has_signal(_screen, "back_to_menu_pressed")


func test_has_load_last_autosave_pressed_signal():
	assert_has_signal(_screen, "load_last_autosave_pressed")


func test_back_button_emits_signal():
	watch_signals(_screen)
	_screen._back_button.emit_signal("pressed")
	assert_signal_emitted(_screen, "back_to_menu_pressed")


func test_load_autosave_button_emits_signal():
	watch_signals(_screen)
	_screen._load_autosave_button.emit_signal("pressed")
	assert_signal_emitted(_screen, "load_last_autosave_pressed")


# --- Default title pour To Be Continued ---

func test_default_title_tbc():
	var tbc_screen = Control.new()
	tbc_screen.set_script(EndingScreenScript)
	tbc_screen.build_ui("À suivre...")
	add_child_autofree(tbc_screen)
	assert_eq(tbc_screen._title_label.text, "À suivre...")
	tbc_screen.setup("", "", "", "", "", "")
	assert_eq(tbc_screen._title_label.text, "À suivre...")
