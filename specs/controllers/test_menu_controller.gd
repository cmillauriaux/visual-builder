extends GutTest

var MenuControllerScript
var EditorMainScript
var StoryScript
var ExportServiceScript


# Mock nav_ctrl : stub de toutes les méthodes appelées par menu_controller
class MockNavCtrl extends Node:
	var new_story_called := false
	var load_called := false
	var save_called := false
	var save_as_called := false
	var verify_called := false
	var variables_called := false
	var menu_config_called := false

	func on_new_story_pressed() -> void: new_story_called = true
	func on_load_pressed() -> void: load_called = true
	func on_save_pressed() -> void: save_called = true
	func on_save_as_pressed() -> void: save_as_called = true
	func on_verify_pressed() -> void: verify_called = true
	func on_variables_pressed() -> void: variables_called = true
	func on_menu_config_requested() -> void: menu_config_called = true


# Mock main
class MockMain extends Control:
	var _nav_ctrl
	var _editor_main
	var _export_service

	func _get_story_base_path() -> String:
		return "res://stories/test/"


var _ctrl
var _main
var _nav_ctrl: MockNavCtrl
var _editor_main
var _story
var _export_service


func before_each() -> void:
	MenuControllerScript = load("res://src/controllers/menu_controller.gd")
	EditorMainScript = load("res://src/ui/editors/editor_main.gd")
	StoryScript = load("res://src/models/story.gd")
	ExportServiceScript = load("res://src/services/export_service.gd")

	_main = MockMain.new()
	add_child_autofree(_main)

	_nav_ctrl = MockNavCtrl.new()
	_main.add_child(_nav_ctrl)
	_main._nav_ctrl = _nav_ctrl

	_editor_main = Control.new()
	_editor_main.set_script(EditorMainScript)
	_main.add_child(_editor_main)
	_main._editor_main = _editor_main

	_story = StoryScript.new()
	_editor_main._story = _story

	_export_service = Node.new()
	_export_service.set_script(ExportServiceScript)
	_main.add_child(_export_service)
	_main._export_service = _export_service

	_ctrl = Node.new()
	_ctrl.set_script(MenuControllerScript)
	_main.add_child(_ctrl)
	_ctrl.setup(_main)


# --- on_histoire_menu_pressed ---

func test_on_histoire_menu_new_story() -> void:
	_ctrl.on_histoire_menu_pressed(0)
	assert_true(_nav_ctrl.new_story_called)

func test_on_histoire_menu_load() -> void:
	_ctrl.on_histoire_menu_pressed(1)
	assert_true(_nav_ctrl.load_called)

func test_on_histoire_menu_save() -> void:
	_ctrl.on_histoire_menu_pressed(2)
	assert_true(_nav_ctrl.save_called)

func test_on_histoire_menu_save_as() -> void:
	_ctrl.on_histoire_menu_pressed(3)
	assert_true(_nav_ctrl.save_as_called)

func test_on_histoire_menu_export() -> void:
	_ctrl.on_histoire_menu_pressed(4)
	var dialog = _main.get_child(_main.get_child_count() - 1)
	assert_true(dialog is ConfirmationDialog)

func test_on_histoire_menu_verify() -> void:
	_ctrl.on_histoire_menu_pressed(5)
	assert_true(_nav_ctrl.verify_called)

func test_on_histoire_menu_i18n_regenerate_creates_dialog() -> void:
	_ctrl.on_histoire_menu_pressed(6)
	var dialog = _main.get_child(_main.get_child_count() - 1)
	assert_true(dialog is AcceptDialog)

func test_on_histoire_menu_i18n_check_creates_dialog() -> void:
	_ctrl.on_histoire_menu_pressed(7)
	var dialog = _main.get_child(_main.get_child_count() - 1)
	assert_true(dialog is AcceptDialog)


# --- on_parametres_menu_pressed ---

func test_on_parametres_menu_variables() -> void:
	_ctrl.on_parametres_menu_pressed(0)
	assert_true(_nav_ctrl.variables_called)

func test_on_parametres_menu_menu_config() -> void:
	_ctrl.on_parametres_menu_pressed(1)
	assert_true(_nav_ctrl.menu_config_called)

func test_on_parametres_menu_gallery() -> void:
	_ctrl.on_parametres_menu_pressed(2)
	var dialog = _main.get_child(_main.get_child_count() - 1)
	assert_true(dialog is Window)

func test_on_parametres_menu_notifications() -> void:
	_ctrl.on_parametres_menu_pressed(3)
	var dialog = _main.get_child(_main.get_child_count() - 1)
	assert_true(dialog is AcceptDialog)

func test_on_parametres_menu_languages() -> void:
	_ctrl.on_parametres_menu_pressed(4)
	var dialog = _main.get_child(_main.get_child_count() - 1)
	assert_true(dialog is AcceptDialog)


# --- _show_export_result / _show_export_error ---

func test_show_export_result_creates_accept_dialog() -> void:
	_ctrl._show_export_result("/output/game.pck", "/log/export.log")
	var dialog = _main.get_child(_main.get_child_count() - 1)
	assert_true(dialog is AcceptDialog)
	assert_eq(dialog.title, "Export terminé")

func test_show_export_error_creates_accept_dialog() -> void:
	_ctrl._show_export_error("/log/export.log", "Erreur de compilation")
	var dialog = _main.get_child(_main.get_child_count() - 1)
	assert_true(dialog is AcceptDialog)
	assert_eq(dialog.title, "Erreur d'export")


# --- Null story guards (early return) ---

func test_on_export_pressed_null_story_no_crash() -> void:
	_editor_main._story = null
	_ctrl.on_export_pressed()
	pass_test("on_export_pressed with null story should not crash")

func test_on_gallery_pressed_null_story_no_crash() -> void:
	_editor_main._story = null
	_ctrl.on_gallery_pressed()
	pass_test("on_gallery_pressed with null story should not crash")

func test_on_notifications_pressed_null_story_no_crash() -> void:
	_editor_main._story = null
	_ctrl.on_notifications_pressed()
	pass_test("on_notifications_pressed with null story should not crash")

func test_on_languages_pressed_null_story_no_crash() -> void:
	_editor_main._story = null
	_ctrl.on_languages_pressed()
	pass_test("on_languages_pressed with null story should not crash")

func test_on_i18n_regenerate_pressed_null_story_no_crash() -> void:
	_editor_main._story = null
	_ctrl.on_i18n_regenerate_pressed()
	pass_test("on_i18n_regenerate_pressed with null story should not crash")

func test_on_i18n_check_pressed_null_story_no_crash() -> void:
	_editor_main._story = null
	_ctrl.on_i18n_check_pressed()
	pass_test("on_i18n_check_pressed with null story should not crash")
