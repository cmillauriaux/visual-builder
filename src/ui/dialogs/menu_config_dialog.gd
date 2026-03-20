extends ConfirmationDialog

## Dialogue de configuration du jeu (menu, analytics, liens, écrans de fin).

signal menu_config_confirmed(menu_title: String, menu_subtitle: String, menu_background: String, menu_music: String, patreon_url: String, itchio_url: String, game_over_title: String, game_over_subtitle: String, game_over_background: String, to_be_continued_title: String, to_be_continued_subtitle: String, to_be_continued_background: String, app_icon: String, show_title_banner: bool, ui_theme_mode: String, plugin_settings: Dictionary)

const ImagePickerDialogScript = preload("res://src/ui/dialogs/image_picker_dialog.gd")
const AudioPickerDialogScript = preload("res://src/ui/dialogs/audio_picker_dialog.gd")

const UI_THEME_ASSETS = [
	"button_brown.png", "button_red.png", "button_red_close.png",
	"panel_brown.png", "panel_brown_dark.png", "banner_hanging.png",
	"checkbox_brown_empty.png", "checkbox_brown_checked.png"
]

var _menu_title_edit: LineEdit
var _menu_subtitle_edit: LineEdit
var _menu_bg_edit: LineEdit
var _browse_button: Button
var _clear_bg_button: Button
var _bg_preview: TextureRect
var _menu_music_label: Label
var _clear_music_button: Button
var _patreon_url_edit: LineEdit
var _itchio_url_edit: LineEdit
var _game_over_bg_edit: LineEdit
var _game_over_bg_preview: TextureRect
var _game_over_title_edit: LineEdit
var _game_over_subtitle_edit: LineEdit
var _to_be_continued_bg_edit: LineEdit
var _to_be_continued_bg_preview: TextureRect
var _to_be_continued_title_edit: LineEdit
var _to_be_continued_subtitle_edit: LineEdit
var _app_icon_edit: LineEdit
var _app_icon_preview: TextureRect
var _app_icon_warning: Label
var _show_title_banner_check: CheckButton
# UI Theme tab
var _ui_theme_default_btn: Button
var _ui_theme_custom_btn: Button
var _ui_theme_default_panel: VBoxContainer
var _ui_theme_custom_panel: VBoxContainer
var _ui_theme_assets_list: VBoxContainer
var _ui_theme_mode: String = "default"
var _plugins_container: VBoxContainer
var _plugin_controls: Dictionary = {}  # plugin_name -> Control (editor config root)
var _game_plugins: Array = []  # loaded VBGamePlugin instances for editor config
var _story = null
var _story_base_path: String = ""
var _current_menu_music: String = ""


func _init():
	title = tr("Configurer le jeu")
	min_size = Vector2i(450, 450)

	var tabs = TabContainer.new()
	tabs.name = "TabContainer"
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# ── Onglet Menu ──────────────────────────────────────────────────────────
	var menu_vbox = VBoxContainer.new()
	menu_vbox.name = "Menu"
	menu_vbox.add_theme_constant_override("separation", 4)

	var title_lbl = Label.new()
	title_lbl.text = tr("Titre du menu")
	menu_vbox.add_child(title_lbl)

	_menu_title_edit = LineEdit.new()
	_menu_title_edit.name = "MenuTitleEdit"
	_menu_title_edit.placeholder_text = tr("Laissez vide pour utiliser le titre de l'histoire")
	menu_vbox.add_child(_menu_title_edit)

	var subtitle_lbl = Label.new()
	subtitle_lbl.text = tr("Sous-titre")
	menu_vbox.add_child(subtitle_lbl)

	_menu_subtitle_edit = LineEdit.new()
	_menu_subtitle_edit.name = "MenuSubtitleEdit"
	menu_vbox.add_child(_menu_subtitle_edit)

	_show_title_banner_check = CheckButton.new()
	_show_title_banner_check.name = "ShowTitleBannerCheck"
	_show_title_banner_check.text = tr("Afficher le bandeau titre / sous-titre")
	_show_title_banner_check.button_pressed = true
	menu_vbox.add_child(_show_title_banner_check)

	var bg_lbl = Label.new()
	bg_lbl.text = tr("Image de fond")
	menu_vbox.add_child(bg_lbl)

	var bg_hbox = HBoxContainer.new()
	bg_hbox.name = "BgHBox"

	_menu_bg_edit = LineEdit.new()
	_menu_bg_edit.name = "MenuBgEdit"
	_menu_bg_edit.editable = false
	_menu_bg_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bg_hbox.add_child(_menu_bg_edit)

	_browse_button = Button.new()
	_browse_button.name = "BrowseButton"
	_browse_button.text = tr("Parcourir...")
	_browse_button.pressed.connect(_on_browse_pressed)
	bg_hbox.add_child(_browse_button)

	_clear_bg_button = Button.new()
	_clear_bg_button.name = "ClearBgButton"
	_clear_bg_button.text = "✕"
	_clear_bg_button.pressed.connect(_on_clear_bg_pressed)
	bg_hbox.add_child(_clear_bg_button)

	menu_vbox.add_child(bg_hbox)

	_bg_preview = TextureRect.new()
	_bg_preview.name = "BgPreview"
	_bg_preview.custom_minimum_size = Vector2(200, 112)
	_bg_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	menu_vbox.add_child(_bg_preview)

	var music_lbl = Label.new()
	music_lbl.text = tr("Musique du menu")
	menu_vbox.add_child(music_lbl)

	var music_hbox = HBoxContainer.new()
	music_hbox.name = "MusicHBox"

	_menu_music_label = Label.new()
	_menu_music_label.name = "MenuMusicLabel"
	_menu_music_label.text = tr("Aucune musique")
	_menu_music_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu_music_label.clip_text = true
	_menu_music_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	music_hbox.add_child(_menu_music_label)

	var browse_music_btn = Button.new()
	browse_music_btn.name = "BrowseMusicButton"
	browse_music_btn.text = tr("Choisir...")
	browse_music_btn.pressed.connect(_on_browse_music_pressed)
	music_hbox.add_child(browse_music_btn)

	_clear_music_button = Button.new()
	_clear_music_button.name = "ClearMusicButton"
	_clear_music_button.text = "✕"
	_clear_music_button.pressed.connect(_on_clear_music_pressed)
	music_hbox.add_child(_clear_music_button)

	menu_vbox.add_child(music_hbox)

	# Section Icône (dans l'onglet Menu)
	var icon_sep = HSeparator.new()
	menu_vbox.add_child(icon_sep)

	var icon_lbl = Label.new()
	icon_lbl.text = tr("Icône de l'application")
	icon_lbl.add_theme_font_size_override("font_size", 16)
	menu_vbox.add_child(icon_lbl)

	var icon_info_lbl = Label.new()
	icon_info_lbl.text = tr("Image carrée, recommandé : 1024×1024")
	icon_info_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	menu_vbox.add_child(icon_info_lbl)

	var icon_hbox = HBoxContainer.new()
	icon_hbox.name = "IconHBox"

	_app_icon_edit = LineEdit.new()
	_app_icon_edit.name = "AppIconEdit"
	_app_icon_edit.editable = false
	_app_icon_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon_hbox.add_child(_app_icon_edit)

	var icon_browse_btn = Button.new()
	icon_browse_btn.name = "IconBrowseButton"
	icon_browse_btn.text = tr("Parcourir...")
	icon_browse_btn.pressed.connect(_on_icon_browse_pressed)
	icon_hbox.add_child(icon_browse_btn)

	var icon_clear_btn = Button.new()
	icon_clear_btn.name = "IconClearButton"
	icon_clear_btn.text = "✕"
	icon_clear_btn.pressed.connect(_on_icon_clear_pressed)
	icon_hbox.add_child(icon_clear_btn)

	menu_vbox.add_child(icon_hbox)

	_app_icon_preview = TextureRect.new()
	_app_icon_preview.name = "IconPreview"
	_app_icon_preview.custom_minimum_size = Vector2(100, 100)
	_app_icon_preview.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_app_icon_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_app_icon_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	menu_vbox.add_child(_app_icon_preview)

	_app_icon_warning = Label.new()
	_app_icon_warning.name = "IconWarning"
	_app_icon_warning.text = tr("L'image n'est pas carrée — elle sera déformée")
	_app_icon_warning.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	_app_icon_warning.visible = false
	menu_vbox.add_child(_app_icon_warning)

	# Envelopper l'onglet Menu dans un ScrollContainer
	var menu_scroll = ScrollContainer.new()
	menu_scroll.name = "Menu"
	menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu_vbox.name = "MenuContent"
	menu_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(menu_scroll)
	menu_scroll.add_child(menu_vbox)

	# ── Onglet Plugins ──────────────────────────────────────────────────────
	var plugins_scroll = ScrollContainer.new()
	plugins_scroll.name = "Plugins"
	plugins_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_plugins_container = VBoxContainer.new()
	_plugins_container.name = "PluginsContent"
	_plugins_container.add_theme_constant_override("separation", 8)
	_plugins_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plugins_scroll.add_child(_plugins_container)
	tabs.add_child(plugins_scroll)

	# ── Onglet Liens ─────────────────────────────────────────────────────────
	var liens_vbox = VBoxContainer.new()
	liens_vbox.name = "Liens"
	liens_vbox.add_theme_constant_override("separation", 4)

	var patreon_lbl = Label.new()
	patreon_lbl.text = tr("URL Patreon")
	liens_vbox.add_child(patreon_lbl)

	_patreon_url_edit = LineEdit.new()
	_patreon_url_edit.name = "PatreonUrlEdit"
	_patreon_url_edit.placeholder_text = "https://www.patreon.com/..."
	liens_vbox.add_child(_patreon_url_edit)

	var itchio_lbl = Label.new()
	itchio_lbl.text = tr("URL itch.io")
	liens_vbox.add_child(itchio_lbl)

	_itchio_url_edit = LineEdit.new()
	_itchio_url_edit.name = "ItchioUrlEdit"
	_itchio_url_edit.placeholder_text = tr("https://votrejeu.itch.io/...")
	liens_vbox.add_child(_itchio_url_edit)

	tabs.add_child(liens_vbox)

	# ── Onglet Game Over ─────────────────────────────────────────────────────
	var go_vbox = VBoxContainer.new()
	go_vbox.name = "GameOver"
	go_vbox.add_theme_constant_override("separation", 4)

	var go_bg_lbl = Label.new()
	go_bg_lbl.text = tr("Image de fond")
	go_vbox.add_child(go_bg_lbl)

	var go_bg_hbox = HBoxContainer.new()
	go_bg_hbox.name = "GameOverBgHBox"

	_game_over_bg_edit = LineEdit.new()
	_game_over_bg_edit.name = "GameOverBgEdit"
	_game_over_bg_edit.editable = false
	_game_over_bg_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go_bg_hbox.add_child(_game_over_bg_edit)

	var go_browse_btn = Button.new()
	go_browse_btn.name = "GameOverBrowseButton"
	go_browse_btn.text = tr("Parcourir...")
	go_browse_btn.pressed.connect(_on_game_over_browse_pressed)
	go_bg_hbox.add_child(go_browse_btn)

	var go_clear_btn = Button.new()
	go_clear_btn.name = "GameOverClearBgButton"
	go_clear_btn.text = "✕"
	go_clear_btn.pressed.connect(_on_game_over_clear_bg_pressed)
	go_bg_hbox.add_child(go_clear_btn)

	go_vbox.add_child(go_bg_hbox)

	_game_over_bg_preview = TextureRect.new()
	_game_over_bg_preview.name = "GameOverBgPreview"
	_game_over_bg_preview.custom_minimum_size = Vector2(200, 112)
	_game_over_bg_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_game_over_bg_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	go_vbox.add_child(_game_over_bg_preview)

	var go_title_lbl = Label.new()
	go_title_lbl.text = tr("Titre")
	go_vbox.add_child(go_title_lbl)

	_game_over_title_edit = LineEdit.new()
	_game_over_title_edit.name = "GameOverTitleEdit"
	_game_over_title_edit.placeholder_text = "Game Over"
	go_vbox.add_child(_game_over_title_edit)

	var go_subtitle_lbl = Label.new()
	go_subtitle_lbl.text = tr("Sous-titre")
	go_vbox.add_child(go_subtitle_lbl)

	_game_over_subtitle_edit = LineEdit.new()
	_game_over_subtitle_edit.name = "GameOverSubtitleEdit"
	go_vbox.add_child(_game_over_subtitle_edit)

	tabs.add_child(go_vbox)

	# ── Onglet À suivre ───────────────────────────────────────────────────────
	var tbc_vbox = VBoxContainer.new()
	tbc_vbox.name = "ASuivre"
	tbc_vbox.add_theme_constant_override("separation", 4)

	var tbc_bg_lbl = Label.new()
	tbc_bg_lbl.text = tr("Image de fond")
	tbc_vbox.add_child(tbc_bg_lbl)

	var tbc_bg_hbox = HBoxContainer.new()
	tbc_bg_hbox.name = "ToBeContinuedBgHBox"

	_to_be_continued_bg_edit = LineEdit.new()
	_to_be_continued_bg_edit.name = "ToBeContinuedBgEdit"
	_to_be_continued_bg_edit.editable = false
	_to_be_continued_bg_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tbc_bg_hbox.add_child(_to_be_continued_bg_edit)

	var tbc_browse_btn = Button.new()
	tbc_browse_btn.name = "ToBeContinuedBrowseButton"
	tbc_browse_btn.text = tr("Parcourir...")
	tbc_browse_btn.pressed.connect(_on_tbc_browse_pressed)
	tbc_bg_hbox.add_child(tbc_browse_btn)

	var tbc_clear_btn = Button.new()
	tbc_clear_btn.name = "ToBeContinuedClearBgButton"
	tbc_clear_btn.text = "✕"
	tbc_clear_btn.pressed.connect(_on_tbc_clear_bg_pressed)
	tbc_bg_hbox.add_child(tbc_clear_btn)

	tbc_vbox.add_child(tbc_bg_hbox)

	_to_be_continued_bg_preview = TextureRect.new()
	_to_be_continued_bg_preview.name = "ToBeContinuedBgPreview"
	_to_be_continued_bg_preview.custom_minimum_size = Vector2(200, 112)
	_to_be_continued_bg_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_to_be_continued_bg_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tbc_vbox.add_child(_to_be_continued_bg_preview)

	var tbc_title_lbl = Label.new()
	tbc_title_lbl.text = tr("Titre")
	tbc_vbox.add_child(tbc_title_lbl)

	_to_be_continued_title_edit = LineEdit.new()
	_to_be_continued_title_edit.name = "ToBeContinuedTitleEdit"
	_to_be_continued_title_edit.placeholder_text = tr("À suivre...")
	tbc_vbox.add_child(_to_be_continued_title_edit)

	var tbc_subtitle_lbl = Label.new()
	tbc_subtitle_lbl.text = tr("Sous-titre")
	tbc_vbox.add_child(tbc_subtitle_lbl)

	_to_be_continued_subtitle_edit = LineEdit.new()
	_to_be_continued_subtitle_edit.name = "ToBeContinuedSubtitleEdit"
	tbc_vbox.add_child(_to_be_continued_subtitle_edit)

	tabs.add_child(tbc_vbox)

	# ── Onglet Thème UI ──────────────────────────────────────────────────────────
	var ui_theme_vbox = VBoxContainer.new()
	ui_theme_vbox.name = "ThemeUI"
	ui_theme_vbox.add_theme_constant_override("separation", 8)

	# Boutons radio (ButtonGroup)
	var bg = ButtonGroup.new()
	var mode_hbox = HBoxContainer.new()
	mode_hbox.add_theme_constant_override("separation", 4)

	_ui_theme_default_btn = Button.new()
	_ui_theme_default_btn.name = "DefaultBtn"
	_ui_theme_default_btn.text = tr("Par défaut")
	_ui_theme_default_btn.toggle_mode = true
	_ui_theme_default_btn.button_group = bg
	_ui_theme_default_btn.button_pressed = true
	mode_hbox.add_child(_ui_theme_default_btn)

	_ui_theme_custom_btn = Button.new()
	_ui_theme_custom_btn.name = "CustomBtn"
	_ui_theme_custom_btn.text = tr("Personnaliser")
	_ui_theme_custom_btn.toggle_mode = true
	_ui_theme_custom_btn.button_group = bg
	mode_hbox.add_child(_ui_theme_custom_btn)

	ui_theme_vbox.add_child(mode_hbox)

	# Panneau mode défaut
	_ui_theme_default_panel = VBoxContainer.new()
	_ui_theme_default_panel.name = "DefaultPanel"
	var default_label = Label.new()
	default_label.text = tr("Thème Kenney Adventure (par défaut)")
	_ui_theme_default_panel.add_child(default_label)
	var default_desc = Label.new()
	default_desc.text = tr("Le jeu utilisera le thème brun aventure intégré.")
	default_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	_ui_theme_default_panel.add_child(default_desc)
	ui_theme_vbox.add_child(_ui_theme_default_panel)

	# Panneau mode personnalisé
	_ui_theme_custom_panel = VBoxContainer.new()
	_ui_theme_custom_panel.name = "CustomPanel"
	_ui_theme_custom_panel.visible = false
	_ui_theme_custom_panel.add_theme_constant_override("separation", 4)

	var assets_label = Label.new()
	assets_label.name = "AssetsCountLabel"
	assets_label.text = tr("Assets personnalisés (0 / 8)")
	_ui_theme_custom_panel.add_child(assets_label)

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 150)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_ui_theme_assets_list = VBoxContainer.new()
	_ui_theme_assets_list.name = "AssetsList"
	_ui_theme_assets_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_ui_theme_assets_list)
	_ui_theme_custom_panel.add_child(scroll)

	var browse_all_btn = Button.new()
	browse_all_btn.name = "BrowseAllButton"
	browse_all_btn.text = tr("📂 Parcourir…")
	browse_all_btn.pressed.connect(_on_browse_ui_assets_pressed)
	_ui_theme_custom_panel.add_child(browse_all_btn)

	ui_theme_vbox.add_child(_ui_theme_custom_panel)
	tabs.add_child(ui_theme_vbox)

	# Connexions
	_ui_theme_default_btn.toggled.connect(_on_ui_theme_mode_toggled.bind("default"))
	_ui_theme_custom_btn.toggled.connect(_on_ui_theme_mode_toggled.bind("custom"))

	# Titres des onglets (après ajout des enfants)
	tabs.set_tab_title(0, tr("Menu"))
	tabs.set_tab_title(1, tr("Plugins"))
	tabs.set_tab_title(2, tr("Liens"))
	tabs.set_tab_title(3, tr("Game Over"))
	tabs.set_tab_title(4, tr("À suivre"))
	tabs.set_tab_title(5, tr("Thème UI"))

	add_child(tabs)
	confirmed.connect(_on_confirmed)


func setup(story, story_base_path: String = "") -> void:
	_menu_title_edit.text = story.menu_title
	_menu_subtitle_edit.text = story.menu_subtitle
	_menu_bg_edit.text = story.menu_background
	_patreon_url_edit.text = story.patreon_url if story.get("patreon_url") != null else ""
	_itchio_url_edit.text = story.itchio_url if story.get("itchio_url") != null else ""
	_game_over_bg_edit.text = story.game_over_background if story.get("game_over_background") != null else ""
	_game_over_title_edit.text = story.game_over_title if story.get("game_over_title") != null else ""
	_game_over_subtitle_edit.text = story.game_over_subtitle if story.get("game_over_subtitle") != null else ""
	_to_be_continued_bg_edit.text = story.to_be_continued_background if story.get("to_be_continued_background") != null else ""
	_to_be_continued_title_edit.text = story.to_be_continued_title if story.get("to_be_continued_title") != null else ""
	_to_be_continued_subtitle_edit.text = story.to_be_continued_subtitle if story.get("to_be_continued_subtitle") != null else ""
	_app_icon_edit.text = story.app_icon if story.get("app_icon") != null else ""
	_show_title_banner_check.button_pressed = story.show_title_banner if story.get("show_title_banner") != null else true
	_story = story
	_story_base_path = story_base_path
	_ui_theme_mode = story.ui_theme_mode if story.get("ui_theme_mode") != null else "default"
	if _ui_theme_mode == "custom":
		_ui_theme_custom_btn.button_pressed = true
	else:
		_ui_theme_default_btn.button_pressed = true
	_ui_theme_default_panel.visible = (_ui_theme_mode == "default")
	_ui_theme_custom_panel.visible = (_ui_theme_mode == "custom")
	_refresh_ui_theme_assets_list()
	_current_menu_music = story.menu_music if story.get("menu_music") != null else ""
	_update_menu_music_label()
	_update_preview()
	_update_game_over_preview()
	_update_tbc_preview()
	_update_icon_preview()
	_rebuild_plugins_tab()


func get_menu_title() -> String:
	return _menu_title_edit.text

func get_menu_subtitle() -> String:
	return _menu_subtitle_edit.text

func get_menu_background() -> String:
	return _menu_bg_edit.text

func get_menu_music() -> String:
	return _current_menu_music

func get_patreon_url() -> String:
	return _patreon_url_edit.text

func get_itchio_url() -> String:
	return _itchio_url_edit.text

func get_game_over_title() -> String:
	return _game_over_title_edit.text

func get_game_over_subtitle() -> String:
	return _game_over_subtitle_edit.text

func get_game_over_background() -> String:
	return _game_over_bg_edit.text

func get_to_be_continued_title() -> String:
	return _to_be_continued_title_edit.text

func get_to_be_continued_subtitle() -> String:
	return _to_be_continued_subtitle_edit.text

func get_to_be_continued_background() -> String:
	return _to_be_continued_bg_edit.text

func get_app_icon() -> String:
	return _app_icon_edit.text

func get_show_title_banner() -> bool:
	return _show_title_banner_check.button_pressed

func get_ui_theme_mode() -> String:
	return _ui_theme_mode


# ── Utilitaires chemins ──────────────────────────────────────────────────────

func _to_relative_path(abs_path: String) -> String:
	if abs_path == "" or _story_base_path == "":
		return abs_path
	var prefix = _story_base_path + "/"
	if abs_path.begins_with(prefix):
		return abs_path.substr(prefix.length())
	return abs_path

func _resolve_path(rel_path: String) -> String:
	if rel_path == "":
		return ""
	if rel_path.begins_with("/") or rel_path.begins_with("user://") or rel_path.begins_with("res://"):
		return rel_path
	if _story_base_path != "":
		return _story_base_path + "/" + rel_path
	return rel_path

# ── Handlers Menu ────────────────────────────────────────────────────────────

func _on_browse_pressed() -> void:
	var picker = Window.new()
	picker.set_script(ImagePickerDialogScript)
	add_child(picker)
	picker.setup(ImagePickerDialogScript.Mode.BACKGROUND, _story_base_path, _story)
	picker.image_selected.connect(_on_bg_image_selected)
	picker.popup_centered()

func _on_bg_image_selected(path: String) -> void:
	_menu_bg_edit.text = _to_relative_path(path)
	_update_preview()

func _on_clear_bg_pressed() -> void:
	_menu_bg_edit.text = ""
	_bg_preview.texture = null

func _on_browse_music_pressed() -> void:
	var picker = Window.new()
	picker.set_script(AudioPickerDialogScript)
	add_child(picker)
	picker.setup(AudioPickerDialogScript.Mode.MUSIC, _story_base_path)
	picker.audio_selected.connect(_on_menu_music_selected)
	picker.popup_centered()

func _on_menu_music_selected(path: String) -> void:
	_current_menu_music = path
	_update_menu_music_label()

func _on_clear_music_pressed() -> void:
	_current_menu_music = ""
	_update_menu_music_label()

func _update_menu_music_label() -> void:
	if _menu_music_label == null:
		return
	if _current_menu_music != "":
		_menu_music_label.text = _current_menu_music.get_file()
		_menu_music_label.add_theme_color_override("font_color", Color.WHITE)
	else:
		_menu_music_label.text = tr("Aucune musique")
		_menu_music_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))

func _update_preview() -> void:
	if _menu_bg_edit.text == "":
		_bg_preview.texture = null
		return
	var resolved := _resolve_path(_menu_bg_edit.text)
	if not FileAccess.file_exists(resolved):
		_bg_preview.texture = null
		return
	var img = Image.new()
	if img.load(resolved) == OK:
		_bg_preview.texture = ImageTexture.create_from_image(img)
	else:
		_bg_preview.texture = null


# ── Handlers Game Over ───────────────────────────────────────────────────────

func _on_game_over_browse_pressed() -> void:
	var picker = Window.new()
	picker.set_script(ImagePickerDialogScript)
	add_child(picker)
	picker.setup(ImagePickerDialogScript.Mode.BACKGROUND, _story_base_path, _story)
	picker.image_selected.connect(_on_game_over_bg_selected)
	picker.popup_centered()

func _on_game_over_bg_selected(path: String) -> void:
	_game_over_bg_edit.text = _to_relative_path(path)
	_update_game_over_preview()

func _on_game_over_clear_bg_pressed() -> void:
	_game_over_bg_edit.text = ""
	_game_over_bg_preview.texture = null

func _update_game_over_preview() -> void:
	if _game_over_bg_edit.text == "":
		_game_over_bg_preview.texture = null
		return
	var resolved := _resolve_path(_game_over_bg_edit.text)
	if not FileAccess.file_exists(resolved):
		_game_over_bg_preview.texture = null
		return
	var img = Image.new()
	if img.load(resolved) == OK:
		_game_over_bg_preview.texture = ImageTexture.create_from_image(img)
	else:
		_game_over_bg_preview.texture = null


# ── Handlers À suivre ────────────────────────────────────────────────────────

func _on_tbc_browse_pressed() -> void:
	var picker = Window.new()
	picker.set_script(ImagePickerDialogScript)
	add_child(picker)
	picker.setup(ImagePickerDialogScript.Mode.BACKGROUND, _story_base_path, _story)
	picker.image_selected.connect(_on_tbc_bg_selected)
	picker.popup_centered()

func _on_tbc_bg_selected(path: String) -> void:
	_to_be_continued_bg_edit.text = _to_relative_path(path)
	_update_tbc_preview()

func _on_tbc_clear_bg_pressed() -> void:
	_to_be_continued_bg_edit.text = ""
	_to_be_continued_bg_preview.texture = null

func _update_tbc_preview() -> void:
	if _to_be_continued_bg_edit.text == "":
		_to_be_continued_bg_preview.texture = null
		return
	var resolved := _resolve_path(_to_be_continued_bg_edit.text)
	if not FileAccess.file_exists(resolved):
		_to_be_continued_bg_preview.texture = null
		return
	var img = Image.new()
	if img.load(resolved) == OK:
		_to_be_continued_bg_preview.texture = ImageTexture.create_from_image(img)
	else:
		_to_be_continued_bg_preview.texture = null


# ── Handlers Icône ───────────────────────────────────────────────────────────

func _on_icon_browse_pressed() -> void:
	var picker = Window.new()
	picker.set_script(ImagePickerDialogScript)
	add_child(picker)
	picker.setup(ImagePickerDialogScript.Mode.ICON, _story_base_path, _story)
	picker.image_selected.connect(_on_icon_selected)
	picker.popup_centered()

func _on_icon_selected(path: String) -> void:
	_app_icon_edit.text = _to_relative_path(path)
	_update_icon_preview()

func _on_icon_clear_pressed() -> void:
	_app_icon_edit.text = ""
	_app_icon_preview.texture = null
	_app_icon_warning.visible = false

func _update_icon_preview() -> void:
	if _app_icon_edit.text == "":
		_app_icon_preview.texture = null
		_app_icon_warning.visible = false
		return
	var resolved := _resolve_path(_app_icon_edit.text)
	if not FileAccess.file_exists(resolved):
		_app_icon_preview.texture = null
		_app_icon_warning.visible = false
		return
	var img = Image.new()
	if img.load(resolved) == OK:
		_app_icon_preview.texture = ImageTexture.create_from_image(img)
		_app_icon_warning.visible = img.get_width() != img.get_height()
	else:
		_app_icon_preview.texture = null
		_app_icon_warning.visible = false


# ── Confirmation ─────────────────────────────────────────────────────────────

static func _validate_url(url: String) -> String:
	var trimmed = url.strip_edges()
	if trimmed == "":
		return ""
	if trimmed.begins_with("http://") or trimmed.begins_with("https://"):
		return trimmed
	return ""

func _on_confirmed() -> void:
	menu_config_confirmed.emit(
		_menu_title_edit.text, _menu_subtitle_edit.text, _menu_bg_edit.text,
		_current_menu_music,
		_validate_url(_patreon_url_edit.text), _validate_url(_itchio_url_edit.text),
		_game_over_title_edit.text, _game_over_subtitle_edit.text, _game_over_bg_edit.text,
		_to_be_continued_title_edit.text, _to_be_continued_subtitle_edit.text, _to_be_continued_bg_edit.text,
		_app_icon_edit.text, _show_title_banner_check.button_pressed,
		_ui_theme_mode, _collect_plugin_settings()
	)


# ── Plugins tab ──────────────────────────────────────────────────────────────

func _rebuild_plugins_tab() -> void:
	if _plugins_container == null:
		return
	for child in _plugins_container.get_children():
		child.queue_free()
	_plugin_controls.clear()
	_game_plugins = _scan_game_plugins()
	if _game_plugins.is_empty():
		var lbl = Label.new()
		lbl.text = tr("Aucun plugin détecté")
		lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_plugins_container.add_child(lbl)
		return
	for plugin in _game_plugins:
		var pname: String = plugin.get_plugin_name()
		var editor_defs = plugin.get_editor_config_controls()
		if editor_defs.is_empty():
			continue
		var section_lbl = Label.new()
		section_lbl.text = plugin.get_plugin_description() if plugin.get_plugin_description() != "" else pname
		section_lbl.add_theme_font_size_override("font_size", 16)
		_plugins_container.add_child(section_lbl)
		for def in editor_defs:
			var ps: Dictionary = _story.plugin_settings.get(pname, {}) if _story else {}
			var ctrl: Control = def.create_control.call(ps)
			if ctrl != null:
				_plugins_container.add_child(ctrl)
				_plugin_controls[pname] = ctrl
				if _story and ctrl.has_meta("populate_chapters"):
					ctrl.get_meta("populate_chapters").call(_story.chapters)
		_plugins_container.add_child(HSeparator.new())


func _scan_game_plugins() -> Array:
	var plugins: Array = []
	for dir_path in ["res://plugins/", "res://game_plugins/"]:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		dir.list_dir_begin()
		var entry := dir.get_next()
		while entry != "":
			if dir.current_is_dir() and not entry.begins_with("."):
				var path := "%s%s/game_plugin.gd" % [dir_path, entry]
				if FileAccess.file_exists(path):
					var script = load(path)
					if script:
						var instance = script.new()
						if instance.has_method("get_plugin_name") and instance.get_plugin_name() != "":
							plugins.append(instance)
			entry = dir.get_next()
		dir.list_dir_end()
	return plugins


func _collect_plugin_settings() -> Dictionary:
	var result: Dictionary = _story.plugin_settings.duplicate(true) if _story else {}
	for plugin in _game_plugins:
		var pname: String = plugin.get_plugin_name()
		if _plugin_controls.has(pname):
			var ctrl = _plugin_controls[pname]
			if plugin.has_method("read_editor_config"):
				result[pname] = plugin.read_editor_config(ctrl)
	return result


# ── Handlers Thème UI ────────────────────────────────────────────────────────

func _on_ui_theme_mode_toggled(pressed: bool, mode: String) -> void:
	if not pressed:
		return
	_ui_theme_mode = mode
	_ui_theme_default_panel.visible = (mode == "default")
	_ui_theme_custom_panel.visible = (mode == "custom")


func _refresh_ui_theme_assets_list() -> void:
	for child in _ui_theme_assets_list.get_children():
		child.queue_free()
	if _story_base_path == "":
		return
	var ui_dir = _story_base_path + "/assets/ui"
	var count = 0
	for filename in UI_THEME_ASSETS:
		var path = ui_dir + "/" + filename
		if FileAccess.file_exists(path):
			count += 1
			_ui_theme_assets_list.add_child(_make_asset_row(filename, path))
	# Mettre à jour le label de comptage
	var lbl = _ui_theme_custom_panel.get_node_or_null("AssetsCountLabel")
	if lbl:
		lbl.text = tr("Assets personnalisés (%d / %d)") % [count, UI_THEME_ASSETS.size()]


func _make_asset_row(filename: String, abs_path: String) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var preview = TextureRect.new()
	preview.custom_minimum_size = Vector2(48, 48)
	preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var img = Image.new()
	if img.load(abs_path) == OK:
		preview.texture = ImageTexture.create_from_image(img)
	row.add_child(preview)

	var lbl = Label.new()
	lbl.text = filename
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)

	var del_btn = Button.new()
	del_btn.text = "✕"
	del_btn.pressed.connect(_on_delete_ui_asset_pressed.bind(filename))
	row.add_child(del_btn)

	var replace_btn = Button.new()
	replace_btn.text = tr("Remplacer")
	replace_btn.pressed.connect(_on_replace_ui_asset_pressed.bind(filename))
	row.add_child(replace_btn)

	return row


func _on_delete_ui_asset_pressed(filename: String) -> void:
	if _story_base_path == "":
		return
	var path = _story_base_path + "/assets/ui/" + filename
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	_refresh_ui_theme_assets_list()


func _on_replace_ui_asset_pressed(filename: String) -> void:
	var picker = FileDialog.new()
	picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.filters = ["*.png ; Images PNG"]
	picker.file_selected.connect(_on_replace_ui_asset_file_selected.bind(filename))
	add_child(picker)
	picker.popup_centered(Vector2i(800, 600))


func _on_replace_ui_asset_file_selected(path: String, filename: String) -> void:
	_import_ui_asset(path, filename)


func _on_browse_ui_assets_pressed() -> void:
	var picker = FileDialog.new()
	picker.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.filters = ["*.png ; Images PNG"]
	picker.files_selected.connect(_on_browse_ui_assets_files_selected)
	add_child(picker)
	picker.popup_centered(Vector2i(800, 600))


func _on_browse_ui_assets_files_selected(paths: PackedStringArray) -> void:
	var ignored: Array[String] = []
	for path in paths:
		var filename = path.get_file()
		if filename in UI_THEME_ASSETS:
			_import_ui_asset(path, filename)
		else:
			ignored.append(filename)
	if ignored.size() > 0:
		_show_ignored_files_warning(ignored)
	_refresh_ui_theme_assets_list()


func _import_ui_asset(src_path: String, filename: String) -> void:
	if _story_base_path == "":
		return
	var ui_dir = _story_base_path + "/assets/ui"
	if not DirAccess.dir_exists_absolute(ui_dir):
		DirAccess.make_dir_recursive_absolute(ui_dir)
	var dest = ui_dir + "/" + filename
	DirAccess.copy_absolute(src_path, dest)
	_refresh_ui_theme_assets_list()


func _show_ignored_files_warning(ignored: Array[String]) -> void:
	var dialog = AcceptDialog.new()
	dialog.title = tr("Fichiers ignorés")
	dialog.dialog_text = tr("%d fichier(s) ignoré(s) (nom non reconnu) :\n%s") % [
		ignored.size(), "\n".join(ignored)
	]
	add_child(dialog)
	dialog.popup_centered()
