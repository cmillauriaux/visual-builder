extends GutTest

const MenuControllerScript = preload("res://src/controllers/menu_controller.gd")


func test_script_loads():
	assert_not_null(MenuControllerScript)


func test_extends_node():
	var ctrl = Node.new()
	ctrl.set_script(MenuControllerScript)
	assert_is(ctrl, Node)
	ctrl.queue_free()


func test_setup_stores_main_reference():
	var ctrl = Node.new()
	ctrl.set_script(MenuControllerScript)
	var mock_main = Control.new()
	ctrl.setup(mock_main)
	assert_eq(ctrl._main, mock_main)
	ctrl.queue_free()
	mock_main.queue_free()
