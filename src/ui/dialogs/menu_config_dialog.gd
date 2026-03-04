extends ConfirmationDialog

## Dialogue de configuration du menu principal de la story.

signal menu_config_confirmed(menu_title: String, menu_subtitle: String, menu_background: String, playfab_title_id: String, playfab_enabled: bool)

const ImagePickerDialogScript = preload("res://src/ui/dialogs/image_picker_dialog.gd")

var _menu_title_edit: LineEdit
var _menu_subtitle_edit: LineEdit
var _menu_bg_edit: LineEdit
var _browse_button: Button
var _clear_bg_button: Button
var _bg_preview: TextureRect
var _playfab_title_id_edit: LineEdit
var _playfab_enabled_check: CheckButton
var _story_base_path: String = ""

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
	_playfab_title_id_edit.text = story.playfab_title_id
	_playfab_enabled_check.button_pressed = story.playfab_enabled
	_story_base_path = story_base_path
	_update_preview()

func get_menu_title() -> String:
	return _menu_title_edit.text

func get_menu_subtitle() -> String:
	return _menu_subtitle_edit.text

func get_menu_background() -> String:
	return _menu_bg_edit.text

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
	menu_config_confirmed.emit(_menu_title_edit.text, _menu_subtitle_edit.text, _menu_bg_edit.text, _playfab_title_id_edit.text, _playfab_enabled_check.button_pressed)
