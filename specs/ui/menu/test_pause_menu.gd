extends GutTest

## Tests pour PauseMenu — menu pause in-game.

var PauseMenuScript = load("res://src/ui/menu/pause_menu.gd")

var _menu: Control


func before_each() -> void:
	_menu = Control.new()
	_menu.set_script(PauseMenuScript)
	_menu.build_ui()
	add_child(_menu)


func after_each() -> void:
	remove_child(_menu)
	_menu.queue_free()


func test_starts_hidden() -> void:
	assert_false(_menu.visible, "pause menu should start hidden")


func test_process_mode_always() -> void:
	assert_eq(_menu.process_mode, Node.PROCESS_MODE_ALWAYS, "should have PROCESS_MODE_ALWAYS")


func test_show_menu() -> void:
	_menu.show_menu()
	assert_true(_menu.visible, "should be visible after show_menu")


func test_hide_menu() -> void:
	_menu.show_menu()
	_menu.hide_menu()
	assert_false(_menu.visible, "should be hidden after hide_menu")


func test_has_overlay() -> void:
	assert_not_null(_menu._overlay, "should have overlay")
	assert_true(_menu._overlay is ColorRect)
	assert_eq(_menu._overlay.color, Color(0, 0, 0, 0.6))


func test_has_resume_button() -> void:
	assert_not_null(_menu._resume_button, "should have resume button")
	assert_eq(_menu._resume_button.text, "Reprendre")


func test_has_save_button() -> void:
	assert_not_null(_menu._save_button, "should have save button")
	assert_eq(_menu._save_button.text, "Sauvegarder")


func test_has_load_button() -> void:
	assert_not_null(_menu._load_button, "should have load button")
	assert_eq(_menu._load_button.text, "Charger")


func test_has_new_game_button() -> void:
	assert_not_null(_menu._new_game_button, "should have new game button")
	assert_eq(_menu._new_game_button.text, "Nouvelle partie")


func test_has_patreon_button() -> void:
	assert_not_null(_menu._patreon_button, "should have patreon button")
	assert_eq(_menu._patreon_button.text, "Patreon")

func test_has_itchio_button() -> void:
	assert_not_null(_menu._itchio_button, "should have itchio button")
	assert_eq(_menu._itchio_button.text, "itch.io")

func test_patreon_button_hidden_by_default() -> void:
	assert_false(_menu._patreon_button.visible)

func test_itchio_button_hidden_by_default() -> void:
	assert_false(_menu._itchio_button.visible)

func test_has_quit_button() -> void:
	assert_not_null(_menu._quit_button, "should have quit button")
	assert_eq(_menu._quit_button.text, "Quitter")


func test_resume_signal() -> void:
	watch_signals(_menu)
	_menu._resume_button.pressed.emit()
	assert_signal_emitted(_menu, "resume_pressed")


func test_save_signal() -> void:
	watch_signals(_menu)
	_menu._save_button.pressed.emit()
	assert_signal_emitted(_menu, "save_pressed")


func test_load_signal() -> void:
	watch_signals(_menu)
	_menu._load_button.pressed.emit()
	assert_signal_emitted(_menu, "load_pressed")


func test_new_game_signal() -> void:
	watch_signals(_menu)
	_menu._new_game_button.pressed.emit()
	assert_signal_emitted(_menu, "new_game_pressed")


func test_quit_signal() -> void:
	watch_signals(_menu)
	_menu._quit_button.pressed.emit()
	assert_signal_emitted(_menu, "quit_pressed")


func test_button_minimum_size() -> void:
	assert_eq(_menu._resume_button.custom_minimum_size, Vector2(300, 50))
	assert_eq(_menu._save_button.custom_minimum_size, Vector2(300, 50))
	assert_eq(_menu._load_button.custom_minimum_size, Vector2(300, 50))
	assert_eq(_menu._options_button.custom_minimum_size, Vector2(300, 50))
	assert_eq(_menu._new_game_button.custom_minimum_size, Vector2(300, 50))
	assert_eq(_menu._patreon_button.custom_minimum_size, Vector2(300, 50))
	assert_eq(_menu._itchio_button.custom_minimum_size, Vector2(300, 50))
	assert_eq(_menu._quit_button.custom_minimum_size, Vector2(300, 50))


# --- Options ---

func test_has_options_button() -> void:
	assert_not_null(_menu._options_button, "should have options button")
	assert_eq(_menu._options_button.text, "Options")


func test_options_signal() -> void:
	watch_signals(_menu)
	_menu._options_button.pressed.emit()
	assert_signal_emitted(_menu, "options_pressed")


# --- Liens externes ---

func test_set_external_links_shows_patreon() -> void:
	_menu.set_external_links("https://www.patreon.com/test", "")
	assert_true(_menu._patreon_button.visible)
	assert_false(_menu._itchio_button.visible)

func test_set_external_links_shows_itchio() -> void:
	_menu.set_external_links("", "https://mygame.itch.io/game")
	assert_false(_menu._patreon_button.visible)
	assert_true(_menu._itchio_button.visible)

func test_set_external_links_shows_both() -> void:
	_menu.set_external_links("https://www.patreon.com/test", "https://mygame.itch.io/game")
	assert_true(_menu._patreon_button.visible)
	assert_true(_menu._itchio_button.visible)

func test_set_external_links_hides_both_when_empty() -> void:
	_menu.set_external_links("https://www.patreon.com/test", "https://mygame.itch.io/game")
	_menu.set_external_links("", "")
	assert_false(_menu._patreon_button.visible)
	assert_false(_menu._itchio_button.visible)
