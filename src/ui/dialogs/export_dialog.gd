extends ConfirmationDialog

## Dialogue d'export d'une story en jeu standalone.
## Demande la plateforme cible et le dossier de destination.

signal export_requested(platform: String, output_path: String, quality: String)

const PLATFORMS = ["Web (HTML5)", "macOS", "Linux", "Windows", "Android"]
const PLATFORM_IDS = ["web", "macos", "linux", "windows", "android"]
const QUALITIES = ["HD", "SD", "Ultra SD"]
const QUALITY_IDS = ["hd", "sd", "ultrasd"]

var _quality_dropdown: OptionButton
var _platform_dropdown: OptionButton
var _path_edit: LineEdit
var _browse_button: Button
var _status_label: Label
var _file_dialog: FileDialog


func _init():
	title = tr("Exporter le jeu")
	min_size = Vector2i(450, 0)
	ok_button_text = tr("Exporter")

	var vbox = VBoxContainer.new()
	vbox.name = "ContentVBox"
	vbox.add_theme_constant_override("separation", 8)

	# Qualité
	var quality_label = Label.new()
	quality_label.text = tr("Qualité")
	vbox.add_child(quality_label)

	_quality_dropdown = OptionButton.new()
	_quality_dropdown.name = "QualityDropdown"
	for q in QUALITIES:
		_quality_dropdown.add_item(q)
	vbox.add_child(_quality_dropdown)

	# Plateforme
	var platform_label = Label.new()
	platform_label.text = tr("Plateforme")
	vbox.add_child(platform_label)

	_platform_dropdown = OptionButton.new()
	_platform_dropdown.name = "PlatformDropdown"
	for p in PLATFORMS:
		_platform_dropdown.add_item(p)
	vbox.add_child(_platform_dropdown)

	# Dossier de destination
	var path_label = Label.new()
	path_label.text = tr("Dossier de destination")
	vbox.add_child(path_label)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	vbox.add_child(hbox)

	_path_edit = LineEdit.new()
	_path_edit.name = "PathEdit"
	_path_edit.placeholder_text = tr("Choisir un dossier...")
	_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_path_edit.text_changed.connect(_on_path_changed)
	hbox.add_child(_path_edit)

	_browse_button = Button.new()
	_browse_button.name = "BrowseButton"
	_browse_button.text = tr("Parcourir...")
	_browse_button.pressed.connect(_on_browse_pressed)
	hbox.add_child(_browse_button)

	# Status
	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.text = ""
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_status_label)

	add_child(vbox)

	confirmed.connect(_on_confirmed)


func setup(story) -> void:
	if story == null:
		_path_edit.text = ""
		get_ok_button().disabled = true
		_status_label.text = tr("Aucune histoire chargée")
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
		return

	get_ok_button().disabled = (_path_edit.text == "")
	_status_label.text = ""
	_status_label.remove_theme_color_override("font_color")


func get_selected_quality() -> String:
	var idx = _quality_dropdown.selected
	if idx < 0 or idx >= QUALITY_IDS.size():
		return "hd"
	return QUALITY_IDS[idx]


func get_selected_platform() -> String:
	var idx = _platform_dropdown.selected
	if idx < 0 or idx >= PLATFORM_IDS.size():
		return "web"
	return PLATFORM_IDS[idx]


func get_output_path() -> String:
	return _path_edit.text


func _on_path_changed(_new_text: String) -> void:
	get_ok_button().disabled = (_path_edit.text == "")


func _on_browse_pressed() -> void:
	if _file_dialog != null:
		_file_dialog.queue_free()
	_file_dialog = FileDialog.new()
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.dir_selected.connect(_on_dir_selected)
	add_child(_file_dialog)
	_file_dialog.popup_centered(Vector2i(700, 500))


func _on_dir_selected(dir: String) -> void:
	_path_edit.text = dir
	get_ok_button().disabled = false


func _on_confirmed() -> void:
	export_requested.emit(get_selected_platform(), get_output_path(), get_selected_quality())
