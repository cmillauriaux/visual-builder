extends GutTest

const SequenceFxPlayerScript = preload("res://src/ui/visual/sequence_fx_player.gd")
const SequenceFx = preload("res://src/models/sequence_fx.gd")

var _player: Node
var _target: Control


func before_each() -> void:
	_player = Node.new()
	_player.set_script(SequenceFxPlayerScript)
	add_child(_player)
	_target = Control.new()
	_target.size = Vector2(800, 600)
	add_child(_target)


func after_each() -> void:
	_player.stop_fx()
	remove_child(_player)
	_player.queue_free()
	remove_child(_target)
	_target.queue_free()


func test_is_playing_default_false() -> void:
	assert_false(_player.is_playing())


func test_play_empty_list_emits_finished() -> void:
	watch_signals(_player)
	_player.play_fx_list([], _target)
	assert_signal_emitted(_player, "fx_finished")


func test_play_empty_list_not_playing() -> void:
	_player.play_fx_list([], _target)
	assert_false(_player.is_playing())


func test_play_fx_list_sets_playing() -> void:
	var fx = SequenceFx.new()
	fx.fx_type = "fade_in"
	fx.duration = 1.0
	_player.play_fx_list([fx], _target)
	assert_true(_player.is_playing())


func test_stop_fx_stops_playing() -> void:
	var fx = SequenceFx.new()
	fx.fx_type = "fade_in"
	fx.duration = 5.0
	_player.play_fx_list([fx], _target)
	assert_true(_player.is_playing())
	_player.stop_fx()
	assert_false(_player.is_playing())


func test_stop_fx_when_not_playing() -> void:
	_player.stop_fx()
	assert_false(_player.is_playing())
	pass_test("should not crash when stopping while not playing")


func test_play_screen_shake_sets_playing() -> void:
	var fx = SequenceFx.new()
	fx.fx_type = "screen_shake"
	fx.duration = 0.5
	fx.intensity = 1.0
	_player.play_fx_list([fx], _target)
	assert_true(_player.is_playing())


func test_play_fade_in_creates_overlay() -> void:
	var fx = SequenceFx.new()
	fx.fx_type = "fade_in"
	fx.duration = 1.0
	_player.play_fx_list([fx], _target)
	var overlay = _target.get_node_or_null("FxFadeOverlay")
	assert_not_null(overlay, "should create fade overlay")
	assert_true(overlay is ColorRect)


func test_play_eyes_blink_creates_bars() -> void:
	var fx = SequenceFx.new()
	fx.fx_type = "eyes_blink"
	fx.duration = 1.0
	_player.play_fx_list([fx], _target)
	var top = _target.get_node_or_null("FxEyesTop")
	var bottom = _target.get_node_or_null("FxEyesBottom")
	assert_not_null(top, "should create top bar")
	assert_not_null(bottom, "should create bottom bar")


func test_play_multiple_fx_sequentially() -> void:
	var fx1 = SequenceFx.new()
	fx1.fx_type = "fade_in"
	fx1.duration = 0.1
	var fx2 = SequenceFx.new()
	fx2.fx_type = "screen_shake"
	fx2.duration = 0.1
	_player.play_fx_list([fx1, fx2], _target)
	assert_true(_player.is_playing())


func test_stop_cleans_up_fade_overlay() -> void:
	var fx = SequenceFx.new()
	fx.fx_type = "fade_in"
	fx.duration = 5.0
	_player.play_fx_list([fx], _target)
	assert_not_null(_target.get_node_or_null("FxFadeOverlay"))
	_player.stop_fx()
	# queue_free is deferred, so check _fx_nodes is cleared
	assert_eq(_player._fx_nodes.size(), 0)


func test_stop_cleans_up_eyes_blink() -> void:
	var fx = SequenceFx.new()
	fx.fx_type = "eyes_blink"
	fx.duration = 5.0
	_player.play_fx_list([fx], _target)
	_player.stop_fx()
	assert_eq(_player._fx_nodes.size(), 0)


func test_stop_restores_position_after_shake() -> void:
	_target.position = Vector2(100, 200)
	var fx = SequenceFx.new()
	fx.fx_type = "screen_shake"
	fx.duration = 5.0
	fx.intensity = 2.0
	_player.play_fx_list([fx], _target)
	_player.stop_fx()
	assert_eq(_target.position, Vector2(100, 200))


func test_play_fx_list_stops_previous() -> void:
	var fx1 = SequenceFx.new()
	fx1.fx_type = "fade_in"
	fx1.duration = 5.0
	_player.play_fx_list([fx1], _target)
	assert_true(_player.is_playing())

	var fx2 = SequenceFx.new()
	fx2.fx_type = "screen_shake"
	fx2.duration = 5.0
	_player.play_fx_list([fx2], _target)
	assert_true(_player.is_playing())
