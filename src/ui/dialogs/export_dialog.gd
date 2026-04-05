# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends ConfirmationDialog

## Dialogue d'export d'une story en jeu standalone.
## Demande la plateforme cible, la langue, l'export partiel et le dossier de destination.

signal export_requested(platform: String, output_path: String, quality: String, export_options: Dictionary, language: String, partial_export: Dictionary)

const PLATFORMS = ["Web (HTML5)", "macOS", "Linux", "Windows", "Android", "iOS"]
const PLATFORM_IDS = ["web", "macos", "linux", "windows", "android", "ios"]
const QUALITIES = ["HD", "SD", "Ultra SD"]
const QUALITY_IDS = ["hd", "sd", "ultrasd"]

var _quality_dropdown: OptionButton
var _platform_dropdown: OptionButton
var _language_dropdown: OptionButton
var _partial_check: CheckBox
var _partial_container: VBoxContainer
var _start_chapter_dropdown: OptionButton
var _end_chapter_dropdown: OptionButton
var _path_edit: LineEdit
var _browse_button: Button
var _status_label: Label
var _file_dialog: FileDialog
var _webp_check: CheckBox
var _export_options_container: VBoxContainer
var _export_option_checks: Dictionary = {}  # key -> CheckBox

var _chapter_uuids: Array = []  # Array[String] — order matches dropdowns


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

	# Langue
	var language_label = Label.new()
	language_label.text = tr("Langue")
	vbox.add_child(language_label)

	_language_dropdown = OptionButton.new()
	_language_dropdown.name = "LanguageDropdown"
	_language_dropdown.add_item(tr("Tous"))
	vbox.add_child(_language_dropdown)

	# Export partiel
	_partial_check = CheckBox.new()
	_partial_check.name = "PartialCheck"
	_partial_check.text = tr("Exporter partiellement")
	_partial_check.toggled.connect(_on_partial_toggled)
	vbox.add_child(_partial_check)

	_partial_container = VBoxContainer.new()
	_partial_container.name = "PartialContainer"
	_partial_container.add_theme_constant_override("separation", 4)
	_partial_container.visible = false

	var start_label = Label.new()
	start_label.text = tr("Chapitre de départ")
	_partial_container.add_child(start_label)

	_start_chapter_dropdown = OptionButton.new()
	_start_chapter_dropdown.name = "StartChapterDropdown"
	_start_chapter_dropdown.item_selected.connect(_on_start_chapter_selected)
	_partial_container.add_child(_start_chapter_dropdown)

	var end_label = Label.new()
	end_label.text = tr("Chapitre de fin")
	_partial_container.add_child(end_label)

	_end_chapter_dropdown = OptionButton.new()
	_end_chapter_dropdown.name = "EndChapterDropdown"
	_partial_container.add_child(_end_chapter_dropdown)

	vbox.add_child(_partial_container)

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

	# Optimisation WebP
	_webp_check = CheckBox.new()
	_webp_check.name = "WebpCheck"
	_webp_check.text = tr("Convertir les images en WebP (réduction ~80%)")
	_webp_check.button_pressed = true
	vbox.add_child(_webp_check)

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


func setup(story, story_path: String = "") -> void:
	if story == null:
		_path_edit.text = ""
		get_ok_button().disabled = true
		_status_label.text = tr("Aucune histoire chargée")
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
		return

	get_ok_button().disabled = (_path_edit.text == "")
	_status_label.text = ""
	_status_label.remove_theme_color_override("font_color")

	_populate_language_dropdown(story_path)
	_populate_chapter_dropdowns(story)
	_populate_export_options()


func _populate_language_dropdown(story_path: String) -> void:
	_language_dropdown.clear()
	_language_dropdown.add_item(tr("Tous"))
	if story_path == "":
		return
	var StoryI18nService = load("res://src/services/story_i18n_service.gd")
	if StoryI18nService == null:
		return
	var config: Dictionary = StoryI18nService.load_languages_config(story_path)
	var languages = config.get("languages", [])
	for lang in languages:
		_language_dropdown.add_item(str(lang))


func _populate_chapter_dropdowns(story) -> void:
	_chapter_uuids.clear()
	_start_chapter_dropdown.clear()
	_end_chapter_dropdown.clear()
	for i in story.chapters.size():
		var ch = story.chapters[i]
		var label: String = ch.chapter_name if ch.chapter_name != "" else "Chapitre %d" % (i + 1)
		_start_chapter_dropdown.add_item(label)
		_end_chapter_dropdown.add_item(label)
		_chapter_uuids.append(ch.uuid)
	# Default: end = last chapter
	if _end_chapter_dropdown.item_count > 0:
		_end_chapter_dropdown.selected = _end_chapter_dropdown.item_count - 1


func _on_partial_toggled(pressed: bool) -> void:
	_partial_container.visible = pressed


func _on_start_chapter_selected(idx: int) -> void:
	# Ensure end >= start
	if _end_chapter_dropdown.selected < idx:
		_end_chapter_dropdown.selected = idx


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


func get_selected_language() -> String:
	var idx = _language_dropdown.selected
	if idx <= 0:
		return ""
	# idx 0 = "Tous", idx 1+ = actual language codes
	return _language_dropdown.get_item_text(idx)


func get_partial_export() -> Dictionary:
	if not _partial_check.button_pressed:
		return {}
	var start_idx = _start_chapter_dropdown.selected
	var end_idx = _end_chapter_dropdown.selected
	if start_idx < 0 or end_idx < 0:
		return {}
	# Clamp end >= start
	if end_idx < start_idx:
		end_idx = start_idx
	return {"start_idx": start_idx, "end_idx": end_idx}


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
	_file_dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
	_file_dialog.dir_selected.connect(_on_dir_selected)
	add_child(_file_dialog)
	_file_dialog.popup_centered(Vector2i(700, 500))


func _on_dir_selected(dir: String) -> void:
	_path_edit.text = dir
	get_ok_button().disabled = false


func get_export_options() -> Dictionary:
	var result: Dictionary = {}
	result["webp_conversion"] = _webp_check.button_pressed
	for key in _export_option_checks:
		result[key] = _export_option_checks[key].button_pressed
	return result


func _on_confirmed() -> void:
	export_requested.emit(
		get_selected_platform(),
		get_output_path(),
		get_selected_quality(),
		get_export_options(),
		get_selected_language(),
		get_partial_export()
	)


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