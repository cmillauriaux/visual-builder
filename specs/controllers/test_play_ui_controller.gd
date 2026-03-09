extends GutTest

var PlayUIControllerScript

class MockMain extends Control:
	var _play_character_label = Label.new()
	var _play_text_label = Label.new()
	var _choice_overlay = Control.new()
	var _choice_panel = Control.new()
	var _play_ctrl = Node.new()
	
	func _init():
		_choice_overlay.add_child(_choice_panel)
		add_child(_play_character_label)
		add_child(_play_text_label)
		add_child(_choice_overlay)
		add_child(_play_ctrl)

var _ctrl
var _main

func before_each():
	PlayUIControllerScript = load("res://src/controllers/play_ui_controller.gd")
	_main = MockMain.new()
	add_child_autofree(_main)
	_ctrl = Node.new()
	_ctrl.set_script(PlayUIControllerScript)
	add_child_autofree(_ctrl)
	_ctrl.setup(_main)

func test_on_play_dialogue_changed():
	_ctrl._on_play_dialogue_changed("Hero", "Hello world", 0)
	assert_eq(_main._play_character_label.text, "Hero")
	assert_eq(_main._play_text_label.text, "Hello world")
	assert_eq(_main._play_text_label.visible_characters, 0)

func test_on_play_typewriter_tick():
	_ctrl._on_play_typewriter_tick(5)
	assert_eq(_main._play_text_label.visible_characters, 5)

func test_on_play_choice_requested():
	var choices = [{"text": "Choice 1"}, {"text": "Choice 2"}]
	_ctrl._on_play_choice_requested(choices)
	assert_true(_main._choice_overlay.visible)
	# Check if ChoiceVBox was created
	var vbox = _main._choice_panel.get_node("ChoiceVBox")
	assert_not_null(vbox)
	# Title + 2 buttons
	assert_eq(vbox.get_child_count(), 3)

func test_hide_choice_overlay():
	_main._choice_overlay.visible = true
	_ctrl._hide_choice_overlay()
	assert_false(_main._choice_overlay.visible)
	assert_eq(_main._choice_panel.get_child_count(), 0)
