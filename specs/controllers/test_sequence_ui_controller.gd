extends GutTest

const SequenceUIControllerScript = preload("res://src/controllers/sequence_ui_controller.gd")


func test_script_loads():
	assert_not_null(SequenceUIControllerScript)


func test_extends_node():
	var ctrl = Node.new()
	ctrl.set_script(SequenceUIControllerScript)
	assert_is(ctrl, Node)
	ctrl.queue_free()


func test_setup_stores_main_reference():
	var ctrl = Node.new()
	ctrl.set_script(SequenceUIControllerScript)
	var mock_main = Control.new()
	ctrl.setup(mock_main)
	assert_eq(ctrl._main, mock_main)
	ctrl.queue_free()
	mock_main.queue_free()
