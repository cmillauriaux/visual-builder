extends Node

## Exécute les effets visuels (FX) d'une séquence séquentiellement via tweens.

signal fx_finished

var _playing: bool = false
var _current_tween: Tween = null
var _fx_nodes: Array = []
var _target: Control = null
var _original_position: Vector2 = Vector2.ZERO


func play_fx_list(fx_list: Array, target: Control) -> void:
	stop_fx()
	if fx_list.is_empty():
		fx_finished.emit()
		return
	_target = target
	_playing = true
	_play_next(fx_list.duplicate(), target)


func stop_fx() -> void:
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
		_current_tween = null
	_cleanup_fx_nodes()
	if _target and is_instance_valid(_target):
		_target.position = _original_position
	_playing = false


func is_playing() -> bool:
	return _playing


func _play_next(remaining: Array, target: Control) -> void:
	if remaining.is_empty() or not _playing:
		_playing = false
		fx_finished.emit()
		return
	var fx = remaining.pop_front()
	_play_single_fx(fx, target, func(): _play_next(remaining, target))


func _play_single_fx(fx, target: Control, on_done: Callable) -> void:
	match fx.fx_type:
		"screen_shake":
			_play_screen_shake(fx, target, on_done)
		"fade_in":
			_play_fade_in(fx, target, on_done)
		"eyes_blink":
			_play_eyes_blink(fx, target, on_done)
		_:
			on_done.call()


func _play_screen_shake(fx, target: Control, on_done: Callable) -> void:
	_original_position = target.position
	var amplitude = fx.intensity * 10.0
	var oscillations = 6
	var step_duration = fx.duration / float(oscillations * 2)

	_current_tween = create_tween()
	for i in range(oscillations):
		var offset = amplitude if (i % 2 == 0) else -amplitude
		_current_tween.tween_property(target, "position:x", _original_position.x + offset, step_duration)
		_current_tween.tween_property(target, "position:x", _original_position.x - offset, step_duration)
	_current_tween.tween_property(target, "position:x", _original_position.x, step_duration)
	_current_tween.finished.connect(func():
		target.position = _original_position
		on_done.call()
	)


func _play_fade_in(fx, target: Control, on_done: Callable) -> void:
	var overlay = ColorRect.new()
	overlay.name = "FxFadeOverlay"
	overlay.color = Color(0, 0, 0, 1)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target.add_child(overlay)
	_fx_nodes.append(overlay)

	_current_tween = create_tween()
	_current_tween.tween_property(overlay, "color:a", 0.0, fx.duration)
	_current_tween.finished.connect(func():
		if is_instance_valid(overlay):
			_fx_nodes.erase(overlay)
			overlay.queue_free()
		on_done.call()
	)


func _play_eyes_blink(fx, target: Control, on_done: Callable) -> void:
	var target_size = target.size

	var top_bar = ColorRect.new()
	top_bar.name = "FxEyesTop"
	top_bar.color = Color(0, 0, 0, 1)
	top_bar.position = Vector2.ZERO
	top_bar.size = Vector2(target_size.x, target_size.y / 2.0)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target.add_child(top_bar)
	_fx_nodes.append(top_bar)

	var bottom_bar = ColorRect.new()
	bottom_bar.name = "FxEyesBottom"
	bottom_bar.color = Color(0, 0, 0, 1)
	bottom_bar.position = Vector2(0, target_size.y / 2.0)
	bottom_bar.size = Vector2(target_size.x, target_size.y / 2.0)
	bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target.add_child(bottom_bar)
	_fx_nodes.append(bottom_bar)

	var closed_duration = fx.duration * 0.25
	var open_duration = fx.duration * 0.75

	_current_tween = create_tween()
	# Phase 1: stay closed
	_current_tween.tween_interval(closed_duration)
	# Phase 2: open — top bar shrinks upward, bottom bar moves down and shrinks
	_current_tween.tween_property(top_bar, "size:y", 0.0, open_duration).set_parallel(false)
	_current_tween.tween_property(bottom_bar, "position:y", target_size.y, open_duration).set_parallel(true)
	_current_tween.tween_property(bottom_bar, "size:y", 0.0, open_duration).set_parallel(true)
	_current_tween.finished.connect(func():
		if is_instance_valid(top_bar):
			_fx_nodes.erase(top_bar)
			top_bar.queue_free()
		if is_instance_valid(bottom_bar):
			_fx_nodes.erase(bottom_bar)
			bottom_bar.queue_free()
		on_done.call()
	)


func _cleanup_fx_nodes() -> void:
	for node in _fx_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_fx_nodes.clear()
