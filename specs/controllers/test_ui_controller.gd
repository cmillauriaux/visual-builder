extends GutTest

const UIControllerScript = preload("res://src/controllers/ui_controller.gd")


func test_script_loads():
	assert_not_null(UIControllerScript)


func test_extends_node():
	var ctrl = Node.new()
	ctrl.set_script(UIControllerScript)
	assert_is(ctrl, Node)
	ctrl.queue_free()


func test_previous_fullscreen_layer_initially_null():
	var ctrl = Node.new()
	ctrl.set_script(UIControllerScript)
	assert_null(ctrl._previous_fullscreen_layer)
	ctrl.queue_free()
