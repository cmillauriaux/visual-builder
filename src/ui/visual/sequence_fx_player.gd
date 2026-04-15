# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends Node

## Exécute les effets visuels (FX) d'une séquence séquentiellement via tweens.

signal fx_finished

var _playing: bool = false
var _current_tween: Tween = null
var _fx_nodes: Array = []
var _target: Control = null
var _transform_target: Control = null
var _transform_active: bool = false
var _pre_applied: bool = false
var _original_position: Vector2 = Vector2.ZERO
var _original_scale: Vector2 = Vector2.ONE
var _original_pivot: Vector2 = Vector2.ZERO

## FX persistants (restent jusqu'à la séquence suivante)
const PERSISTENT_FX_TYPES = ["vignette", "desaturation"]
var _persistent_fx: Dictionary = {}  # fx_type -> overlay node

## Tweens des FX lancés en parallèle (continue_during_fx = true)
var _detached_tweens: Array = []

const VIGNETTE_SHADER = """
shader_type canvas_item;
uniform float strength : hint_range(0.0, 3.0) = 0.0;

void fragment() {
	vec2 uv = UV;
	float dist = distance(uv, vec2(0.5));
	float vignette = smoothstep(0.3, 0.7, dist) * strength;
	COLOR = vec4(0.0, 0.0, 0.0, vignette);
}
"""

const DESATURATION_SHADER = """
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 col = texture(screen_texture, SCREEN_UV);
	float gray = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(col.rgb, vec3(gray), amount), col.a);
}
"""

const PIXELATE_SHADER = """
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float amount : hint_range(0.0, 512.0) = 0.0;

void fragment() {
	if (amount > 0.0) {
		vec2 size = vec2(textureSize(screen_texture, 0));
		float pixel_size = amount;
		vec2 uv = floor(SCREEN_UV * size / pixel_size) * pixel_size / size;
		COLOR = texture(screen_texture, uv);
	} else {
		COLOR = texture(screen_texture, SCREEN_UV);
	}
}
"""

## Applique immédiatement les FX persistants (vignette, désaturation) à pleine intensité.
## Gère la transition entre séquences : garde les FX existants si le type correspond,
## supprime ceux qui ne sont plus nécessaires, et crée les nouveaux.
func apply_persistent_fx(fx_list: Array, target: Control) -> void:
	var needed: Dictionary = {}
	for fx in fx_list:
		if fx.fx_type in PERSISTENT_FX_TYPES:
			needed[fx.fx_type] = fx

	# Supprimer les FX persistants qui ne sont plus dans la nouvelle liste
	var to_remove: Array = []
	for fx_type in _persistent_fx:
		if fx_type not in needed:
			to_remove.append(fx_type)
	for fx_type in to_remove:
		var overlay = _persistent_fx[fx_type]
		if is_instance_valid(overlay):
			overlay.queue_free()
		_persistent_fx.erase(fx_type)

	# Créer ou mettre à jour les FX persistants
	for fx_type in needed:
		if _persistent_fx.has(fx_type) and is_instance_valid(_persistent_fx[fx_type]):
			# Déjà actif — mettre à jour l'intensité
			var mat = _persistent_fx[fx_type].material as ShaderMaterial
			if mat:
				match fx_type:
					"vignette":
						mat.set_shader_parameter("strength", needed[fx_type].intensity)
					"desaturation":
						mat.set_shader_parameter("amount", minf(needed[fx_type].intensity, 1.0))
			continue
		match fx_type:
			"vignette":
				_create_vignette_immediate(needed[fx_type], target)
			"desaturation":
				_create_desaturation_immediate(needed[fx_type], target)


func _create_vignette_immediate(fx, target: Control) -> void:
	var overlay = ColorRect.new()
	overlay.name = "FxVignetteOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target.add_child(overlay)
	_persistent_fx["vignette"] = overlay
	var mat = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = VIGNETTE_SHADER
	mat.shader = shader
	overlay.material = mat
	mat.set_shader_parameter("strength", fx.intensity)


func _create_desaturation_immediate(fx, target: Control) -> void:
	var overlay = ColorRect.new()
	overlay.name = "FxDesaturationOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target.add_child(overlay)
	_persistent_fx["desaturation"] = overlay
	var mat = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = DESATURATION_SHADER
	mat.shader = shader
	overlay.material = mat
	mat.set_shader_parameter("amount", minf(fx.intensity, 1.0))


## Applique immédiatement l'état initial d'un FX zoom/pan pour éviter un flash visuel au démarrage.
## Doit être appelé AVANT play_transition() pour que le canvas soit déjà dans l'état correct pendant
## la transition d'ouverture.
func pre_apply_initial_transform(fx_list: Array, transform_target: Control) -> void:
	if transform_target == null or not is_instance_valid(transform_target):
		return
	_transform_target = transform_target
	for fx in fx_list:
		if fx.fx_type in ["zoom_in", "zoom_out"]:
			_original_scale = transform_target.scale
			_original_pivot = transform_target.pivot_offset
			_original_position = transform_target.position
			var scale_from: float = maxf(fx.zoom_from, 1.0)
			transform_target.pivot_offset = transform_target.size / 2.0
			transform_target.scale = Vector2(scale_from, scale_from)
			_pre_applied = true
			break
		elif fx.fx_type in ["pan_right", "pan_left", "pan_down", "pan_up"]:
			_original_scale = transform_target.scale
			_original_pivot = transform_target.pivot_offset
			_original_position = transform_target.position
			var apply_zoom: float = maxf(fx.zoom_from, 1.001)
			transform_target.pivot_offset = transform_target.size / 2.0
			transform_target.scale = Vector2(apply_zoom, apply_zoom)
			var extra_x: float = transform_target.size.x * (apply_zoom - 1.0) / 2.0
			var extra_y: float = transform_target.size.y * (apply_zoom - 1.0) / 2.0
			match fx.fx_type:
				"pan_right":
					transform_target.position = Vector2(_original_position.x + extra_x, _original_position.y)
				"pan_left":
					transform_target.position = Vector2(_original_position.x - extra_x, _original_position.y)
				"pan_down":
					transform_target.position = Vector2(_original_position.x, _original_position.y + extra_y)
				"pan_up":
					transform_target.position = Vector2(_original_position.x, _original_position.y - extra_y)
			_pre_applied = true
			break


func play_fx_list(fx_list: Array, target: Control, transform_target: Control = null) -> void:
	# Déterminer quels FX persistants la nouvelle liste contient
	var new_persistent_types: Array = []
	for fx in fx_list:
		if fx.fx_type in PERSISTENT_FX_TYPES:
			new_persistent_types.append(fx.fx_type)

	# Supprimer les FX persistants qui ne sont PAS dans la nouvelle liste
	var types_to_remove: Array = []
	for fx_type in _persistent_fx:
		if fx_type not in new_persistent_types:
			types_to_remove.append(fx_type)
	for fx_type in types_to_remove:
		var overlay = _persistent_fx[fx_type]
		if is_instance_valid(overlay):
			overlay.queue_free()
		_persistent_fx.erase(fx_type)

	# Filtrer les FX persistants déjà actifs (éviter le clignotement)
	var filtered_fx_list: Array = []
	for fx in fx_list:
		if fx.fx_type in PERSISTENT_FX_TYPES and fx.fx_type in _persistent_fx:
			continue  # déjà affiché, on le garde tel quel
		filtered_fx_list.append(fx)

	# Arrêter les FX transitoires (pas les persistants)
	_stop_transient_fx()

	if filtered_fx_list.is_empty():
		fx_finished.emit()
		return
	_target = target
	_transform_target = transform_target if transform_target else target
	_playing = true
	_play_next(filtered_fx_list.duplicate(), target)


func play_transition(type: String, duration: float, is_in: bool, target: Control) -> void:
	_stop_transient_fx()
	if type == "none" or duration <= 0:
		fx_finished.emit()
		return
	
	_target = target
	_playing = true
	
	match type:
		"fade":
			if is_in:
				_play_fade_in_transition(duration, target)
			else:
				_play_fade_out_transition(duration, target)
		"pixelate":
			if is_in:
				_play_pixelate_in_transition(duration, target)
			else:
				_play_pixelate_out_transition(duration, target)
		_:
			_playing = false
			fx_finished.emit()


func _play_fade_in_transition(duration: float, target: Control) -> void:
	var overlay = ColorRect.new()
	overlay.name = "TransFadeInOverlay"
	overlay.color = Color(0, 0, 0, 1)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target.add_child(overlay)
	_fx_nodes.append(overlay)

	_current_tween = create_tween()
	_current_tween.tween_property(overlay, "color:a", 0.0, duration)
	_current_tween.finished.connect(func():
		if is_instance_valid(overlay):
			_fx_nodes.erase(overlay)
			overlay.queue_free()
		_playing = false
		fx_finished.emit()
	)


func _play_fade_out_transition(duration: float, target: Control) -> void:
	var overlay = ColorRect.new()
	overlay.name = "TransFadeOutOverlay"
	overlay.color = Color(0, 0, 0, 0)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target.add_child(overlay)
	_fx_nodes.append(overlay)

	_current_tween = create_tween()
	_current_tween.tween_property(overlay, "color:a", 1.0, duration)
	_current_tween.finished.connect(func():
		# Note: we don't queue_free the overlay yet because it should stay black until next sequence
		_playing = false
		fx_finished.emit()
	)


func _play_pixelate_in_transition(duration: float, target: Control) -> void:
	var overlay = ColorRect.new()
	overlay.name = "TransPixelateInOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target.add_child(overlay)
	_fx_nodes.append(overlay)

	var mat = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = PIXELATE_SHADER
	mat.shader = shader
	overlay.material = mat
	
	mat.set_shader_parameter("amount", 128.0)

	_current_tween = create_tween()
	_current_tween.tween_method(func(v): mat.set_shader_parameter("amount", v), 128.0, 0.0, duration)
	_current_tween.finished.connect(func():
		if is_instance_valid(overlay):
			_fx_nodes.erase(overlay)
			overlay.queue_free()
		_playing = false
		fx_finished.emit()
	)


func _play_pixelate_out_transition(duration: float, target: Control) -> void:
	var overlay = ColorRect.new()
	overlay.name = "TransPixelateOutOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target.add_child(overlay)
	_fx_nodes.append(overlay)

	var mat = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = PIXELATE_SHADER
	mat.shader = shader
	overlay.material = mat
	
	mat.set_shader_parameter("amount", 0.0)

	_current_tween = create_tween()
	_current_tween.tween_method(func(v): mat.set_shader_parameter("amount", v), 0.0, 128.0, duration)
	_current_tween.finished.connect(func():
		_playing = false
		fx_finished.emit()
	)


func stop_fx() -> void:
	_stop_transient_fx()
	# Restaurer le transform pré-appliqué si le tween n'était pas encore démarré
	if _pre_applied:
		var t = _transform_target if _transform_target and is_instance_valid(_transform_target) else _target
		if t and is_instance_valid(t):
			t.position = _original_position
			t.scale = _original_scale
			t.pivot_offset = _original_pivot
		_pre_applied = false
	_cleanup_persistent_fx()


func _stop_transient_fx() -> void:
	for tween in _detached_tweens:
		if tween and tween.is_valid():
			tween.kill()
	_detached_tweens.clear()
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
		_current_tween = null
	_cleanup_fx_nodes()
	if _transform_active:
		var t = _transform_target if _transform_target and is_instance_valid(_transform_target) else _target
		if t and is_instance_valid(t):
			t.position = _original_position
			t.scale = _original_scale
			t.pivot_offset = _original_pivot
		_transform_active = false
	_playing = false


func is_playing() -> bool:
	return _playing


func _play_next(remaining: Array, target: Control) -> void:
	if remaining.is_empty() or not _playing:
		_playing = false
		fx_finished.emit()
		return
	var fx = remaining.pop_front()
	if fx.continue_during_fx:
		# Lancer le FX sans bloquer la chaîne : démarre l'animation et continue immédiatement
		_play_single_fx(fx, target, func(): pass)
		# Déplacer le tween vers la liste des détachés pour qu'il survive mais soit nettoyé par stop_fx
		if _current_tween and _current_tween.is_valid():
			_detached_tweens.append(_current_tween)
			_current_tween = null
		_play_next(remaining, target)
	else:
		_play_single_fx(fx, target, func(): _play_next(remaining, target))


func _play_single_fx(fx, target: Control, on_done: Callable) -> void:
	match fx.fx_type:
		"screen_shake":
			_play_screen_shake(fx, target, on_done)
		"fade_in":
			_play_fade_in(fx, target, on_done)
		"eyes_blink":
			_play_eyes_blink(fx, target, on_done)
		"flash":
			_play_flash(fx, target, on_done)
		"zoom":
			_play_zoom(fx, target, on_done)
		"zoom_in", "zoom_out":
			_play_zoom_animated(fx, target, on_done)
		"pan_right", "pan_left", "pan_down", "pan_up":
			_play_pan(fx, target, on_done)
		"vignette":
			_play_vignette(fx, target, on_done)
		"desaturation":
			_play_desaturation(fx, target, on_done)
		_:
			on_done.call()


func _play_screen_shake(fx, target: Control, on_done: Callable) -> void:
	var t = _transform_target if _transform_target else target
	_transform_active = true
	_original_position = t.position
	var amplitude = fx.intensity * 10.0
	var oscillations = 6
	var step_duration = fx.duration / float(oscillations * 2)

	_current_tween = create_tween()
	for i in range(oscillations):
		var offset = amplitude if (i % 2 == 0) else -amplitude
		_current_tween.tween_property(t, "position:x", _original_position.x + offset, step_duration)
		_current_tween.tween_property(t, "position:x", _original_position.x - offset, step_duration)
	_current_tween.tween_property(t, "position:x", _original_position.x, step_duration)
	_current_tween.finished.connect(func():
		t.position = _original_position
		_transform_active = false
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
	# Phase 2: open — top bar shrinks upward, bottom bar moves down and shrinks (parallel)
	_current_tween.tween_property(top_bar, "size:y", 0.0, open_duration)
	_current_tween.parallel().tween_property(bottom_bar, "position:y", target_size.y, open_duration)
	_current_tween.parallel().tween_property(bottom_bar, "size:y", 0.0, open_duration)
	_current_tween.finished.connect(func():
		if is_instance_valid(top_bar):
			_fx_nodes.erase(top_bar)
			top_bar.queue_free()
		if is_instance_valid(bottom_bar):
			_fx_nodes.erase(bottom_bar)
			bottom_bar.queue_free()
		on_done.call()
	)


func _play_flash(fx, target: Control, on_done: Callable) -> void:
	var overlay = ColorRect.new()
	overlay.name = "FxFlashOverlay"
	overlay.color = Color(fx.color.r, fx.color.g, fx.color.b, 0.0)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target.add_child(overlay)
	_fx_nodes.append(overlay)

	var peak_alpha = minf(fx.intensity, 1.0)
	var fade_in_dur = fx.duration * 0.3
	var hold_dur = fx.duration * 0.2
	var fade_out_dur = fx.duration * 0.5

	_current_tween = create_tween()
	_current_tween.tween_property(overlay, "color:a", peak_alpha, fade_in_dur)
	_current_tween.tween_interval(hold_dur)
	_current_tween.tween_property(overlay, "color:a", 0.0, fade_out_dur)
	_current_tween.finished.connect(func():
		if is_instance_valid(overlay):
			_fx_nodes.erase(overlay)
			overlay.queue_free()
		on_done.call()
	)


func _play_zoom(fx, target: Control, on_done: Callable) -> void:
	var t = _transform_target if _transform_target else target
	_transform_active = true
	_original_scale = t.scale
	_original_pivot = t.pivot_offset
	t.pivot_offset = t.size / 2.0

	var zoom_level = 1.0 + fx.intensity * 0.15
	var zoom_in_dur = fx.duration * 0.4
	var hold_dur = fx.duration * 0.2
	var zoom_out_dur = fx.duration * 0.4

	_current_tween = create_tween()
	_current_tween.tween_property(t, "scale", Vector2(zoom_level, zoom_level), zoom_in_dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_current_tween.tween_interval(hold_dur)
	_current_tween.tween_property(t, "scale", Vector2.ONE, zoom_out_dur).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_current_tween.finished.connect(func():
		t.scale = _original_scale
		t.pivot_offset = _original_pivot
		_transform_active = false
		on_done.call()
	)


func _play_zoom_animated(fx, target: Control, on_done: Callable) -> void:
	var t = _transform_target if _transform_target else target
	_transform_active = true
	if not _pre_applied:
		# Sauvegarder l'état original seulement si pre_apply ne l'a pas déjà fait
		_original_scale = t.scale
		_original_pivot = t.pivot_offset
		_original_position = t.position
		t.pivot_offset = t.size / 2.0
	_pre_applied = false

	var scale_from: float = maxf(fx.zoom_from, 1.0)
	var scale_to: float = maxf(fx.zoom_to, 1.0)
	t.scale = Vector2(scale_from, scale_from)

	# Capturer localement pour la closure (évite les problèmes si les membres sont écrasés par un FX concurrent)
	var restore_scale: Vector2 = _original_scale
	var restore_pivot: Vector2 = _original_pivot
	var restore_pos: Vector2 = _original_position

	_current_tween = create_tween()
	_current_tween.tween_property(t, "scale", Vector2(scale_to, scale_to), fx.duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	_current_tween.finished.connect(func():
		# Keep canvas at final zoom state for the rest of the sequence.
		# stop_fx() will restore the original transform when play ends.
		on_done.call()
	)


func _play_pan(fx, target: Control, on_done: Callable) -> void:
	var t = _transform_target if _transform_target else target
	_transform_active = true
	if not _pre_applied:
		# Sauvegarder l'état original seulement si pre_apply ne l'a pas déjà fait
		_original_scale = t.scale
		_original_pivot = t.pivot_offset
		_original_position = t.position
		var apply_zoom: float = maxf(fx.zoom_from, 1.001)
		t.pivot_offset = t.size / 2.0
		t.scale = Vector2(apply_zoom, apply_zoom)
	_pre_applied = false

	var zoom: float = maxf(fx.zoom_from, 1.001)
	var extra_x: float = t.size.x * (zoom - 1.0) / 2.0
	var extra_y: float = t.size.y * (zoom - 1.0) / 2.0
	var scroll: float = clampf(fx.intensity, 0.0, 1.0)

	var start_pos: Vector2 = _original_position
	var end_pos: Vector2 = _original_position

	match fx.fx_type:
		"pan_right":
			start_pos = Vector2(_original_position.x + extra_x, _original_position.y)
			end_pos = Vector2(_original_position.x + extra_x - 2.0 * extra_x * scroll, _original_position.y)
		"pan_left":
			start_pos = Vector2(_original_position.x - extra_x, _original_position.y)
			end_pos = Vector2(_original_position.x - extra_x + 2.0 * extra_x * scroll, _original_position.y)
		"pan_down":
			start_pos = Vector2(_original_position.x, _original_position.y + extra_y)
			end_pos = Vector2(_original_position.x, _original_position.y + extra_y - 2.0 * extra_y * scroll)
		"pan_up":
			start_pos = Vector2(_original_position.x, _original_position.y - extra_y)
			end_pos = Vector2(_original_position.x, _original_position.y - extra_y + 2.0 * extra_y * scroll)

	t.position = start_pos

	# Capturer localement pour la closure (évite les problèmes si les membres sont écrasés par un FX concurrent)
	var restore_scale: Vector2 = _original_scale
	var restore_pivot: Vector2 = _original_pivot
	var restore_pos: Vector2 = _original_position

	_current_tween = create_tween()
	_current_tween.tween_property(t, "position", end_pos, fx.duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_current_tween.finished.connect(func():
		# Keep canvas at final pan state for the rest of the sequence.
		# stop_fx() will restore the original transform when play ends.
		on_done.call()
	)


func _play_vignette(fx, target: Control, on_done: Callable) -> void:
	var overlay = ColorRect.new()
	overlay.name = "FxVignetteOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target.add_child(overlay)
	_persistent_fx["vignette"] = overlay

	var mat = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = VIGNETTE_SHADER
	mat.shader = shader
	overlay.material = mat
	mat.set_shader_parameter("strength", 0.0)

	_current_tween = create_tween()
	_current_tween.tween_method(func(v): mat.set_shader_parameter("strength", v), 0.0, fx.intensity, fx.duration)
	_current_tween.finished.connect(func():
		on_done.call()
	)


func _play_desaturation(fx, target: Control, on_done: Callable) -> void:
	var overlay = ColorRect.new()
	overlay.name = "FxDesaturationOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target.add_child(overlay)
	_persistent_fx["desaturation"] = overlay

	var mat = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = DESATURATION_SHADER
	mat.shader = shader
	overlay.material = mat
	mat.set_shader_parameter("amount", 0.0)

	var peak_amount = minf(fx.intensity, 1.0)

	_current_tween = create_tween()
	_current_tween.tween_method(func(v): mat.set_shader_parameter("amount", v), 0.0, peak_amount, fx.duration)
	_current_tween.finished.connect(func():
		on_done.call()
	)


func _cleanup_fx_nodes() -> void:
	for node in _fx_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_fx_nodes.clear()


func _cleanup_persistent_fx() -> void:
	for fx_type in _persistent_fx:
		var overlay = _persistent_fx[fx_type]
		if is_instance_valid(overlay):
			overlay.queue_free()
	_persistent_fx.clear()
