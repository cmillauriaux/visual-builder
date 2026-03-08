extends ConfirmationDialog

## Dialogue de configuration du jeu (menu, analytics, liens, écrans de fin).

signal menu_config_confirmed(menu_title: String, menu_subtitle: String, menu_background: String, menu_music: String, playfab_title_id: String, playfab_enabled: bool, patreon_url: String, itchio_url: String, game_over_title: String, game_over_subtitle: String, game_over_background: String, to_be_continued_title: String, to_be_continued_subtitle: String, to_be_continued_background: String, app_icon: String)

const ImagePickerDialogScript = preload("res://src/ui/dialogs/image_picker_dialog.gd")
const AudioPickerDialogScript = preload("res://src/ui/dialogs/audio_picker_dialog.gd")

var _menu_title_edit: LineEdit
var _menu_subtitle_edit: LineEdit
var _menu_bg_edit: LineEdit
var _browse_button: Button
var _clear_bg_button: Button
var _bg_preview: TextureRect
var _menu_music_label: Label
var _clear_music_button: Button
var _playfab_title_id_edit: LineEdit
var _playfab_enabled_check: CheckButton
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
var _story = null
var _story_base_path: String = ""
var _current_menu_music: String = ""


func _init():
	title = "Configurer le jeu"
	min_size = Vector2i(450, 450)

	var tabs = TabContainer.new()
	tabs.name = "TabContainer"
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# ── Onglet Menu ──────────────────────────────────────────────────────────
	var menu_vbox = VBoxContainer.new()
	menu_vbox.name = "Menu"
	menu_vbox.add_theme_constant_override("separation", 4)

	var title_lbl = Label.new()
	title_lbl.text = "Titre du menu"
	menu_vbox.add_child(title_lbl)

	_menu_title_edit = LineEdit.new()
	_menu_title_edit.name = "MenuTitleEdit"
	_menu_title_edit.placeholder_text = "Laissez vide pour utiliser le titre de l'histoire"
	menu_vbox.add_child(_menu_title_edit)

	var subtitle_lbl = Label.new()
	subtitle_lbl.text = "Sous-titre"
	menu_vbox.add_child(subtitle_lbl)

	_menu_subtitle_edit = LineEdit.new()
	_menu_subtitle_edit.name = "MenuSubtitleEdit"
	menu_vbox.add_child(_menu_subtitle_edit)

	var bg_lbl = Label.new()
	bg_lbl.text = "Image de fond"
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
	_browse_button.text = "Parcourir..."
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
	music_lbl.text = "Musique du menu"
	menu_vbox.add_child(music_lbl)

	var music_hbox = HBoxContainer.new()
	music_hbox.name = "MusicHBox"

	_menu_music_label = Label.new()
	_menu_music_label.name = "MenuMusicLabel"
	_menu_music_label.text = "Aucune musique"
	_menu_music_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu_music_label.clip_text = true
	_menu_music_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	music_hbox.add_child(_menu_music_label)

	var browse_music_btn = Button.new()
	browse_music_btn.name = "BrowseMusicButton"
	browse_music_btn.text = "Choisir..."
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
	icon_lbl.text = "Icône de l'application"
	icon_lbl.add_theme_font_size_override("font_size", 16)
	menu_vbox.add_child(icon_lbl)

	var icon_info_lbl = Label.new()
	icon_info_lbl.text = "Image carrée, recommandé : 1024×1024"
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
	icon_browse_btn.text = "Parcourir..."
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
	_app_icon_warning.text = "L'image n'est pas carrée — elle sera déformée"
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

	# ── Onglet Analytics ─────────────────────────────────────────────────────
	var analytics_vbox = VBoxContainer.new()
	analytics_vbox.name = "Analytics"
	analytics_vbox.add_theme_constant_override("separation", 4)

	var pf_section_lbl = Label.new()
	pf_section_lbl.text = "PlayFab Analytics"
	pf_section_lbl.add_theme_font_size_override("font_size", 16)
	analytics_vbox.add_child(pf_section_lbl)

	var pf_title_lbl = Label.new()
	pf_title_lbl.text = "Title ID"
	analytics_vbox.add_child(pf_title_lbl)

	_playfab_title_id_edit = LineEdit.new()
	_playfab_title_id_edit.name = "PlayFabTitleIdEdit"
	_playfab_title_id_edit.placeholder_text = "Laisser vide pour désactiver"
	analytics_vbox.add_child(_playfab_title_id_edit)

	_playfab_enabled_check = CheckButton.new()
	_playfab_enabled_check.name = "PlayFabEnabledCheck"
	_playfab_enabled_check.text = "Activer le tracking PlayFab"
	analytics_vbox.add_child(_playfab_enabled_check)

	tabs.add_child(analytics_vbox)

	# ── Onglet Liens ─────────────────────────────────────────────────────────
	var liens_vbox = VBoxContainer.new()
	liens_vbox.name = "Liens"
	liens_vbox.add_theme_constant_override("separation", 4)

	var patreon_lbl = Label.new()
	patreon_lbl.text = "URL Patreon"
	liens_vbox.add_child(patreon_lbl)

	_patreon_url_edit = LineEdit.new()
	_patreon_url_edit.name = "PatreonUrlEdit"
	_patreon_url_edit.placeholder_text = "https://www.patreon.com/..."
	liens_vbox.add_child(_patreon_url_edit)

	var itchio_lbl = Label.new()
	itchio_lbl.text = "URL itch.io"
	liens_vbox.add_child(itchio_lbl)

	_itchio_url_edit = LineEdit.new()
	_itchio_url_edit.name = "ItchioUrlEdit"
	_itchio_url_edit.placeholder_text = "https://votrejeu.itch.io/..."
	liens_vbox.add_child(_itchio_url_edit)

	tabs.add_child(liens_vbox)

	# ── Onglet Game Over ─────────────────────────────────────────────────────
	var go_vbox = VBoxContainer.new()
	go_vbox.name = "GameOver"
	go_vbox.add_theme_constant_override("separation", 4)

	var go_bg_lbl = Label.new()
	go_bg_lbl.text = "Image de fond"
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
	go_browse_btn.text = "Parcourir..."
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
	go_title_lbl.text = "Titre"
	go_vbox.add_child(go_title_lbl)

	_game_over_title_edit = LineEdit.new()
	_game_over_title_edit.name = "GameOverTitleEdit"
	_game_over_title_edit.placeholder_text = "Game Over"
	go_vbox.add_child(_game_over_title_edit)

	var go_subtitle_lbl = Label.new()
	go_subtitle_lbl.text = "Sous-titre"
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
	tbc_bg_lbl.text = "Image de fond"
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
	tbc_browse_btn.text = "Parcourir..."
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
	tbc_title_lbl.text = "Titre"
	tbc_vbox.add_child(tbc_title_lbl)

	_to_be_continued_title_edit = LineEdit.new()
	_to_be_continued_title_edit.name = "ToBeContinuedTitleEdit"
	_to_be_continued_title_edit.placeholder_text = "À suivre..."
	tbc_vbox.add_child(_to_be_continued_title_edit)

	var tbc_subtitle_lbl = Label.new()
	tbc_subtitle_lbl.text = "Sous-titre"
	tbc_vbox.add_child(tbc_subtitle_lbl)

	_to_be_continued_subtitle_edit = LineEdit.new()
	_to_be_continued_subtitle_edit.name = "ToBeContinuedSubtitleEdit"
	tbc_vbox.add_child(_to_be_continued_subtitle_edit)

	tabs.add_child(tbc_vbox)

	# Titres des onglets (après ajout des enfants)
	tabs.set_tab_title(0, "Menu")
	tabs.set_tab_title(1, "Analytics")
	tabs.set_tab_title(2, "Liens")
	tabs.set_tab_title(3, "Game Over")
	tabs.set_tab_title(4, "À suivre")

	add_child(tabs)
	confirmed.connect(_on_confirmed)


func setup(story, story_base_path: String = "") -> void:
	_menu_title_edit.text = story.menu_title
	_menu_subtitle_edit.text = story.menu_subtitle
	_menu_bg_edit.text = story.menu_background
	_playfab_title_id_edit.text = story.playfab_title_id
	_playfab_enabled_check.button_pressed = story.playfab_enabled
	_patreon_url_edit.text = story.patreon_url if story.get("patreon_url") != null else ""
	_itchio_url_edit.text = story.itchio_url if story.get("itchio_url") != null else ""
	_game_over_bg_edit.text = story.game_over_background if story.get("game_over_background") != null else ""
	_game_over_title_edit.text = story.game_over_title if story.get("game_over_title") != null else ""
	_game_over_subtitle_edit.text = story.game_over_subtitle if story.get("game_over_subtitle") != null else ""
	_to_be_continued_bg_edit.text = story.to_be_continued_background if story.get("to_be_continued_background") != null else ""
	_to_be_continued_title_edit.text = story.to_be_continued_title if story.get("to_be_continued_title") != null else ""
	_to_be_continued_subtitle_edit.text = story.to_be_continued_subtitle if story.get("to_be_continued_subtitle") != null else ""
	_app_icon_edit.text = story.app_icon if story.get("app_icon") != null else ""
	_story = story
	_story_base_path = story_base_path
	_current_menu_music = story.menu_music if story.get("menu_music") != null else ""
	_update_menu_music_label()
	_update_preview()
	_update_game_over_preview()
	_update_tbc_preview()
	_update_icon_preview()


func get_menu_title() -> String:
	return _menu_title_edit.text

func get_menu_subtitle() -> String:
	return _menu_subtitle_edit.text

func get_menu_background() -> String:
	return _menu_bg_edit.text

func get_menu_music() -> String:
	return _current_menu_music

func get_playfab_title_id() -> String:
	return _playfab_title_id_edit.text

func get_playfab_enabled() -> bool:
	return _playfab_enabled_check.button_pressed

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


# ── Handlers Menu ────────────────────────────────────────────────────────────

func _on_browse_pressed() -> void:
	var picker = Window.new()
	picker.set_script(ImagePickerDialogScript)
	add_child(picker)
	picker.setup(ImagePickerDialogScript.Mode.BACKGROUND, _story_base_path, _story)
	picker.image_selected.connect(_on_bg_image_selected)
	picker.popup_centered()

func _on_bg_image_selected(path: String) -> void:
	_menu_bg_edit.text = path
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
		_menu_music_label.text = "Aucune musique"
		_menu_music_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))

func _update_preview() -> void:
	if _menu_bg_edit.text == "":
		_bg_preview.texture = null
		return
	var img = Image.new()
	if img.load(_menu_bg_edit.text) == OK:
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
	_game_over_bg_edit.text = path
	_update_game_over_preview()

func _on_game_over_clear_bg_pressed() -> void:
	_game_over_bg_edit.text = ""
	_game_over_bg_preview.texture = null

func _update_game_over_preview() -> void:
	if _game_over_bg_edit.text == "":
		_game_over_bg_preview.texture = null
		return
	var img = Image.new()
	if img.load(_game_over_bg_edit.text) == OK:
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
	_to_be_continued_bg_edit.text = path
	_update_tbc_preview()

func _on_tbc_clear_bg_pressed() -> void:
	_to_be_continued_bg_edit.text = ""
	_to_be_continued_bg_preview.texture = null

func _update_tbc_preview() -> void:
	if _to_be_continued_bg_edit.text == "":
		_to_be_continued_bg_preview.texture = null
		return
	var img = Image.new()
	if img.load(_to_be_continued_bg_edit.text) == OK:
		_to_be_continued_bg_preview.texture = ImageTexture.create_from_image(img)
	else:
		_to_be_continued_bg_preview.texture = null


# ── Handlers Icône ───────────────────────────────────────────────────────────

func _on_icon_browse_pressed() -> void:
	var picker = Window.new()
	picker.set_script(ImagePickerDialogScript)
	add_child(picker)
	picker.setup(ImagePickerDialogScript.Mode.BACKGROUND, _story_base_path, _story)
	picker.image_selected.connect(_on_icon_selected)
	picker.popup_centered()

func _on_icon_selected(path: String) -> void:
	_app_icon_edit.text = path
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
	var img = Image.new()
	if img.load(_app_icon_edit.text) == OK:
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
		_current_menu_music, _playfab_title_id_edit.text, _playfab_enabled_check.button_pressed,
		_validate_url(_patreon_url_edit.text), _validate_url(_itchio_url_edit.text),
		_game_over_title_edit.text, _game_over_subtitle_edit.text, _game_over_bg_edit.text,
		_to_be_continued_title_edit.text, _to_be_continued_subtitle_edit.text, _to_be_continued_bg_edit.text,
		_app_icon_edit.text
	)
