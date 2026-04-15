# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends GutTest

const ApngBuilderScript = preload("res://src/services/apng_builder.gd")

func _make_frame(w: int = 8, h: int = 8, color: Color = Color.RED) -> Image:
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return img

func test_build_returns_non_empty_bytes():
	var frames = [_make_frame(), _make_frame(8, 8, Color.BLUE)]
	var result = ApngBuilderScript.build(frames, 8)
	assert_gt(result.size(), 0)

func test_build_starts_with_png_signature():
	var result = ApngBuilderScript.build([_make_frame()], 8)
	assert_gte(result.size(), 8)
	assert_eq(result[0], 0x89)
	assert_eq(result[1], 0x50)  # P
	assert_eq(result[2], 0x4E)  # N
	assert_eq(result[3], 0x47)  # G
	assert_eq(result[4], 0x0D)
	assert_eq(result[5], 0x0A)
	assert_eq(result[6], 0x1A)
	assert_eq(result[7], 0x0A)

func test_build_contains_actl_chunk():
	var result = ApngBuilderScript.build([_make_frame(), _make_frame()], 8)
	var found = false
	for i in range(result.size() - 3):
		if result[i] == 0x61 and result[i+1] == 0x63 and result[i+2] == 0x54 and result[i+3] == 0x4C:
			found = true
			break
	assert_true(found, "acTL chunk non trouvé dans l'APNG")

func test_build_single_frame_produces_valid_png():
	var frame = _make_frame(16, 16, Color.GREEN)
	var result = ApngBuilderScript.build([frame], 24, 1)
	var img = Image.new()
	var err = img.load_png_from_buffer(result)
	assert_eq(err, OK, "L'APNG 1 frame doit être lisible comme PNG standard")
	assert_eq(img.get_width(), 16)
	assert_eq(img.get_height(), 16)

func test_build_empty_frames_returns_empty():
	var result = ApngBuilderScript.build([], 8)
	assert_eq(result.size(), 0)

func test_build_zero_fps_returns_empty():
	var result = ApngBuilderScript.build([_make_frame()], 0)
	assert_eq(result.size(), 0)
