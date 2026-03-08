extends GutTest

# Tests pour le dialogue de configuration du jeu

const MenuConfigDialogScript = preload("res://src/ui/dialogs/menu_config_dialog.gd")
const StoryScript = preload("res://src/models/story.gd")

var _dialog: ConfirmationDialog = null

func before_each():
	_dialog = ConfirmationDialog.new()
	_dialog.set_script(MenuConfigDialogScript)
	add_child_autofree(_dialog)

func _make_story(menu_title := "", menu_subtitle := "", menu_background := ""):
	var story = StoryScript.new()
	story.title = "Mon Histoire"
	story.menu_title = menu_title
	story.menu_subtitle = menu_subtitle
	story.menu_background = menu_background
	return story

# --- Structure UI ---

func test_title_is_configurer_le_jeu():
	assert_eq(_dialog.title, "Configurer le jeu")

func test_has_tab_container():
	assert_true(_dialog.has_node("TabContainer"), "Le TabContainer doit exister")

func test_has_menu_title_edit():
	assert_true(_dialog.has_node("TabContainer/Menu/MenuContent/MenuTitleEdit"), "Le champ titre du menu doit exister")

func test_has_menu_subtitle_edit():
	assert_true(_dialog.has_node("TabContainer/Menu/MenuContent/MenuSubtitleEdit"), "Le champ sous-titre doit exister")

func test_has_menu_bg_edit():
	assert_true(_dialog.has_node("TabContainer/Menu/MenuContent/BgHBox/MenuBgEdit"), "Le champ image de fond doit exister")

func test_has_browse_button():
	assert_true(_dialog.has_node("TabContainer/Menu/MenuContent/BgHBox/BrowseButton"), "Le bouton Parcourir doit exister")

func test_has_clear_bg_button():
	assert_true(_dialog.has_node("TabContainer/Menu/MenuContent/BgHBox/ClearBgButton"), "Le bouton de suppression doit exister")

func test_has_bg_preview():
	assert_true(_dialog.has_node("TabContainer/Menu/MenuContent/BgPreview"), "L'aperçu doit exister")

func test_bg_edit_is_readonly():
	assert_false(_dialog._menu_bg_edit.editable, "Le champ background doit être en lecture seule")

func test_bg_preview_size():
	assert_eq(_dialog._bg_preview.custom_minimum_size, Vector2(200, 112))

# --- Setup ---

func test_setup_fills_fields():
	var story = _make_story("Titre Menu", "Sous-titre", "/path/to/bg.png")
	_dialog.setup(story, "/tmp/test_story")
	assert_eq(_dialog.get_menu_title(), "Titre Menu")
	assert_eq(_dialog.get_menu_subtitle(), "Sous-titre")
	assert_eq(_dialog.get_menu_background(), "/path/to/bg.png")

func test_setup_with_empty_fields():
	var story = _make_story()
	_dialog.setup(story, "/tmp/test_story")
	assert_eq(_dialog.get_menu_title(), "")
	assert_eq(_dialog.get_menu_subtitle(), "")
	assert_eq(_dialog.get_menu_background(), "")

# --- Signal ---
# Note : le signal a 14 paramètres, ce qui dépasse la limite de GUT watch_signals (9 max).
# On utilise une connexion directe avec lambda pour capturer les paramètres.

func test_menu_config_confirmed_signal_exists():
	assert_has_signal(_dialog, "menu_config_confirmed")

func test_confirmed_emits_signal():
	var story = _make_story("Mon Titre", "Mon Sous-titre", "bg.png")
	_dialog.setup(story, "/tmp/test_story")
	var emitted := [false]
	_dialog.menu_config_confirmed.connect(func(_a,_b,_c,_d,_e,_f,_g,_h,_i,_j,_k,_l,_m,_n,_o,_p): emitted[0] = true)
	_dialog._on_confirmed()
	assert_true(emitted[0], "Le signal menu_config_confirmed doit être émis")

func test_confirmed_signal_params():
	var story = _make_story("T", "S", "B")
	_dialog.setup(story, "/tmp/test_story")
	var captured := []
	_dialog.menu_config_confirmed.connect(func(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p): captured.append_array([a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p]))
	_dialog._on_confirmed()
	assert_eq(captured[0], "T")
	assert_eq(captured[1], "S")
	assert_eq(captured[2], "B")

# --- Clear background ---

func test_clear_bg_clears_field():
	var story = _make_story("", "", "/path/to/bg.png")
	_dialog.setup(story, "/tmp/test_story")
	_dialog._on_clear_bg_pressed()
	assert_eq(_dialog.get_menu_background(), "")

func test_clear_bg_clears_preview():
	var story = _make_story()
	_dialog.setup(story, "/tmp/test_story")
	_dialog._on_clear_bg_pressed()
	assert_null(_dialog._bg_preview.texture)

# --- Getters ---

func test_get_menu_title():
	_dialog._menu_title_edit.text = "Test Title"
	assert_eq(_dialog.get_menu_title(), "Test Title")

func test_get_menu_subtitle():
	_dialog._menu_subtitle_edit.text = "Test Sub"
	assert_eq(_dialog.get_menu_subtitle(), "Test Sub")

func test_get_menu_background():
	_dialog._menu_bg_edit.text = "test.png"
	assert_eq(_dialog.get_menu_background(), "test.png")


# --- Liens externes ---

func test_has_patreon_url_edit():
	assert_true(_dialog.has_node("TabContainer/Liens/PatreonUrlEdit"), "Le champ URL Patreon doit exister")

func test_has_itchio_url_edit():
	assert_true(_dialog.has_node("TabContainer/Liens/ItchioUrlEdit"), "Le champ URL itch.io doit exister")

func test_get_patreon_url():
	_dialog._patreon_url_edit.text = "https://www.patreon.com/test"
	assert_eq(_dialog.get_patreon_url(), "https://www.patreon.com/test")

func test_get_itchio_url():
	_dialog._itchio_url_edit.text = "https://mygame.itch.io/game"
	assert_eq(_dialog.get_itchio_url(), "https://mygame.itch.io/game")

func test_setup_fills_link_fields():
	var story = _make_story()
	story.patreon_url = "https://www.patreon.com/test"
	story.itchio_url = "https://mygame.itch.io/game"
	_dialog.setup(story, "/tmp/test_story")
	assert_eq(_dialog.get_patreon_url(), "https://www.patreon.com/test")
	assert_eq(_dialog.get_itchio_url(), "https://mygame.itch.io/game")

func test_confirmed_signal_includes_links():
	var story = _make_story("T", "S", "B")
	story.patreon_url = "https://www.patreon.com/test"
	story.itchio_url = "https://test.itch.io/game"
	_dialog.setup(story, "/tmp/test_story")
	var captured := []
	_dialog.menu_config_confirmed.connect(func(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p): captured.append_array([a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p]))
	_dialog._on_confirmed()
	assert_eq(captured[6], "https://www.patreon.com/test")
	assert_eq(captured[7], "https://test.itch.io/game")

func test_validate_url_rejects_invalid():
	var story = _make_story()
	_dialog.setup(story, "/tmp/test_story")
	_dialog._patreon_url_edit.text = "not-a-url"
	_dialog._itchio_url_edit.text = "ftp://invalid.com"
	var captured := []
	_dialog.menu_config_confirmed.connect(func(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p): captured.append_array([a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p]))
	_dialog._on_confirmed()
	assert_eq(captured[6], "", "URL invalide doit être traitée comme vide")
	assert_eq(captured[7], "", "URL invalide doit être traitée comme vide")

func test_validate_url_accepts_https():
	var story = _make_story()
	_dialog.setup(story, "/tmp/test_story")
	_dialog._patreon_url_edit.text = "https://www.patreon.com/test"
	var captured := []
	_dialog.menu_config_confirmed.connect(func(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p): captured.append_array([a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p]))
	_dialog._on_confirmed()
	assert_eq(captured[6], "https://www.patreon.com/test")

func test_validate_url_accepts_http():
	var story = _make_story()
	_dialog.setup(story, "/tmp/test_story")
	_dialog._patreon_url_edit.text = "http://www.patreon.com/test"
	var captured := []
	_dialog.menu_config_confirmed.connect(func(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p): captured.append_array([a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p]))
	_dialog._on_confirmed()
	assert_eq(captured[6], "http://www.patreon.com/test")


# --- Écran Game Over ---

func test_has_game_over_bg_edit():
	assert_true(_dialog.has_node("TabContainer/GameOver/GameOverBgHBox/GameOverBgEdit"))

func test_has_game_over_browse_button():
	assert_true(_dialog.has_node("TabContainer/GameOver/GameOverBgHBox/GameOverBrowseButton"))

func test_has_game_over_clear_button():
	assert_true(_dialog.has_node("TabContainer/GameOver/GameOverBgHBox/GameOverClearBgButton"))

func test_has_game_over_bg_preview():
	assert_true(_dialog.has_node("TabContainer/GameOver/GameOverBgPreview"))

func test_has_game_over_title_edit():
	assert_true(_dialog.has_node("TabContainer/GameOver/GameOverTitleEdit"))

func test_has_game_over_subtitle_edit():
	assert_true(_dialog.has_node("TabContainer/GameOver/GameOverSubtitleEdit"))

func test_game_over_bg_edit_readonly():
	assert_false(_dialog._game_over_bg_edit.editable)

func test_setup_fills_game_over_fields():
	var story = _make_story()
	story.game_over_title = "Game Over!"
	story.game_over_subtitle = "Tu as perdu"
	story.game_over_background = "bg.png"
	_dialog.setup(story, "/tmp")
	assert_eq(_dialog.get_game_over_title(), "Game Over!")
	assert_eq(_dialog.get_game_over_subtitle(), "Tu as perdu")
	assert_eq(_dialog.get_game_over_background(), "bg.png")

func test_clear_game_over_bg():
	var story = _make_story()
	story.game_over_background = "bg.png"
	_dialog.setup(story, "/tmp")
	_dialog._on_game_over_clear_bg_pressed()
	assert_eq(_dialog.get_game_over_background(), "")
	assert_null(_dialog._game_over_bg_preview.texture)


# --- Écran To Be Continued ---

func test_has_to_be_continued_bg_edit():
	assert_true(_dialog.has_node("TabContainer/ASuivre/ToBeContinuedBgHBox/ToBeContinuedBgEdit"))

func test_has_to_be_continued_browse_button():
	assert_true(_dialog.has_node("TabContainer/ASuivre/ToBeContinuedBgHBox/ToBeContinuedBrowseButton"))

func test_has_to_be_continued_clear_button():
	assert_true(_dialog.has_node("TabContainer/ASuivre/ToBeContinuedBgHBox/ToBeContinuedClearBgButton"))

func test_has_to_be_continued_bg_preview():
	assert_true(_dialog.has_node("TabContainer/ASuivre/ToBeContinuedBgPreview"))

func test_has_to_be_continued_title_edit():
	assert_true(_dialog.has_node("TabContainer/ASuivre/ToBeContinuedTitleEdit"))

func test_has_to_be_continued_subtitle_edit():
	assert_true(_dialog.has_node("TabContainer/ASuivre/ToBeContinuedSubtitleEdit"))

func test_setup_fills_to_be_continued_fields():
	var story = _make_story()
	story.to_be_continued_title = "À suivre..."
	story.to_be_continued_subtitle = "Episode 2"
	story.to_be_continued_background = "tbc.png"
	_dialog.setup(story, "/tmp")
	assert_eq(_dialog.get_to_be_continued_title(), "À suivre...")
	assert_eq(_dialog.get_to_be_continued_subtitle(), "Episode 2")
	assert_eq(_dialog.get_to_be_continued_background(), "tbc.png")

func test_clear_to_be_continued_bg():
	var story = _make_story()
	story.to_be_continued_background = "tbc.png"
	_dialog.setup(story, "/tmp")
	_dialog._on_tbc_clear_bg_pressed()
	assert_eq(_dialog.get_to_be_continued_background(), "")
	assert_null(_dialog._to_be_continued_bg_preview.texture)

func test_confirmed_signal_includes_ending_screen_params():
	var story = _make_story("T", "S", "B")
	story.game_over_title = "GO"
	story.game_over_subtitle = "GOS"
	story.game_over_background = "gobg.png"
	story.to_be_continued_title = "TBC"
	story.to_be_continued_subtitle = "TBCS"
	story.to_be_continued_background = "tbcbg.png"
	_dialog.setup(story, "/tmp")
	var captured := []
	_dialog.menu_config_confirmed.connect(func(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p): captured.append_array([a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p]))
	_dialog._on_confirmed()
	assert_eq(captured[8], "GO")
	assert_eq(captured[9], "GOS")
	assert_eq(captured[10], "gobg.png")
	assert_eq(captured[11], "TBC")
	assert_eq(captured[12], "TBCS")
	assert_eq(captured[13], "tbcbg.png")


# --- Section Icône (dans l'onglet Menu) ---

func test_has_app_icon_edit():
	assert_true(_dialog.has_node("TabContainer/Menu/MenuContent/IconHBox/AppIconEdit"))

func test_has_icon_browse_button():
	assert_true(_dialog.has_node("TabContainer/Menu/MenuContent/IconHBox/IconBrowseButton"))

func test_has_icon_clear_button():
	assert_true(_dialog.has_node("TabContainer/Menu/MenuContent/IconHBox/IconClearButton"))

func test_has_icon_preview():
	assert_true(_dialog.has_node("TabContainer/Menu/MenuContent/IconPreview"))

func test_has_icon_warning():
	assert_true(_dialog.has_node("TabContainer/Menu/MenuContent/IconWarning"))

func test_icon_edit_is_readonly():
	assert_false(_dialog._app_icon_edit.editable)

func test_icon_preview_size():
	assert_eq(_dialog._app_icon_preview.custom_minimum_size, Vector2(100, 100))

func test_icon_warning_hidden_by_default():
	assert_false(_dialog._app_icon_warning.visible)

func test_setup_fills_app_icon():
	var story = _make_story()
	story.app_icon = "my_icon.png"
	_dialog.setup(story, "/tmp")
	assert_eq(_dialog.get_app_icon(), "my_icon.png")

func test_setup_empty_app_icon():
	var story = _make_story()
	_dialog.setup(story, "/tmp")
	assert_eq(_dialog.get_app_icon(), "")

func test_clear_icon():
	var story = _make_story()
	story.app_icon = "icon.png"
	_dialog.setup(story, "/tmp")
	_dialog._on_icon_clear_pressed()
	assert_eq(_dialog.get_app_icon(), "")
	assert_null(_dialog._app_icon_preview.texture)
	assert_false(_dialog._app_icon_warning.visible)

func test_confirmed_signal_includes_app_icon():
	var story = _make_story("T", "S", "B")
	story.app_icon = "myicon.png"
	_dialog.setup(story, "/tmp")
	var captured := []
	_dialog.menu_config_confirmed.connect(func(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p): captured.append_array([a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p]))
	_dialog._on_confirmed()
	assert_eq(captured[14], "myicon.png")


# --- Bandeau titre ---

func test_has_show_title_banner_check():
	assert_true(_dialog.has_node("TabContainer/Menu/MenuContent/ShowTitleBannerCheck"))

func test_show_title_banner_default_true():
	assert_true(_dialog._show_title_banner_check.button_pressed)

func test_get_show_title_banner():
	_dialog._show_title_banner_check.button_pressed = false
	assert_false(_dialog.get_show_title_banner())

func test_setup_fills_show_title_banner_true():
	var story = _make_story()
	story.show_title_banner = true
	_dialog.setup(story, "/tmp")
	assert_true(_dialog.get_show_title_banner())

func test_setup_fills_show_title_banner_false():
	var story = _make_story()
	story.show_title_banner = false
	_dialog.setup(story, "/tmp")
	assert_false(_dialog.get_show_title_banner())

func test_confirmed_signal_includes_show_title_banner():
	var story = _make_story("T", "S", "B")
	story.show_title_banner = false
	_dialog.setup(story, "/tmp")
	var captured := []
	_dialog.menu_config_confirmed.connect(func(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p): captured.append_array([a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p]))
	_dialog._on_confirmed()
	assert_false(captured[15])
