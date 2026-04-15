# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends Control
class_name ForegroundAnimPlayer

## Lecteur de frames pour foregrounds APNG.
## Cycle les frames via _process(delta) selon les options de lecture.

const ApngLoaderScript = preload("res://src/ui/shared/apng_loader.gd")

var anim_speed: float = 1.0
var anim_reverse: bool = false
var anim_loop: bool = true
var anim_reverse_loop: bool = false

var flip_h: bool = false:
	set(v):
		flip_h = v
		if _tex_rect:
			_tex_rect.flip_h = v

var flip_v: bool = false:
	set(v):
		flip_v = v
		if _tex_rect:
			_tex_rect.flip_v = v

var _frames: Array = []  # Array[ImageTexture]
var _delays: Array = []  # Array[float]
var _current_frame: int = 0
var _elapsed: float = 0.0
var _playing: bool = false
var _tex_rect: TextureRect


func _ready() -> void:
	_tex_rect = TextureRect.new()
	_tex_rect.name = "Texture"
	_tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_tex_rect)
	set_process(false)


func load_apng(path: String) -> bool:
	var result = ApngLoaderScript.load(path)
	if result.is_empty():
		return false
	_frames = result["frames"]
	_delays = result["delays"]
	_current_frame = 0
	_elapsed = 0.0
	if not _frames.is_empty() and _tex_rect:
		_tex_rect.texture = _frames[0]
	return true


func play() -> void:
	if _frames.is_empty():
		return
	_current_frame = _frames.size() - 1 if anim_reverse_loop else 0
	_elapsed = 0.0
	_playing = true
	set_process(true)


func stop() -> void:
	_playing = false
	set_process(false)


func is_playing() -> bool:
	return _playing


func get_first_frame_texture() -> Texture2D:
	if _frames.is_empty():
		return null
	return _frames[0]


func _process(delta: float) -> void:
	if not _playing or _frames.is_empty():
		return
	_elapsed += delta
	var frame_delay = _delays[_current_frame] / maxf(anim_speed, 0.01)
	if _elapsed < frame_delay:
		return
	_elapsed = 0.0

	if anim_reverse_loop:
		_current_frame -= 1
		if _current_frame < 0:
			_current_frame = _frames.size() - 1
	elif anim_loop:
		_current_frame += 1
		if _current_frame >= _frames.size():
			_current_frame = 0
	elif anim_reverse:
		_current_frame -= 1
		if _current_frame < 0:
			_current_frame = 0
			stop()
			return
	else:
		_current_frame += 1
		if _current_frame >= _frames.size():
			_current_frame = _frames.size() - 1
			stop()
			return

	if _tex_rect:
		_tex_rect.texture = _frames[_current_frame]
