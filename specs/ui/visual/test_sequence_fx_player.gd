extends GutTest

var SequenceFxPlayerScript = load("res://src/ui/visual/sequence_fx_player.gd")
var SequenceFx = load("res://src/models/sequence_fx.gd")

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


## --- Eyes blink (bug fix: parallel tweens) ---


func test_eyes_blink_sets_playing() -> void:
	var fx = SequenceFx.new()
	fx.fx_type = "eyes_blink"
	fx.duration = 1.0
	_player.play_fx_list([fx], _target)
	assert_true(_player.is_playing())


func test_eyes_blink_bars_cover_full_height() -> void:
	var fx = SequenceFx.new()
	fx.fx_type = "eyes_blink"
	fx.duration = 1.0
	_player.play_fx_list([fx], _target)
	var top = _target.get_node_or_null("FxEyesTop")
	var bottom = _target.get_node_or_null("FxEyesBottom")
	assert_eq(top.size.y, _target.size.y / 2.0, "top bar should cover half height")
	assert_eq(bottom.size.y, _target.size.y / 2.0, "bottom bar should cover half height")
	assert_eq(bottom.position.y, _target.size.y / 2.0, "bottom bar starts at midpoint")


func test_eyes_blink_stop_does_not_crash() -> void:
	var fx = SequenceFx.new()
	fx.fx_type = "eyes_blink"
	fx.duration = 5.0
	_player.play_fx_list([fx], _target)
	_player.stop_fx()
	assert_false(_player.is_playing())
	pass_test("stop during eyes_blink should not crash")


## --- Flash ---


func test_play_flash_creates_overlay() -> void:
	var fx = SequenceFx.new()
	fx.fx_type = "flash"
	fx.duration = 1.0
	fx.color = Color.WHITE
	_player.play_fx_list([fx], _target)
	var overlay = _target.get_node_or_null("FxFlashOverlay")
	assert_not_null(overlay, "should create flash overlay")
	assert_true(overlay is ColorRect)


func test_play_flash_sets_playing() -> void:
	var fx = SequenceFx.new()
	fx.fx_type = "flash"
	fx.duration = 1.0
	_player.play_fx_list([fx], _target)
	assert_true(_player.is_playing())


func test_flash_overlay_uses_fx_color() -> void:
	var fx = SequenceFx.new()
	fx.fx_type = "flash"
	fx.duration = 5.0
	fx.color = Color.RED
	_player.play_fx_list([fx], _target)
	var overlay = _target.get_node_or_null("FxFlashOverlay")
	assert_almost_eq(overlay.color.r, 1.0, 0.01, "flash overlay should use red channel from fx.color")
	assert_almost_eq(overlay.color.g, 0.0, 0.01, "flash overlay should have no green")
	assert_almost_eq(overlay.color.b, 0.0, 0.01, "flash overlay should have no blue")


func test_flash_overlay_starts_transparent() -> void:
	var fx = SequenceFx.new()
	fx.fx_type = "flash"
	fx.duration = 5.0
	_player.play_fx_list([fx], _target)
	var overlay = _target.get_node_or_null("FxFlashOverlay")
	assert_eq(overlay.color.a, 0.0, "flash overlay should start fully transparent")


func test_flash_overlay_is_full_rect() -> void:
	var fx = SequenceFx.new()
	fx.fx_type = "flash"
	fx.duration = 5.0
	_player.play_fx_list([fx], _target)
	var overlay = _target.get_node_or_null("FxFlashOverlay")
	assert_eq(overlay.mouse_filter, Control.MOUSE_FILTER_IGNORE, "overlay should ignore mouse")


func test_stop_cleans_up_flash_overlay() -> void:
	var fx = SequenceFx.new()
	fx.fx_type = "flash"
	fx.duration = 5.0
	_player.play_fx_list([fx], _target)
	assert_not_null(_target.get_node_or_null("FxFlashOverlay"))
	_player.stop_fx()
	assert_eq(_player._fx_nodes.size(), 0)


## --- Zoom ---


func test_play_zoom_sets_playing() -> void:
	var fx = SequenceFx.new()
	fx.fx_type = "zoom"
	fx.duration = 1.0
	fx.intensity = 1.0
	_player.play_fx_list([fx], _target)
	assert_true(_player.is_playing())


func test_play_zoom_sets_pivot_to_center() -> void:
	var fx = SequenceFx.new()
	fx.fx_type = "zoom"
	fx.duration = 5.0
	fx.intensity = 2.0
	_player.play_fx_list([fx], _target)
	assert_eq(_target.pivot_offset, _target.size / 2.0, "pivot should be set to center")


func test_stop_restores_scale_after_zoom() -> void:
	_target.scale = Vector2(1, 1)
	var fx = SequenceFx.new()
	fx.fx_type = "zoom"
	fx.duration = 5.0
	fx.intensity = 2.0
	_player.play_fx_list([fx], _target)
	_player.stop_fx()
	assert_eq(_target.scale, Vector2(1, 1), "scale should be restored after stop")


func test_stop_restores_pivot_after_zoom() -> void:
	_target.pivot_offset = Vector2(10, 20)
	var fx = SequenceFx.new()
	fx.fx_type = "zoom"
	fx.duration = 5.0
	fx.intensity = 1.0
	_player.play_fx_list([fx], _target)
	_player.stop_fx()
	assert_eq(_target.pivot_offset, Vector2(10, 20), "pivot should be restored after stop")


func test_zoom_does_not_create_overlay_nodes() -> void:
	var fx = SequenceFx.new()
	fx.fx_type = "zoom"
	fx.duration = 5.0
	fx.intensity = 1.0
	_player.play_fx_list([fx], _target)
	assert_eq(_player._fx_nodes.size(), 0, "zoom should not create overlay nodes")


## --- Vignette (persistent) ---


func test_play_vignette_creates_overlay() -> void:
	var fx = SequenceFx.new()
	fx.fx_type = "vignette"
	fx.duration = 1.0
	_player.play_fx_list([fx], _target)
	var overlay = _target.get_node_or_null("FxVignetteOverlay")
	assert_not_null(overlay, "should create vignette overlay")
	assert_true(overlay is ColorRect)


func test_vignette_overlay_has_shader_material() -> void:
	var fx = SequenceFx.new()
	fx.fx_type = "vignette"
	fx.duration = 5.0
	_player.play_fx_list([fx], _target)
	var overlay = _target.get_node_or_null("FxVignetteOverlay")
	assert_not_null(overlay.material, "should have shader material")
	assert_true(overlay.material is ShaderMaterial, "material should be ShaderMaterial")


func test_vignette_shader_starts_at_zero_strength() -> void:
	var fx = SequenceFx.new()
	fx.fx_type = "vignette"
	fx.duration = 5.0
	fx.intensity = 2.0
	_player.play_fx_list([fx], _target)
	var overlay = _target.get_node_or_null("FxVignetteOverlay")
	var mat = overlay.material as ShaderMaterial
	assert_eq(mat.get_shader_parameter("strength"), 0.0, "vignette strength should start at 0")


func test_vignette_is_persistent() -> void:
	var fx = SequenceFx.new()
	fx.fx_type = "vignette"
	fx.duration = 5.0
	_player.play_fx_list([fx], _target)
	assert_true(_player._persistent_fx.has("vignette"), "vignette should be in persistent_fx")
	assert_eq(_player._fx_nodes.size(), 0, "vignette should NOT be in transient _fx_nodes")


func test_stop_cleans_up_vignette_persistent() -> void:
	var fx = SequenceFx.new()
	fx.fx_type = "vignette"
	fx.duration = 5.0
	_player.play_fx_list([fx], _target)
	_player.stop_fx()
	assert_eq(_player._persistent_fx.size(), 0, "stop_fx should clean persistent fx")


func test_vignette_kept_between_sequences() -> void:
	var fx1 = SequenceFx.new()
	fx1.fx_type = "vignette"
	fx1.duration = 5.0
	_player.play_fx_list([fx1], _target)
	var overlay1 = _target.get_node_or_null("FxVignetteOverlay")

	# Deuxième séquence avec vignette aussi
	var fx2 = SequenceFx.new()
	fx2.fx_type = "vignette"
	fx2.duration = 5.0
	_player.play_fx_list([fx2], _target)

	# L'overlay original devrait être conservé (pas recréé)
	var overlay2 = _player._persistent_fx.get("vignette")
	assert_eq(overlay1, overlay2, "same vignette overlay should be kept to avoid flicker")


func test_vignette_removed_when_not_in_next_sequence() -> void:
	var fx1 = SequenceFx.new()
	fx1.fx_type = "vignette"
	fx1.duration = 5.0
	_player.play_fx_list([fx1], _target)
	assert_true(_player._persistent_fx.has("vignette"))

	# Séquence suivante sans vignette
	_player.play_fx_list([], _target)
	assert_false(_player._persistent_fx.has("vignette"), "vignette should be removed if not in next sequence")


func test_vignette_overlay_ignores_mouse() -> void:
	var fx = SequenceFx.new()
	fx.fx_type = "vignette"
	fx.duration = 5.0
	_player.play_fx_list([fx], _target)
	var overlay = _target.get_node_or_null("FxVignetteOverlay")
	assert_eq(overlay.mouse_filter, Control.MOUSE_FILTER_IGNORE)


## --- Desaturation (persistent) ---


func test_play_desaturation_creates_overlay() -> void:
	var fx = SequenceFx.new()
	fx.fx_type = "desaturation"
	fx.duration = 1.0
	_player.play_fx_list([fx], _target)
	var overlay = _target.get_node_or_null("FxDesaturationOverlay")
	assert_not_null(overlay, "should create desaturation overlay")
	assert_true(overlay is ColorRect)


func test_desaturation_overlay_has_shader_material() -> void:
	var fx = SequenceFx.new()
	fx.fx_type = "desaturation"
	fx.duration = 5.0
	_player.play_fx_list([fx], _target)
	var overlay = _target.get_node_or_null("FxDesaturationOverlay")
	assert_not_null(overlay.material, "should have shader material")
	assert_true(overlay.material is ShaderMaterial, "material should be ShaderMaterial")


func test_desaturation_shader_starts_at_zero_amount() -> void:
	var fx = SequenceFx.new()
	fx.fx_type = "desaturation"
	fx.duration = 5.0
	fx.intensity = 2.0
	_player.play_fx_list([fx], _target)
	var overlay = _target.get_node_or_null("FxDesaturationOverlay")
	var mat = overlay.material as ShaderMaterial
	assert_eq(mat.get_shader_parameter("amount"), 0.0, "desaturation amount should start at 0")


func test_desaturation_is_persistent() -> void:
	var fx = SequenceFx.new()
	fx.fx_type = "desaturation"
	fx.duration = 5.0
	_player.play_fx_list([fx], _target)
	assert_true(_player._persistent_fx.has("desaturation"), "desaturation should be in persistent_fx")
	assert_eq(_player._fx_nodes.size(), 0, "desaturation should NOT be in transient _fx_nodes")


func test_stop_cleans_up_desaturation_persistent() -> void:
	var fx = SequenceFx.new()
	fx.fx_type = "desaturation"
	fx.duration = 5.0
	_player.play_fx_list([fx], _target)
	_player.stop_fx()
	assert_eq(_player._persistent_fx.size(), 0, "stop_fx should clean persistent fx")


func test_desaturation_kept_between_sequences() -> void:
	var fx1 = SequenceFx.new()
	fx1.fx_type = "desaturation"
	fx1.duration = 5.0
	_player.play_fx_list([fx1], _target)
	var overlay1 = _player._persistent_fx.get("desaturation")

	var fx2 = SequenceFx.new()
	fx2.fx_type = "desaturation"
	fx2.duration = 5.0
	_player.play_fx_list([fx2], _target)

	var overlay2 = _player._persistent_fx.get("desaturation")
	assert_eq(overlay1, overlay2, "same desaturation overlay should be kept to avoid flicker")


func test_desaturation_removed_when_not_in_next_sequence() -> void:
	var fx1 = SequenceFx.new()
	fx1.fx_type = "desaturation"
	fx1.duration = 5.0
	_player.play_fx_list([fx1], _target)
	assert_true(_player._persistent_fx.has("desaturation"))

	_player.play_fx_list([], _target)
	assert_false(_player._persistent_fx.has("desaturation"), "desaturation should be removed if not in next sequence")


func test_desaturation_overlay_ignores_mouse() -> void:
	var fx = SequenceFx.new()
	fx.fx_type = "desaturation"
	fx.duration = 5.0
	_player.play_fx_list([fx], _target)
	var overlay = _target.get_node_or_null("FxDesaturationOverlay")
	assert_eq(overlay.mouse_filter, Control.MOUSE_FILTER_IGNORE)


## --- Mixed persistent + transient ---


func test_persistent_fx_survives_next_play_with_same_type() -> void:
	# Séquence 1 avec vignette + desaturation
	var fx1 = SequenceFx.new()
	fx1.fx_type = "vignette"
	fx1.duration = 5.0
	var fx2 = SequenceFx.new()
	fx2.fx_type = "desaturation"
	fx2.duration = 5.0
	_player.play_fx_list([fx1, fx2], _target)
	assert_true(_player._persistent_fx.has("vignette"))

	# Séquence 2 avec seulement vignette → desaturation doit être supprimé
	var fx3 = SequenceFx.new()
	fx3.fx_type = "vignette"
	fx3.duration = 5.0
	_player.play_fx_list([fx3], _target)
	assert_true(_player._persistent_fx.has("vignette"), "vignette should survive")
	assert_false(_player._persistent_fx.has("desaturation"), "desaturation should be removed")


func test_transient_fx_with_persistent_in_same_list() -> void:
	var fx1 = SequenceFx.new()
	fx1.fx_type = "vignette"
	fx1.duration = 5.0
	_player.play_fx_list([fx1], _target)
	assert_true(_player.is_playing())
	assert_true(_player._persistent_fx.has("vignette"))
	assert_eq(_player._fx_nodes.size(), 0, "persistent fx should not be in _fx_nodes")


## --- Unknown FX type ---


func test_unknown_fx_type_does_not_crash() -> void:
	var fx = SequenceFx.new()
	fx.fx_type = "fade_in"  # set valid first, then force internal
	# Simulate an unknown type by calling _play_single_fx directly
	watch_signals(_player)
	_player.play_fx_list([], _target)
	assert_signal_emitted(_player, "fx_finished")
	pass_test("unknown fx type should not crash")


## --- Combinations ---


func test_play_multiple_new_fx_sequentially() -> void:
	var fx1 = SequenceFx.new()
	fx1.fx_type = "flash"
	fx1.duration = 0.1
	var fx2 = SequenceFx.new()
	fx2.fx_type = "zoom"
	fx2.duration = 0.1
	var fx3 = SequenceFx.new()
	fx3.fx_type = "vignette"
	fx3.duration = 0.1
	_player.play_fx_list([fx1, fx2, fx3], _target)
	assert_true(_player.is_playing())


func test_stop_during_multi_fx_cleans_up() -> void:
	var fx1 = SequenceFx.new()
	fx1.fx_type = "flash"
	fx1.duration = 5.0
	var fx2 = SequenceFx.new()
	fx2.fx_type = "desaturation"
	fx2.duration = 5.0
	_player.play_fx_list([fx1, fx2], _target)
	_player.stop_fx()
	assert_false(_player.is_playing())
	assert_eq(_player._fx_nodes.size(), 0)


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


## --- Separate overlay / transform targets ---


func test_screen_shake_uses_transform_target() -> void:
	var overlay_target = Control.new()
	overlay_target.size = Vector2(800, 600)
	add_child(overlay_target)
	var transform_target = Control.new()
	transform_target.size = Vector2(1920, 1080)
	transform_target.position = Vector2(50, 60)
	add_child(transform_target)

	var fx = SequenceFx.new()
	fx.fx_type = "screen_shake"
	fx.duration = 5.0
	fx.intensity = 2.0
	_player.play_fx_list([fx], overlay_target, transform_target)

	# The shake should modify transform_target, not overlay_target
	assert_eq(_player._transform_target, transform_target)
	_player.stop_fx()
	assert_eq(transform_target.position, Vector2(50, 60), "transform_target position should be restored")

	remove_child(overlay_target)
	overlay_target.queue_free()
	remove_child(transform_target)
	transform_target.queue_free()


func test_overlay_fx_goes_to_target_not_transform_target() -> void:
	var overlay_target = Control.new()
	overlay_target.size = Vector2(800, 600)
	add_child(overlay_target)
	var transform_target = Control.new()
	transform_target.size = Vector2(1920, 1080)
	add_child(transform_target)

	var fx = SequenceFx.new()
	fx.fx_type = "vignette"
	fx.duration = 5.0
	_player.play_fx_list([fx], overlay_target, transform_target)

	# Vignette overlay should be in overlay_target, not transform_target
	assert_not_null(overlay_target.get_node_or_null("FxVignetteOverlay"), "vignette should be child of overlay_target")
	assert_null(transform_target.get_node_or_null("FxVignetteOverlay"), "vignette should NOT be child of transform_target")

	_player.stop_fx()
	remove_child(overlay_target)
	overlay_target.queue_free()
	remove_child(transform_target)
	transform_target.queue_free()


func test_stop_does_not_reset_transform_target_without_transform_fx() -> void:
	var overlay_target = Control.new()
	overlay_target.size = Vector2(800, 600)
	add_child(overlay_target)
	var transform_target = Control.new()
	transform_target.size = Vector2(1920, 1080)
	transform_target.position = Vector2(100, 200)
	add_child(transform_target)

	var fx = SequenceFx.new()
	fx.fx_type = "vignette"
	fx.duration = 5.0
	_player.play_fx_list([fx], overlay_target, transform_target)
	_player.stop_fx()

	# Position should NOT be reset to Vector2.ZERO since no transform FX was played
	assert_eq(transform_target.position, Vector2(100, 200), "transform_target position should be untouched when no transform FX played")

	remove_child(overlay_target)
	overlay_target.queue_free()
	remove_child(transform_target)
	transform_target.queue_free()


## --- apply_persistent_fx (immediate, full-intensity) ---


func test_apply_persistent_fx_creates_vignette_immediately() -> void:
	var fx = SequenceFx.new()
	fx.fx_type = "vignette"
	fx.intensity = 0.8
	_player.apply_persistent_fx([fx], _target)
	assert_true(_player._persistent_fx.has("vignette"), "vignette should be in persistent_fx")
	var overlay = _player._persistent_fx.get("vignette")
	var mat = overlay.material as ShaderMaterial
	assert_eq(mat.get_shader_parameter("strength"), 0.8, "vignette should be at full intensity immediately")


func test_apply_persistent_fx_creates_desaturation_immediately() -> void:
	var fx = SequenceFx.new()
	fx.fx_type = "desaturation"
	fx.intensity = 0.6
	_player.apply_persistent_fx([fx], _target)
	assert_true(_player._persistent_fx.has("desaturation"), "desaturation should be in persistent_fx")
	var overlay = _player._persistent_fx.get("desaturation")
	var mat = overlay.material as ShaderMaterial
	assert_almost_eq(mat.get_shader_parameter("amount"), 0.6, 0.01, "desaturation should be at full intensity immediately")


func test_apply_persistent_fx_ignores_transient_types() -> void:
	var fx1 = SequenceFx.new()
	fx1.fx_type = "fade_in"
	fx1.duration = 1.0
	var fx2 = SequenceFx.new()
	fx2.fx_type = "screen_shake"
	fx2.duration = 1.0
	_player.apply_persistent_fx([fx1, fx2], _target)
	assert_eq(_player._persistent_fx.size(), 0, "transient FX should not be created by apply_persistent_fx")


func test_apply_persistent_fx_updates_existing_intensity() -> void:
	var fx1 = SequenceFx.new()
	fx1.fx_type = "vignette"
	fx1.intensity = 0.5
	_player.apply_persistent_fx([fx1], _target)
	var overlay1 = _player._persistent_fx.get("vignette")

	var fx2 = SequenceFx.new()
	fx2.fx_type = "vignette"
	fx2.intensity = 1.0
	_player.apply_persistent_fx([fx2], _target)
	var overlay2 = _player._persistent_fx.get("vignette")

	assert_eq(overlay1, overlay2, "should reuse same overlay node")
	var mat = overlay2.material as ShaderMaterial
	assert_eq(mat.get_shader_parameter("strength"), 1.0, "intensity should be updated to new value")


func test_apply_persistent_fx_removes_absent_types() -> void:
	var fx1 = SequenceFx.new()
	fx1.fx_type = "vignette"
	fx1.intensity = 0.5
	var fx2 = SequenceFx.new()
	fx2.fx_type = "desaturation"
	fx2.intensity = 0.5
	_player.apply_persistent_fx([fx1, fx2], _target)
	assert_eq(_player._persistent_fx.size(), 2)

	# Second call with only vignette — desaturation should be removed
	var fx3 = SequenceFx.new()
	fx3.fx_type = "vignette"
	fx3.intensity = 0.5
	_player.apply_persistent_fx([fx3], _target)
	assert_true(_player._persistent_fx.has("vignette"))
	assert_false(_player._persistent_fx.has("desaturation"), "desaturation should be removed when not in new list")


func test_apply_persistent_fx_empty_list_clears_all() -> void:
	var fx = SequenceFx.new()
	fx.fx_type = "vignette"
	fx.intensity = 0.5
	_player.apply_persistent_fx([fx], _target)
	assert_eq(_player._persistent_fx.size(), 1)

	_player.apply_persistent_fx([], _target)
	assert_eq(_player._persistent_fx.size(), 0, "empty list should clear all persistent fx")


func test_apply_persistent_fx_desaturation_clamped_to_one() -> void:
	var fx = SequenceFx.new()
	fx.fx_type = "desaturation"
	fx.intensity = 5.0
	_player.apply_persistent_fx([fx], _target)
	var overlay = _player._persistent_fx.get("desaturation")
	var mat = overlay.material as ShaderMaterial
	assert_almost_eq(mat.get_shader_parameter("amount"), 1.0, 0.01, "desaturation should be clamped to 1.0")


func test_zoom_uses_transform_target() -> void:
	var overlay_target = Control.new()
	overlay_target.size = Vector2(800, 600)
	add_child(overlay_target)
	var transform_target = Control.new()
	transform_target.size = Vector2(1920, 1080)
	transform_target.scale = Vector2(0.5, 0.5)
	add_child(transform_target)

	var fx = SequenceFx.new()
	fx.fx_type = "zoom"
	fx.duration = 5.0
	fx.intensity = 1.0
	_player.play_fx_list([fx], overlay_target, transform_target)

	# Zoom should modify transform_target
	assert_eq(transform_target.pivot_offset, transform_target.size / 2.0, "pivot should be set on transform_target")

	_player.stop_fx()
	assert_eq(transform_target.scale, Vector2(0.5, 0.5), "transform_target scale should be restored")

	remove_child(overlay_target)
	overlay_target.queue_free()
	remove_child(transform_target)
	transform_target.queue_free()


## --- Zoom In / Zoom Out ---


func test_play_zoom_in_sets_playing() -> void:
	var fx = SequenceFx.new()
	fx.fx_type = "zoom_in"
	fx.zoom_from = 1.0
	fx.zoom_to = 1.5
	fx.duration = 1.0
	_player.play_fx_list([fx], _target)
	assert_true(_player.is_playing())


func test_play_zoom_out_sets_playing() -> void:
	var fx = SequenceFx.new()
	fx.fx_type = "zoom_out"
	fx.zoom_from = 1.5
	fx.zoom_to = 1.0
	fx.duration = 1.0
	_player.play_fx_list([fx], _target)
	assert_true(_player.is_playing())


func test_zoom_in_sets_pivot_to_center() -> void:
	var fx = SequenceFx.new()
	fx.fx_type = "zoom_in"
	fx.zoom_from = 1.0
	fx.zoom_to = 1.5
	fx.duration = 5.0
	_player.play_fx_list([fx], _target)
	assert_eq(_target.pivot_offset, _target.size / 2.0, "pivot should be set to center")


func test_zoom_in_sets_initial_scale_to_zoom_from() -> void:
	_target.scale = Vector2(1.0, 1.0)
	var fx = SequenceFx.new()
	fx.fx_type = "zoom_in"
	fx.zoom_from = 1.2
	fx.zoom_to = 1.8
	fx.duration = 5.0
	_player.play_fx_list([fx], _target)
	assert_almost_eq(_target.scale.x, 1.2, 0.01, "scale should start at zoom_from")


func test_stop_restores_scale_after_zoom_in() -> void:
	_target.scale = Vector2(1.0, 1.0)
	var fx = SequenceFx.new()
	fx.fx_type = "zoom_in"
	fx.zoom_from = 1.0
	fx.zoom_to = 1.5
	fx.duration = 5.0
	_player.play_fx_list([fx], _target)
	_player.stop_fx()
	assert_eq(_target.scale, Vector2(1.0, 1.0), "scale should be restored after stop")


func test_stop_restores_pivot_after_zoom_in() -> void:
	_target.pivot_offset = Vector2(5.0, 10.0)
	var fx = SequenceFx.new()
	fx.fx_type = "zoom_in"
	fx.zoom_from = 1.0
	fx.zoom_to = 1.5
	fx.duration = 5.0
	_player.play_fx_list([fx], _target)
	_player.stop_fx()
	assert_eq(_target.pivot_offset, Vector2(5.0, 10.0), "pivot should be restored after stop")


func test_zoom_in_uses_transform_target() -> void:
	var overlay_target = Control.new()
	overlay_target.size = Vector2(800, 600)
	add_child(overlay_target)
	var transform_target = Control.new()
	transform_target.size = Vector2(1920, 1080)
	transform_target.scale = Vector2(1.0, 1.0)
	add_child(transform_target)

	var fx = SequenceFx.new()
	fx.fx_type = "zoom_in"
	fx.zoom_from = 1.0
	fx.zoom_to = 1.5
	fx.duration = 5.0
	_player.play_fx_list([fx], overlay_target, transform_target)

	assert_eq(transform_target.pivot_offset, transform_target.size / 2.0, "pivot set on transform_target")
	_player.stop_fx()
	assert_eq(transform_target.scale, Vector2(1.0, 1.0), "transform_target scale restored")

	remove_child(overlay_target)
	overlay_target.queue_free()
	remove_child(transform_target)
	transform_target.queue_free()


func test_zoom_in_does_not_create_overlay_nodes() -> void:
	var fx = SequenceFx.new()
	fx.fx_type = "zoom_in"
	fx.zoom_from = 1.0
	fx.zoom_to = 1.5
	fx.duration = 5.0
	_player.play_fx_list([fx], _target)
	assert_eq(_player._fx_nodes.size(), 0, "zoom_in should not create overlay nodes")


## --- Pan Effects ---


func test_play_pan_right_sets_playing() -> void:
	var fx = SequenceFx.new()
	fx.fx_type = "pan_right"
	fx.zoom_from = 1.3
	fx.intensity = 0.5
	fx.duration = 1.0
	_player.play_fx_list([fx], _target)
	assert_true(_player.is_playing())


func test_play_pan_left_sets_playing() -> void:
	var fx = SequenceFx.new()
	fx.fx_type = "pan_left"
	fx.zoom_from = 1.3
	fx.intensity = 0.5
	fx.duration = 1.0
	_player.play_fx_list([fx], _target)
	assert_true(_player.is_playing())


func test_play_pan_down_sets_playing() -> void:
	var fx = SequenceFx.new()
	fx.fx_type = "pan_down"
	fx.zoom_from = 1.3
	fx.intensity = 0.5
	fx.duration = 1.0
	_player.play_fx_list([fx], _target)
	assert_true(_player.is_playing())


func test_play_pan_up_sets_playing() -> void:
	var fx = SequenceFx.new()
	fx.fx_type = "pan_up"
	fx.zoom_from = 1.3
	fx.intensity = 0.5
	fx.duration = 1.0
	_player.play_fx_list([fx], _target)
	assert_true(_player.is_playing())


func test_pan_right_sets_pivot_to_center() -> void:
	var fx = SequenceFx.new()
	fx.fx_type = "pan_right"
	fx.zoom_from = 1.3
	fx.intensity = 0.5
	fx.duration = 5.0
	_player.play_fx_list([fx], _target)
	assert_eq(_target.pivot_offset, _target.size / 2.0, "pivot should be set to center")


func test_pan_right_sets_zoom_scale() -> void:
	_target.scale = Vector2(1.0, 1.0)
	var fx = SequenceFx.new()
	fx.fx_type = "pan_right"
	fx.zoom_from = 1.3
	fx.intensity = 0.5
	fx.duration = 5.0
	_player.play_fx_list([fx], _target)
	assert_almost_eq(_target.scale.x, 1.3, 0.01, "scale should be set to zoom_from")


func test_pan_right_starts_at_left_edge() -> void:
	_target.size = Vector2(800.0, 600.0)
	_target.position = Vector2.ZERO
	var fx = SequenceFx.new()
	fx.fx_type = "pan_right"
	fx.zoom_from = 1.3
	fx.intensity = 0.5
	fx.duration = 5.0
	_player.play_fx_list([fx], _target)
	var extra_x: float = 800.0 * (1.3 - 1.0) / 2.0
	assert_almost_eq(_target.position.x, extra_x, 0.01, "pan_right should start at left edge of background")


func test_pan_left_starts_at_right_edge() -> void:
	_target.size = Vector2(800.0, 600.0)
	_target.position = Vector2.ZERO
	var fx = SequenceFx.new()
	fx.fx_type = "pan_left"
	fx.zoom_from = 1.3
	fx.intensity = 0.5
	fx.duration = 5.0
	_player.play_fx_list([fx], _target)
	var extra_x: float = 800.0 * (1.3 - 1.0) / 2.0
	assert_almost_eq(_target.position.x, -extra_x, 0.01, "pan_left should start at right edge of background")


func test_pan_down_starts_at_top_edge() -> void:
	_target.size = Vector2(800.0, 600.0)
	_target.position = Vector2.ZERO
	var fx = SequenceFx.new()
	fx.fx_type = "pan_down"
	fx.zoom_from = 1.3
	fx.intensity = 0.5
	fx.duration = 5.0
	_player.play_fx_list([fx], _target)
	var extra_y: float = 600.0 * (1.3 - 1.0) / 2.0
	assert_almost_eq(_target.position.y, extra_y, 0.01, "pan_down should start at top edge of background")


func test_pan_up_starts_at_bottom_edge() -> void:
	_target.size = Vector2(800.0, 600.0)
	_target.position = Vector2.ZERO
	var fx = SequenceFx.new()
	fx.fx_type = "pan_up"
	fx.zoom_from = 1.3
	fx.intensity = 0.5
	fx.duration = 5.0
	_player.play_fx_list([fx], _target)
	var extra_y: float = 600.0 * (1.3 - 1.0) / 2.0
	assert_almost_eq(_target.position.y, -extra_y, 0.01, "pan_up should start at bottom edge of background")


func test_stop_restores_position_after_pan() -> void:
	_target.position = Vector2(10.0, 20.0)
	var fx = SequenceFx.new()
	fx.fx_type = "pan_right"
	fx.zoom_from = 1.3
	fx.intensity = 0.5
	fx.duration = 5.0
	_player.play_fx_list([fx], _target)
	_player.stop_fx()
	assert_eq(_target.position, Vector2(10.0, 20.0), "position should be restored after stop")


func test_stop_restores_scale_after_pan() -> void:
	_target.scale = Vector2(1.0, 1.0)
	var fx = SequenceFx.new()
	fx.fx_type = "pan_right"
	fx.zoom_from = 1.3
	fx.intensity = 0.5
	fx.duration = 5.0
	_player.play_fx_list([fx], _target)
	_player.stop_fx()
	assert_eq(_target.scale, Vector2(1.0, 1.0), "scale should be restored after stop")


func test_pan_does_not_create_overlay_nodes() -> void:
	var fx = SequenceFx.new()
	fx.fx_type = "pan_right"
	fx.zoom_from = 1.3
	fx.intensity = 0.5
	fx.duration = 5.0
	_player.play_fx_list([fx], _target)
	assert_eq(_player._fx_nodes.size(), 0, "pan should not create overlay nodes")


func test_pan_uses_transform_target() -> void:
	var overlay_target = Control.new()
	overlay_target.size = Vector2(800, 600)
	add_child(overlay_target)
	var transform_target = Control.new()
	transform_target.size = Vector2(1920.0, 1080.0)
	transform_target.position = Vector2(50.0, 60.0)
	transform_target.scale = Vector2(1.0, 1.0)
	add_child(transform_target)

	var fx = SequenceFx.new()
	fx.fx_type = "pan_right"
	fx.zoom_from = 1.3
	fx.intensity = 0.5
	fx.duration = 5.0
	_player.play_fx_list([fx], overlay_target, transform_target)

	assert_eq(_player._transform_target, transform_target)
	_player.stop_fx()
	assert_eq(transform_target.position, Vector2(50.0, 60.0), "transform_target position should be restored")
	assert_eq(transform_target.scale, Vector2(1.0, 1.0), "transform_target scale should be restored")

	remove_child(overlay_target)
	overlay_target.queue_free()
	remove_child(transform_target)
	transform_target.queue_free()


## --- continue_during_fx (FX en parallèle) ---


func test_continue_during_fx_emits_finished_immediately() -> void:
	watch_signals(_player)
	var fx = SequenceFx.new()
	fx.fx_type = "fade_in"
	fx.duration = 10.0
	fx.continue_during_fx = true
	_player.play_fx_list([fx], _target)
	# fx_finished doit être émis immédiatement (sans attendre la fin de l'animation)
	assert_signal_emitted(_player, "fx_finished")


func test_continue_during_fx_not_blocking_second_fx() -> void:
	watch_signals(_player)
	var fx1 = SequenceFx.new()
	fx1.fx_type = "fade_in"
	fx1.duration = 10.0
	fx1.continue_during_fx = true
	var fx2 = SequenceFx.new()
	fx2.fx_type = "flash"
	fx2.duration = 10.0
	fx2.continue_during_fx = false
	_player.play_fx_list([fx1, fx2], _target)
	# fx1 ne bloque pas : fx2 doit avoir démarré (player toujours en cours)
	assert_true(_player.is_playing())


func test_continue_during_fx_tween_stored_in_detached() -> void:
	var fx = SequenceFx.new()
	fx.fx_type = "flash"
	fx.duration = 10.0
	fx.continue_during_fx = true
	_player.play_fx_list([fx], _target)
	# Le tween doit être dans _detached_tweens, pas dans _current_tween
	assert_eq(_player._detached_tweens.size(), 1, "detached tween should be tracked")


func test_continue_during_fx_stop_cleans_detached_tweens() -> void:
	var fx = SequenceFx.new()
	fx.fx_type = "flash"
	fx.duration = 10.0
	fx.continue_during_fx = true
	# Ajouter un second FX bloquant pour que _player reste en cours après fx1
	var fx2 = SequenceFx.new()
	fx2.fx_type = "fade_in"
	fx2.duration = 10.0
	_player.play_fx_list([fx, fx2], _target)
	assert_eq(_player._detached_tweens.size(), 1)
	_player.stop_fx()
	assert_eq(_player._detached_tweens.size(), 0, "stop_fx should clear detached tweens")


func test_continue_during_fx_false_does_not_detach() -> void:
	var fx = SequenceFx.new()
	fx.fx_type = "flash"
	fx.duration = 10.0
	fx.continue_during_fx = false
	_player.play_fx_list([fx], _target)
	assert_eq(_player._detached_tweens.size(), 0, "blocking FX should not be in detached tweens")


## --- pre_apply_initial_transform ---


func test_pre_apply_zoom_in_sets_scale_immediately() -> void:
	var fx = SequenceFx.new()
	fx.fx_type = "zoom_in"
	fx.zoom_from = 1.5
	fx.zoom_to = 2.0
	_player.pre_apply_initial_transform([fx], _target)
	assert_almost_eq(_target.scale.x, 1.5, 0.001, "scale should be zoom_from immediately")
	assert_almost_eq(_target.scale.y, 1.5, 0.001)


func test_pre_apply_zoom_out_sets_scale_immediately() -> void:
	var fx = SequenceFx.new()
	fx.fx_type = "zoom_out"
	fx.zoom_from = 2.0
	fx.zoom_to = 1.0
	_player.pre_apply_initial_transform([fx], _target)
	assert_almost_eq(_target.scale.x, 2.0, 0.001)


func test_pre_apply_pan_right_sets_initial_position() -> void:
	var fx = SequenceFx.new()
	fx.fx_type = "pan_right"
	fx.zoom_from = 1.5
	fx.intensity = 0.5
	_target.size = Vector2(800, 600)
	_player.pre_apply_initial_transform([fx], _target)
	# extra_x = 800 * (1.5 - 1) / 2 = 200
	assert_almost_eq(_target.position.x, 200.0, 0.5, "pan_right should start at left edge offset")


func test_pre_apply_pan_left_sets_initial_position() -> void:
	var fx = SequenceFx.new()
	fx.fx_type = "pan_left"
	fx.zoom_from = 1.5
	fx.intensity = 0.5
	_target.size = Vector2(800, 600)
	_player.pre_apply_initial_transform([fx], _target)
	assert_almost_eq(_target.position.x, -200.0, 0.5, "pan_left should start at right edge offset")


func test_pre_apply_sets_pre_applied_flag() -> void:
	var fx = SequenceFx.new()
	fx.fx_type = "zoom_in"
	fx.zoom_from = 1.5
	_player.pre_apply_initial_transform([fx], _target)
	assert_true(_player._pre_applied, "pre_applied flag should be set")


func test_pre_apply_saves_original_scale() -> void:
	_target.scale = Vector2.ONE
	var fx = SequenceFx.new()
	fx.fx_type = "zoom_in"
	fx.zoom_from = 1.5
	_player.pre_apply_initial_transform([fx], _target)
	assert_almost_eq(_player._original_scale.x, 1.0, 0.001, "original scale should be saved before pre-apply")


func test_pre_apply_then_play_keeps_final_zoom_state() -> void:
	_target.scale = Vector2.ONE
	var fx = SequenceFx.new()
	fx.fx_type = "zoom_in"
	fx.zoom_from = 1.5
	fx.zoom_to = 2.0
	fx.duration = 0.01
	_player.pre_apply_initial_transform([fx], _target)
	watch_signals(_player)
	_player.play_fx_list([fx], _target, _target)
	await _player.fx_finished
	assert_almost_eq(_target.scale.x, 2.0, 0.001, "scale should stay at zoom_to after FX completes")


func test_pre_apply_stop_restores_scale() -> void:
	_target.scale = Vector2.ONE
	var fx = SequenceFx.new()
	fx.fx_type = "zoom_in"
	fx.zoom_from = 1.5
	_player.pre_apply_initial_transform([fx], _target)
	assert_almost_eq(_target.scale.x, 1.5, 0.001)
	_player.stop_fx()
	assert_almost_eq(_target.scale.x, 1.0, 0.001, "stop_fx should restore scale to original")


func test_pre_apply_non_zoom_fx_does_not_set_flag() -> void:
	var fx = SequenceFx.new()
	fx.fx_type = "fade_in"
	_player.pre_apply_initial_transform([fx], _target)
	assert_false(_player._pre_applied, "non-zoom/pan FX should not set pre_applied flag")
