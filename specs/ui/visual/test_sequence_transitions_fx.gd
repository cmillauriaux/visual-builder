extends "res://addons/gut/test.gd"

var SequenceFxPlayerScript = load("res://src/ui/visual/sequence_fx_player.gd")

var _player: Node
var _target: Control

func before_each():
	_player = Node.new()
	_player.set_script(SequenceFxPlayerScript)
	add_child(_player)
	_target = Control.new()
	_target.size = Vector2(800, 600)
	add_child(_target)

func after_each():
	_player.free()
	_target.free()

func test_play_transition_fade_in():
	watch_signals(_player)
	_player.play_transition("fade", 0.2, true, _target)
	
	assert_true(_player.is_playing())
	var overlay = _target.get_node_or_null("TransFadeInOverlay")
	assert_not_null(overlay)
	assert_eq(overlay.color.a, 1.0) # Initial state
	
	await wait_seconds(0.4)
	
	assert_false(_player.is_playing())
	assert_null(_target.get_node_or_null("TransFadeInOverlay"))
	assert_signal_emitted(_player, "fx_finished")

func test_play_transition_fade_out():
	watch_signals(_player)
	_player.play_transition("fade", 0.2, false, _target)
	
	assert_true(_player.is_playing())
	var overlay = _target.get_node_or_null("TransFadeOutOverlay")
	assert_not_null(overlay)
	assert_eq(overlay.color.a, 0.0) # Initial state
	
	await wait_seconds(0.4)
	
	assert_false(_player.is_playing())
	# Overlay should remain
	var overlay_after = _target.get_node_or_null("TransFadeOutOverlay")
	assert_not_null(overlay_after)
	assert_eq(overlay_after.color.a, 1.0)
	assert_signal_emitted(_player, "fx_finished")

func test_stop_fx_cleans_up_transitions():
	_player.play_transition("fade", 0.5, true, _target)
	assert_not_null(_target.get_node_or_null("TransFadeInOverlay"))
	
	_player.stop_fx()
	await wait_frames(1)
	assert_false(_player.is_playing())
	assert_null(_target.get_node_or_null("TransFadeInOverlay"))
