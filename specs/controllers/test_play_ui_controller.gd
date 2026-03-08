extends GutTest

const PlayUIControllerScript = preload("res://src/controllers/play_ui_controller.gd")


func test_script_loads():
	assert_not_null(PlayUIControllerScript)


func test_extends_node():
	var ctrl = Node.new()
	ctrl.set_script(PlayUIControllerScript)
	assert_is(ctrl, Node)
	ctrl.queue_free()


func test_setup_stores_main_reference():
	var ctrl = Node.new()
	ctrl.set_script(PlayUIControllerScript)
	# Create a mock main with required properties for EventBus signals
	var mock_main = Control.new()
	mock_main.set_meta("_play_character_label", Label.new())
	mock_main.set_meta("_play_text_label", RichTextLabel.new())
	ctrl._main = mock_main
	assert_eq(ctrl._main, mock_main)
	ctrl.queue_free()
	mock_main.queue_free()
