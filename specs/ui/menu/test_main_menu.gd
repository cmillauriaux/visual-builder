extends GutTest

var MainMenuScript = load("res://src/ui/menu/main_menu.gd")
var Story = load("res://src/models/story.gd")

var _menu: Control


func before_each():
	_menu = Control.new()
	_menu.set_script(MainMenuScript)
	add_child_autofree(_menu)
	_menu.build_ui()


# --- Structure UI ---

func test_main_menu_is_control():
	assert_is(_menu, Control)

func test_has_background():
	assert_not_null(_menu._background)
	assert_is(_menu._background, TextureRect)

func test_has_overlay():
	assert_not_null(_menu._overlay)
	assert_is(_menu._overlay, ColorRect)

func test_has_title_label():
	assert_not_null(_menu._title_label)
	assert_is(_menu._title_label, Label)

func test_has_subtitle_label():
	assert_not_null(_menu._subtitle_label)
	assert_is(_menu._subtitle_label, Label)

func test_has_new_game_button():
	assert_not_null(_menu._new_game_button)
	assert_eq(_menu._new_game_button.text, "Nouvelle partie")

func test_has_load_game_button():
	assert_not_null(_menu._load_game_button)
	assert_eq(_menu._load_game_button.text, "Charger partie")

func test_has_chapters_scenes_button():
	assert_not_null(_menu._chapters_scenes_button)
	assert_eq(_menu._chapters_scenes_button.text, "Chapitres / Scènes")

func test_chapters_scenes_signal():
	watch_signals(_menu)
	_menu._chapters_scenes_button.pressed.emit()
	assert_signal_emitted(_menu, "chapters_scenes_pressed")

func test_has_options_button():
	assert_not_null(_menu._options_button)
	assert_eq(_menu._options_button.text, "Options")

func test_has_patreon_button():
	assert_not_null(_menu._patreon_button)
	assert_eq(_menu._patreon_button.text, "Patreon")

func test_has_itchio_button():
	assert_not_null(_menu._itchio_button)
	assert_eq(_menu._itchio_button.text, "itch.io")

func test_patreon_button_hidden_by_default():
	assert_false(_menu._patreon_button.visible)

func test_itchio_button_hidden_by_default():
	assert_false(_menu._itchio_button.visible)

func test_has_quit_button():
	assert_not_null(_menu._quit_button)
	assert_eq(_menu._quit_button.text, "Quitter")

func test_has_options_menu():
	assert_not_null(_menu._options_menu)


# --- Setup avec story ---

func test_setup_title_from_menu_title():
	var story = Story.new()
	story.menu_title = "Mon Super Jeu"
	story.title = "Fallback"
	_menu.setup(story, "res://")
	assert_eq(_menu._title_label.text, "Mon Super Jeu")

func test_setup_title_fallback_to_story_title():
	var story = Story.new()
	story.menu_title = ""
	story.title = "Le Titre"
	_menu.setup(story, "res://")
	assert_eq(_menu._title_label.text, "Le Titre")

func test_setup_subtitle():
	var story = Story.new()
	story.menu_subtitle = "Une aventure épique"
	_menu.setup(story, "res://")
	assert_eq(_menu._subtitle_label.text, "Une aventure épique")

func test_setup_empty_subtitle():
	var story = Story.new()
	story.menu_subtitle = ""
	_menu.setup(story, "res://")
	assert_eq(_menu._subtitle_label.text, "")

func test_setup_no_background():
	var story = Story.new()
	story.menu_background = ""
	_menu.setup(story, "res://")
	assert_null(_menu._background.texture)


# --- Signaux ---

func test_new_game_emits_signal():
	watch_signals(_menu)
	_menu._new_game_button.emit_signal("pressed")
	assert_signal_emitted(_menu, "new_game_pressed")

func test_load_game_emits_signal():
	watch_signals(_menu)
	_menu._load_game_button.emit_signal("pressed")
	assert_signal_emitted(_menu, "load_game_pressed")

func test_quit_emits_signal():
	watch_signals(_menu)
	_menu._quit_button.emit_signal("pressed")
	assert_signal_emitted(_menu, "quit_pressed")

func test_options_shows_options_menu():
	_menu._options_button.emit_signal("pressed")
	assert_true(_menu._options_menu.visible)


# --- Show / Hide ---

func test_show_menu():
	_menu.visible = false
	_menu.show_menu()
	assert_true(_menu.visible)

func test_hide_menu():
	_menu.visible = true
	_menu.hide_menu()
	assert_false(_menu.visible)


# --- Liens externes ---

func test_patreon_visible_when_url_set():
	var story = Story.new()
	story.patreon_url = "https://www.patreon.com/test"
	_menu.setup(story, "res://")
	assert_true(_menu._patreon_button.visible)

func test_patreon_hidden_when_url_empty():
	var story = Story.new()
	story.patreon_url = ""
	_menu.setup(story, "res://")
	assert_false(_menu._patreon_button.visible)

func test_itchio_visible_when_url_set():
	var story = Story.new()
	story.itchio_url = "https://mygame.itch.io/game"
	_menu.setup(story, "res://")
	assert_true(_menu._itchio_button.visible)

func test_itchio_hidden_when_url_empty():
	var story = Story.new()
	story.itchio_url = ""
	_menu.setup(story, "res://")
	assert_false(_menu._itchio_button.visible)


# --- Banner updates ---

func test_update_banner_does_not_crash_with_empty_path() -> void:
	# update_banner doit exister et ne pas planter avec un chemin vide
	assert_true(_menu.has_method("update_banner"), "main_menu should have update_banner method")
	_menu.update_banner("")

func test_update_banner_does_not_crash_with_nonexistent_path() -> void:
	_menu.update_banner("/nonexistent/path/that/does/not/exist")
	# Pas de crash = succès

func test_update_banner_does_not_crash_with_valid_path() -> void:
	# Appeler update_banner avec un chemin valide
	# En headless mode, load() peut retourner null, mais update_banner() doit gérer ce cas gracieusement
	# Note : _banner_texture_rect est null en headless mode (GPU absent), donc
	# update_banner() gère ce cas avec `if tex and _banner_texture_rect:`
	_menu.update_banner("res://assets/ui")  # Valid path that exists in the project
	# Si pas de crash = succès
