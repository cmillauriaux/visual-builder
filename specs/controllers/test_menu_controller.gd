extends GutTest

var MenuControllerScript
var NavigationControllerScript
var EditorMainScript
var StoryScript
var ExportServiceScript

# Mock class for Main
class MockMain extends Control:
	var _nav_ctrl
	var _editor_main
	var _export_service
	
	func _get_story_base_path() -> String:
		return "res://stories/test/"

var _ctrl
var _main
var _nav_ctrl
var _editor_main
var _story
var _export_service

func before_each() -> void:
	MenuControllerScript = load("res://src/controllers/menu_controller.gd")
	NavigationControllerScript = load("res://src/controllers/navigation_controller.gd")
	EditorMainScript = load("res://src/ui/editors/editor_main.gd")
	StoryScript = load("res://src/models/story.gd")
	ExportServiceScript = load("res://src/services/export_service.gd")

	_main = MockMain.new()
	add_child_autofree(_main)
	
	_nav_ctrl = Node.new()
	_nav_ctrl.set_script(NavigationControllerScript)
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

func test_on_histoire_menu_export() -> void:
	_ctrl.on_histoire_menu_pressed(4)
	var dialog = _main.get_child(_main.get_child_count() - 1)
	assert_true(dialog is ConfirmationDialog)

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
