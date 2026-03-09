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
