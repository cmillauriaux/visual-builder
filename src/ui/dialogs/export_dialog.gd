extends ConfirmationDialog

## Dialogue d'export d'une story en jeu standalone.
## Demande la plateforme cible et le dossier de destination.

signal export_requested(platform: String, output_path: String, quality: String, export_options: Dictionary)

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
var _export_options_container: VBoxContainer
var _export_option_checks: Dictionary = {}  # key -> CheckBox


func _init():
	title = "Exporter le jeu"
	min_size = Vector2i(450, 0)
	ok_button_text = "Exporter"

	var vbox = VBoxContainer.new()
	vbox.name = "ContentVBox"
	vbox.add_theme_constant_override("separation", 8)

	# Qualité
	var quality_label = Label.new()
	quality_label.text = "Qualité"
	vbox.add_child(quality_label)

	_quality_dropdown = OptionButton.new()
	_quality_dropdown.name = "QualityDropdown"
	for q in QUALITIES:
		_quality_dropdown.add_item(q)
	vbox.add_child(_quality_dropdown)

	# Plateforme
	var platform_label = Label.new()
	platform_label.text = "Plateforme"
	vbox.add_child(platform_label)

	_platform_dropdown = OptionButton.new()
	_platform_dropdown.name = "PlatformDropdown"
	for p in PLATFORMS:
		_platform_dropdown.add_item(p)
	vbox.add_child(_platform_dropdown)

	# Dossier de destination
	var path_label = Label.new()
	path_label.text = "Dossier de destination"
	vbox.add_child(path_label)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	vbox.add_child(hbox)

	_path_edit = LineEdit.new()
	_path_edit.name = "PathEdit"
	_path_edit.placeholder_text = "Choisir un dossier..."
	_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_path_edit.text_changed.connect(_on_path_changed)
	hbox.add_child(_path_edit)

	_browse_button = Button.new()
	_browse_button.name = "BrowseButton"
	_browse_button.text = "Parcourir..."
	_browse_button.pressed.connect(_on_browse_pressed)
	hbox.add_child(_browse_button)

	# Options d'export des plugins
	_export_options_container = VBoxContainer.new()
	_export_options_container.name = "ExportOptionsContainer"
	_export_options_container.add_theme_constant_override("separation", 4)
	_export_options_container.visible = false
	vbox.add_child(_export_options_container)

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
		_status_label.text = "Aucune histoire chargée"
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
		return

	get_ok_button().disabled = (_path_edit.text == "")
	_status_label.text = ""
	_status_label.remove_theme_color_override("font_color")
	_populate_export_options()


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


func get_export_options() -> Dictionary:
	var result: Dictionary = {}
	for key in _export_option_checks:
		result[key] = _export_option_checks[key].button_pressed
	return result


func _on_confirmed() -> void:
	export_requested.emit(get_selected_platform(), get_output_path(), get_selected_quality(), get_export_options())


func _populate_export_options() -> void:
	for child in _export_options_container.get_children():
		child.queue_free()
	_export_option_checks.clear()

	var plugins := _scan_game_plugins()
	var has_options := false
	for plugin in plugins:
		if not plugin.has_method("get_export_options"):
			continue
		for opt in plugin.get_export_options():
			if not has_options:
				var sep := HSeparator.new()
				_export_options_container.add_child(sep)
				var title_lbl := Label.new()
				title_lbl.text = "Options"
				_export_options_container.add_child(title_lbl)
				has_options = true
			var check := CheckBox.new()
			check.text = opt.label
			check.button_pressed = opt.default_value
			_export_options_container.add_child(check)
			_export_option_checks[opt.key] = check

	_export_options_container.visible = has_options


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
