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


func test_from_dict_defaults():
	var dict = {}
	var fx = SequenceFx.from_dict(dict)
	assert_eq(fx.fx_type, "fade_in")
	assert_eq(fx.duration, 0.5)
	assert_eq(fx.intensity, 1.0)


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
