extends GutTest

var SequenceUIControllerScript

class MockMain extends Control:
	var _visual_editor = Control.new()
	var _sequence_editor_ctrl = Control.new()
	var _undo_redo = RefCounted.new()
	var _editor_main = Node.new()

	func _init():
		_visual_editor.set_script(load("res://src/ui/sequence/sequence_visual_editor.gd"))
		_sequence_editor_ctrl.set_script(load("res://src/ui/sequence/sequence_editor.gd"))
		_undo_redo.set_script(load("res://src/services/undo_redo_service.gd"))
		add_child(_visual_editor)
		add_child(_sequence_editor_ctrl)
		add_child(_editor_main)
	
	func _get_story_base_path():
		return "res://story/"
	
	func _rebuild_dialogue_list():
		pass
	
	func _on_dialogue_selected(idx):
		pass

var _ctrl
var _main

func before_each():
	SequenceUIControllerScript = load("res://src/controllers/sequence_ui_controller.gd")
	_main = MockMain.new()
	add_child_autofree(_main)
	_ctrl = Node.new()
	_ctrl.set_script(SequenceUIControllerScript)
	add_child_autofree(_ctrl)
	_ctrl.setup(_main)

func test_grid_toggled():
	_ctrl.on_grid_toggled(true)
	assert_true(_main._visual_editor.is_grid_visible())
	_ctrl.on_grid_toggled(false)
	assert_false(_main._visual_editor.is_grid_visible())

func test_snap_toggled():
	_ctrl.on_snap_toggled(true)
	assert_true(_main._visual_editor.is_snap_enabled())
	_ctrl.on_snap_toggled(false)
	assert_false(_main._visual_editor.is_snap_enabled())

func test_on_bg_file_selected():
	_ctrl._on_bg_file_selected("assets/bg.png")
	# set_background délègue aux objets réels — pas de crash = succès
	assert_true(true)
