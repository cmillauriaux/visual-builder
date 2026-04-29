# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends Node

## Gère les actions des menus "Histoire" et "Paramètres" de la barre supérieure.

const ImagePickerDialogScript = preload("res://src/ui/dialogs/image_picker_dialog.gd")
const ExportDialogScript = preload("res://src/ui/dialogs/export_dialog.gd")
const GalleryDialogScript = preload("res://src/ui/dialogs/gallery_dialog.gd")
const I18nDialogScript = preload("res://src/ui/dialogs/i18n_dialog.gd")
const NotificationDialogScript = preload("res://src/ui/dialogs/notification_dialog.gd")
const LanguageManagerDialogScript = preload("res://src/ui/dialogs/language_manager_dialog.gd")
const StoryI18nService = preload("res://src/services/story_i18n_service.gd")

var _main: Control


func setup(main: Control) -> void:
	_main = main


func on_histoire_menu_pressed(id: int) -> void:
	match id:
		0: _main._nav_ctrl.on_new_story_pressed()
		1: _main._nav_ctrl.on_load_pressed()
		2: _main._nav_ctrl.on_save_pressed()
		3: _main._nav_ctrl.on_save_as_pressed()
		4: on_export_pressed()
		5: _main._nav_ctrl.on_verify_pressed()
		6: on_i18n_regenerate_pressed()
		7: on_i18n_check_pressed()
		8: _main._nav_ctrl.on_reload_pressed()
		9: _main._nav_ctrl.on_menu_config_requested()
		10: on_gallery_pressed()


func on_parametres_menu_pressed(id: int) -> void:
	match id:
		0: on_notifications_pressed()
		1: on_languages_pressed()


func on_export_pressed() -> void:
	if _main._editor_main._story == null:
		return
	var dialog = ConfirmationDialog.new()
	dialog.set_script(ExportDialogScript)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	_main.add_child(dialog)
	dialog.setup(_main._editor_main._story, _main._get_story_base_path())
	dialog.export_requested.connect(_on_export_requested)
	dialog.popup_centered()


func _on_export_requested(platform: String, output_path: String, quality: String, export_options: Dictionary = {}, language: String = "", partial_export: Dictionary = {}) -> void:
	if _main._editor_main._story == null:
		return

	var story_path = _main._get_story_base_path()
	var result = _main._export_service.export_story(_main._editor_main._story, platform, output_path, story_path, quality, export_options, language, partial_export)
	
	if result.success:
		_show_export_result(result.output_path, result.log_path)
	else:
		_show_export_error(result.log_path, result.error_message)


func _show_export_result(output_path: String, log_path: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.title = tr("Export terminé")
	dialog.dialog_text = tr("Le jeu a été exporté dans :\n%s\n\nLog : %s") % [output_path, log_path]
	dialog.confirmed.connect(dialog.queue_free)
	_main.add_child(dialog)
	dialog.popup_centered()


func _show_export_error(log_path: String, reason: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.title = tr("Erreur d'export")
	dialog.dialog_text = reason + "\n\n" + tr("Log : %s") % log_path
	dialog.confirmed.connect(dialog.queue_free)
	_main.add_child(dialog)
	dialog.popup_centered()


func on_gallery_pressed() -> void:
	if _main._editor_main._story == null:
		return
	var dialog = Window.new()
	dialog.set_script(GalleryDialogScript)
	dialog.close_requested.connect(dialog.queue_free)
	_main.add_child(dialog)
	dialog.setup(_main._editor_main._story, _main._get_story_base_path())
	dialog.popup_centered()


func on_notifications_pressed() -> void:
	if _main._editor_main._story == null:
		return
	var dialog = AcceptDialog.new()
	dialog.set_script(NotificationDialogScript)
	dialog.confirmed.connect(dialog.queue_free)
	_main.add_child(dialog)
	dialog.setup(_main._editor_main._story)
	dialog.popup_centered()


func on_languages_pressed() -> void:
	var base_path = _main._get_story_base_path()
	if base_path == "":
		return
	var dialog = AcceptDialog.new()
	dialog.set_script(LanguageManagerDialogScript)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.languages_changed.connect(func(): _main._nav_ctrl.on_variables_changed())
	_main.add_child(dialog)
	dialog.setup(base_path)
	dialog.popup_centered()


func on_i18n_regenerate_pressed() -> void:
	if _main._editor_main._story == null:
		return
	var base_path = _main._get_story_base_path()
	if base_path == "":
		return
	var added = StoryI18nService.regenerate_missing_keys(_main._editor_main._story, base_path)
	var dialog = AcceptDialog.new()
	dialog.set_script(I18nDialogScript)
	dialog.confirmed.connect(dialog.queue_free)
	_main.add_child(dialog)
	dialog.show_regenerate_result(added)
	dialog.popup_centered()


func on_i18n_check_pressed() -> void:
	if _main._editor_main._story == null:
		return
	var base_path = _main._get_story_base_path()
	if base_path == "":
		return
	var check = StoryI18nService.check_translations(_main._editor_main._story, base_path)
	var dialog = AcceptDialog.new()
	dialog.set_script(I18nDialogScript)
	dialog.confirmed.connect(dialog.queue_free)
	_main.add_child(dialog)
	dialog.show_check_result(check)
	dialog.popup_centered()
