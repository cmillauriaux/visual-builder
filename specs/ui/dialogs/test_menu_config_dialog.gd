extends GutTest

# Tests pour le dialogue de configuration du menu

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

func test_title_is_configurer_le_menu():
	assert_eq(_dialog.title, "Configurer le menu")

func test_has_menu_title_edit():
	assert_true(_dialog.has_node("ContentVBox/MenuTitleEdit"), "Le champ titre du menu doit exister")

func test_has_menu_subtitle_edit():
	assert_true(_dialog.has_node("ContentVBox/MenuSubtitleEdit"), "Le champ sous-titre doit exister")

func test_has_menu_bg_edit():
	assert_true(_dialog.has_node("ContentVBox/BgHBox/MenuBgEdit"), "Le champ image de fond doit exister")

func test_has_browse_button():
	assert_true(_dialog.has_node("ContentVBox/BgHBox/BrowseButton"), "Le bouton Parcourir doit exister")

func test_has_clear_bg_button():
	assert_true(_dialog.has_node("ContentVBox/BgHBox/ClearBgButton"), "Le bouton de suppression doit exister")

func test_has_bg_preview():
	assert_true(_dialog.has_node("ContentVBox/BgPreview"), "L'aperçu doit exister")

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

func test_menu_config_confirmed_signal_exists():
	assert_has_signal(_dialog, "menu_config_confirmed")

func test_confirmed_emits_signal():
	var story = _make_story("Mon Titre", "Mon Sous-titre", "bg.png")
	_dialog.setup(story, "/tmp/test_story")
	watch_signals(_dialog)
	_dialog._on_confirmed()
	assert_signal_emitted(_dialog, "menu_config_confirmed")

func test_confirmed_signal_params():
	var story = _make_story("T", "S", "B")
	_dialog.setup(story, "/tmp/test_story")
	watch_signals(_dialog)
	_dialog._on_confirmed()
	var params = get_signal_parameters(_dialog, "menu_config_confirmed")
	assert_eq(params[0], "T")
	assert_eq(params[1], "S")
	assert_eq(params[2], "B")

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
	assert_true(_dialog.has_node("ContentVBox/PatreonUrlEdit"), "Le champ URL Patreon doit exister")

func test_has_itchio_url_edit():
	assert_true(_dialog.has_node("ContentVBox/ItchioUrlEdit"), "Le champ URL itch.io doit exister")

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
	watch_signals(_dialog)
	_dialog._on_confirmed()
	var params = get_signal_parameters(_dialog, "menu_config_confirmed")
	assert_eq(params[6], "https://www.patreon.com/test")
	assert_eq(params[7], "https://test.itch.io/game")

func test_validate_url_rejects_invalid():
	var story = _make_story()
	_dialog.setup(story, "/tmp/test_story")
	_dialog._patreon_url_edit.text = "not-a-url"
	_dialog._itchio_url_edit.text = "ftp://invalid.com"
	watch_signals(_dialog)
	_dialog._on_confirmed()
	var params = get_signal_parameters(_dialog, "menu_config_confirmed")
	assert_eq(params[6], "", "URL invalide doit être traitée comme vide")
	assert_eq(params[7], "", "URL invalide doit être traitée comme vide")

func test_validate_url_accepts_https():
	var story = _make_story()
	_dialog.setup(story, "/tmp/test_story")
	_dialog._patreon_url_edit.text = "https://www.patreon.com/test"
	watch_signals(_dialog)
	_dialog._on_confirmed()
	var params = get_signal_parameters(_dialog, "menu_config_confirmed")
	assert_eq(params[6], "https://www.patreon.com/test")

func test_validate_url_accepts_http():
	var story = _make_story()
	_dialog.setup(story, "/tmp/test_story")
	_dialog._patreon_url_edit.text = "http://www.patreon.com/test"
	watch_signals(_dialog)
	_dialog._on_confirmed()
	var params = get_signal_parameters(_dialog, "menu_config_confirmed")
	assert_eq(params[6], "http://www.patreon.com/test")
