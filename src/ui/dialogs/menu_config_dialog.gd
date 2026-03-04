extends ConfirmationDialog

## Dialogue de configuration du menu principal de la story.

signal menu_config_confirmed(menu_title: String, menu_subtitle: String, menu_background: String, menu_music: String, playfab_title_id: String, playfab_enabled: bool)

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
var _story_base_path: String = ""
var _current_menu_music: String = ""

func _init():
	title = "Configurer le menu"
	min_size = Vector2i(400, 0)

	var vbox = VBoxContainer.new()
	vbox.name = "ContentVBox"

	var title_label = Label.new()
	title_label.text = "Titre du menu"
	vbox.add_child(title_label)

	_menu_title_edit = LineEdit.new()
	_menu_title_edit.name = "MenuTitleEdit"
	_menu_title_edit.placeholder_text = "Laissez vide pour utiliser le titre de l'histoire"
	vbox.add_child(_menu_title_edit)

	var subtitle_label = Label.new()
	subtitle_label.text = "Sous-titre"
	vbox.add_child(subtitle_label)

	_menu_subtitle_edit = LineEdit.new()
	_menu_subtitle_edit.name = "MenuSubtitleEdit"
	vbox.add_child(_menu_subtitle_edit)

	var bg_label = Label.new()
	bg_label.text = "Image de fond"
	vbox.add_child(bg_label)

	var hbox = HBoxContainer.new()
	hbox.name = "BgHBox"

	_menu_bg_edit = LineEdit.new()
	_menu_bg_edit.name = "MenuBgEdit"
	_menu_bg_edit.editable = false
	_menu_bg_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(_menu_bg_edit)

	_browse_button = Button.new()
	_browse_button.name = "BrowseButton"
	_browse_button.text = "Parcourir..."
	_browse_button.pressed.connect(_on_browse_pressed)
	hbox.add_child(_browse_button)

	_clear_bg_button = Button.new()
	_clear_bg_button.name = "ClearBgButton"
	_clear_bg_button.text = "✕"
	_clear_bg_button.pressed.connect(_on_clear_bg_pressed)
	hbox.add_child(_clear_bg_button)

	vbox.add_child(hbox)

	_bg_preview = TextureRect.new()
	_bg_preview.name = "BgPreview"
	_bg_preview.custom_minimum_size = Vector2(200, 112)
	_bg_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vbox.add_child(_bg_preview)

	var music_label = Label.new()
	music_label.text = "Musique du menu"
	vbox.add_child(music_label)

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

	vbox.add_child(music_hbox)

	var separator = HSeparator.new()
	separator.name = "PlayFabSeparator"
	vbox.add_child(separator)

	var playfab_label = Label.new()
	playfab_label.text = "PlayFab Analytics"
	playfab_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(playfab_label)

	var pf_title_label = Label.new()
	pf_title_label.text = "Title ID"
	vbox.add_child(pf_title_label)

	_playfab_title_id_edit = LineEdit.new()
	_playfab_title_id_edit.name = "PlayFabTitleIdEdit"
	_playfab_title_id_edit.placeholder_text = "Laisser vide pour désactiver"
	vbox.add_child(_playfab_title_id_edit)

	_playfab_enabled_check = CheckButton.new()
	_playfab_enabled_check.name = "PlayFabEnabledCheck"
	_playfab_enabled_check.text = "Activer le tracking PlayFab"
	vbox.add_child(_playfab_enabled_check)

	add_child(vbox)

	confirmed.connect(_on_confirmed)

func setup(story, story_base_path: String = "") -> void:
	_menu_title_edit.text = story.menu_title
	_menu_subtitle_edit.text = story.menu_subtitle
	_menu_bg_edit.text = story.menu_background
	_playfab_title_id_edit.text = story.playfab_title_id if story.get("playfab_title_id") != null else ""
	_playfab_enabled_check.button_pressed = story.playfab_enabled if story.get("playfab_enabled") != null else false
	_story_base_path = story_base_path
	_current_menu_music = story.menu_music if story.get("menu_music") != null else ""
	_update_menu_music_label()
	_update_preview()

func get_menu_title() -> String:
	return _menu_title_edit.text

func get_menu_subtitle() -> String:
	return _menu_subtitle_edit.text

func get_menu_background() -> String:
	return _menu_bg_edit.text

func get_menu_music() -> String:
	return _current_menu_music

func _on_browse_pressed() -> void:
	var picker = Window.new()
	picker.set_script(ImagePickerDialogScript)
	add_child(picker)
	picker.setup(ImagePickerDialogScript.Mode.BACKGROUND, _story_base_path)
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

func get_playfab_title_id() -> String:
	return _playfab_title_id_edit.text

func get_playfab_enabled() -> bool:
	return _playfab_enabled_check.button_pressed

func _on_confirmed() -> void:
	menu_config_confirmed.emit(_menu_title_edit.text, _menu_subtitle_edit.text, _menu_bg_edit.text, _current_menu_music, _playfab_title_id_edit.text, _playfab_enabled_check.button_pressed)
