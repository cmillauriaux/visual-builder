extends GutTest

const SequenceFx = preload("res://src/models/sequence_fx.gd")


func test_default_values():
	var fx = SequenceFx.new()
	assert_ne(fx.uuid, "", "UUID doit être généré automatiquement")
	assert_eq(fx.fx_type, "fade_in")
	assert_eq(fx.duration, 0.5)
	assert_eq(fx.intensity, 1.0)


func test_uuid_is_unique():
	var fx1 = SequenceFx.new()
	var fx2 = SequenceFx.new()
	assert_ne(fx1.uuid, fx2.uuid)


func test_fx_type_valid_values():
	var fx = SequenceFx.new()
	for t in SequenceFx.VALID_FX_TYPES:
		fx.fx_type = t
		assert_eq(fx.fx_type, t)


func test_fx_type_invalid_falls_back_to_default():
	var fx = SequenceFx.new()
	fx.fx_type = "invalid_type"
	assert_eq(fx.fx_type, "fade_in")


func test_fx_type_screen_shake():
	var fx = SequenceFx.new()
	fx.fx_type = "screen_shake"
	assert_eq(fx.fx_type, "screen_shake")


func test_fx_type_eyes_blink():
	var fx = SequenceFx.new()
	fx.fx_type = "eyes_blink"
	assert_eq(fx.fx_type, "eyes_blink")


func test_fx_type_flash():
	var fx = SequenceFx.new()
	fx.fx_type = "flash"
	assert_eq(fx.fx_type, "flash")


func test_fx_type_zoom():
	var fx = SequenceFx.new()
	fx.fx_type = "zoom"
	assert_eq(fx.fx_type, "zoom")


func test_fx_type_vignette():
	var fx = SequenceFx.new()
	fx.fx_type = "vignette"
	assert_eq(fx.fx_type, "vignette")


func test_fx_type_desaturation():
	var fx = SequenceFx.new()
	fx.fx_type = "desaturation"
	assert_eq(fx.fx_type, "desaturation")


func test_duration_clamped_min():
	var fx = SequenceFx.new()
	fx.duration = 0.01
	assert_eq(fx.duration, 0.1)


func test_duration_clamped_max():
	var fx = SequenceFx.new()
	fx.duration = 10.0
	assert_eq(fx.duration, 5.0)


func test_duration_valid_value():
	var fx = SequenceFx.new()
	fx.duration = 2.0
	assert_eq(fx.duration, 2.0)


func test_intensity_clamped_min():
	var fx = SequenceFx.new()
	fx.intensity = 0.0
	assert_eq(fx.intensity, 0.1)


func test_intensity_clamped_max():
	var fx = SequenceFx.new()
	fx.intensity = 5.0
	assert_eq(fx.intensity, 3.0)


func test_intensity_valid_value():
	var fx = SequenceFx.new()
	fx.intensity = 1.5
	assert_eq(fx.intensity, 1.5)


func test_color_default():
	var fx = SequenceFx.new()
	assert_eq(fx.color, Color.WHITE)


func test_color_set():
	var fx = SequenceFx.new()
	fx.color = Color.RED
	assert_eq(fx.color, Color.RED)


func test_to_dict():
	var fx = SequenceFx.new()
	fx.uuid = "fx-001"
	fx.fx_type = "screen_shake"
	fx.duration = 1.0
	fx.intensity = 2.0
	var dict = fx.to_dict()
	assert_eq(dict["uuid"], "fx-001")
	assert_eq(dict["fx_type"], "screen_shake")
	assert_eq(dict["duration"], 1.0)
	assert_eq(dict["intensity"], 2.0)


func test_to_dict_includes_color():
	var fx = SequenceFx.new()
	fx.color = Color.RED
	var dict = fx.to_dict()
	assert_eq(dict["color"], Color.RED.to_html())


func test_from_dict():
	var dict = {
		"uuid": "fx-002",
		"fx_type": "eyes_blink",
		"duration": 1.5,
		"intensity": 0.5,
	}
	var fx = SequenceFx.from_dict(dict)
	assert_eq(fx.uuid, "fx-002")
	assert_eq(fx.fx_type, "eyes_blink")
	assert_eq(fx.duration, 1.5)
	assert_eq(fx.intensity, 0.5)


func test_from_dict_with_color():
	var dict = {
		"uuid": "fx-003",
		"fx_type": "flash",
		"duration": 0.5,
		"intensity": 1.0,
		"color": Color.YELLOW.to_html(),
	}
	var fx = SequenceFx.from_dict(dict)
	assert_eq(fx.color, Color.YELLOW)


func test_from_dict_defaults():
	var dict = {}
	var fx = SequenceFx.from_dict(dict)
	assert_eq(fx.fx_type, "fade_in")
	assert_eq(fx.duration, 0.5)
	assert_eq(fx.intensity, 1.0)


func test_from_dict_without_color_defaults_to_white():
	var dict = {"fx_type": "flash"}
	var fx = SequenceFx.from_dict(dict)
	assert_eq(fx.color, Color.WHITE)


func test_from_dict_invalid_type_falls_back():
	var dict = {"fx_type": "nonexistent"}
	var fx = SequenceFx.from_dict(dict)
	assert_eq(fx.fx_type, "fade_in")


func test_roundtrip():
	var fx = SequenceFx.new()
	fx.fx_type = "screen_shake"
	fx.duration = 2.5
	fx.intensity = 1.8
	var dict = fx.to_dict()
	var restored = SequenceFx.from_dict(dict)
	assert_eq(restored.uuid, fx.uuid)
	assert_eq(restored.fx_type, fx.fx_type)
	assert_eq(restored.duration, fx.duration)
	assert_eq(restored.intensity, fx.intensity)


## --- Nouveaux types zoom_in, zoom_out, pan_* ---


func test_fx_type_zoom_in():
	var fx = SequenceFx.new()
	fx.fx_type = "zoom_in"
	assert_eq(fx.fx_type, "zoom_in")


func test_fx_type_zoom_out():
	var fx = SequenceFx.new()
	fx.fx_type = "zoom_out"
	assert_eq(fx.fx_type, "zoom_out")


func test_fx_type_pan_right():
	var fx = SequenceFx.new()
	fx.fx_type = "pan_right"
	assert_eq(fx.fx_type, "pan_right")


func test_fx_type_pan_left():
	var fx = SequenceFx.new()
	fx.fx_type = "pan_left"
	assert_eq(fx.fx_type, "pan_left")


func test_fx_type_pan_down():
	var fx = SequenceFx.new()
	fx.fx_type = "pan_down"
	assert_eq(fx.fx_type, "pan_down")


func test_fx_type_pan_up():
	var fx = SequenceFx.new()
	fx.fx_type = "pan_up"
	assert_eq(fx.fx_type, "pan_up")


## --- zoom_from / zoom_to ---


func test_zoom_from_default():
	var fx = SequenceFx.new()
	assert_eq(fx.zoom_from, 1.0)


func test_zoom_to_default():
	var fx = SequenceFx.new()
	assert_eq(fx.zoom_to, 1.5)


func test_zoom_from_clamped_below_one():
	var fx = SequenceFx.new()
	fx.zoom_from = 0.5
	assert_eq(fx.zoom_from, 1.0)


func test_zoom_to_clamped_below_one():
	var fx = SequenceFx.new()
	fx.zoom_to = 0.0
	assert_eq(fx.zoom_to, 1.0)


func test_zoom_from_valid_value():
	var fx = SequenceFx.new()
	fx.zoom_from = 1.8
	assert_almost_eq(fx.zoom_from, 1.8, 0.001)


func test_zoom_to_valid_value():
	var fx = SequenceFx.new()
	fx.zoom_to = 2.5
	assert_almost_eq(fx.zoom_to, 2.5, 0.001)


func test_to_dict_includes_zoom_from_and_zoom_to():
	var fx = SequenceFx.new()
	fx.zoom_from = 1.2
	fx.zoom_to = 2.0
	var dict = fx.to_dict()
	assert_almost_eq(dict["zoom_from"], 1.2, 0.001)
	assert_almost_eq(dict["zoom_to"], 2.0, 0.001)


func test_from_dict_restores_zoom_from_and_zoom_to():
	var dict = {
		"fx_type": "zoom_in",
		"duration": 1.0,
		"intensity": 1.0,
		"zoom_from": 1.0,
		"zoom_to": 1.5,
	}
	var fx = SequenceFx.from_dict(dict)
	assert_almost_eq(fx.zoom_from, 1.0, 0.001)
	assert_almost_eq(fx.zoom_to, 1.5, 0.001)


func test_from_dict_zoom_from_defaults_to_one():
	var dict = {"fx_type": "zoom_in"}
	var fx = SequenceFx.from_dict(dict)
	assert_almost_eq(fx.zoom_from, 1.0, 0.001)


func test_from_dict_zoom_to_defaults_to_one_point_five():
	var dict = {"fx_type": "zoom_in"}
	var fx = SequenceFx.from_dict(dict)
	assert_almost_eq(fx.zoom_to, 1.5, 0.001)


func test_roundtrip_zoom_in():
	var fx = SequenceFx.new()
	fx.fx_type = "zoom_in"
	fx.zoom_from = 1.0
	fx.zoom_to = 2.0
	fx.duration = 1.5
	var dict = fx.to_dict()
	var restored = SequenceFx.from_dict(dict)
	assert_eq(restored.fx_type, "zoom_in")
	assert_almost_eq(restored.zoom_from, 1.0, 0.001)
	assert_almost_eq(restored.zoom_to, 2.0, 0.001)


func test_roundtrip_pan_right():
	var fx = SequenceFx.new()
	fx.fx_type = "pan_right"
	fx.zoom_from = 1.3
	fx.intensity = 0.5
	fx.duration = 2.0
	var dict = fx.to_dict()
	var restored = SequenceFx.from_dict(dict)
	assert_eq(restored.fx_type, "pan_right")
	assert_almost_eq(restored.zoom_from, 1.3, 0.001)
	assert_almost_eq(restored.intensity, 0.5, 0.001)


## --- continue_during_fx ---


func test_continue_during_fx_default_false():
	var fx = SequenceFx.new()
	assert_false(fx.continue_during_fx)


func test_continue_during_fx_set_true():
	var fx = SequenceFx.new()
	fx.continue_during_fx = true
	assert_true(fx.continue_during_fx)


func test_to_dict_includes_continue_during_fx():
	var fx = SequenceFx.new()
	fx.continue_during_fx = true
	var dict = fx.to_dict()
	assert_true(dict.has("continue_during_fx"))
	assert_true(dict["continue_during_fx"])


func test_from_dict_restores_continue_during_fx():
	var dict = {"fx_type": "fade_in", "continue_during_fx": true}
	var fx = SequenceFx.from_dict(dict)
	assert_true(fx.continue_during_fx)


func test_from_dict_continue_during_fx_defaults_to_false():
	var dict = {"fx_type": "fade_in"}
	var fx = SequenceFx.from_dict(dict)
	assert_false(fx.continue_during_fx)


func test_roundtrip_continue_during_fx():
	var fx = SequenceFx.new()
	fx.fx_type = "zoom_in"
	fx.continue_during_fx = true
	var dict = fx.to_dict()
	var restored = SequenceFx.from_dict(dict)
	assert_true(restored.continue_during_fx)
