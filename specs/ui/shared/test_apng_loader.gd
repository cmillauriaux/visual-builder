# SPDX-License-Identifier: AGPL-3.0-only
extends GutTest

const ApngLoader = preload("res://src/ui/shared/apng_loader.gd")

# PNG 1x1 blanc encodé en base64 (format valide, pas d'APNG)
const MINIMAL_PNG_B64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII="

func test_empty_buffer_returns_empty():
	var result = ApngLoader.load_from_buffer(PackedByteArray())
	assert_eq(result, {})

func test_invalid_signature_returns_empty():
	var result = ApngLoader.load_from_buffer(PackedByteArray([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]))
	assert_eq(result, {})

func test_valid_png_returns_one_frame():
	var data = Marshalls.base64_to_raw(MINIMAL_PNG_B64)
	var result = ApngLoader.load_from_buffer(data)
	assert_true(result.has("frames"), "doit avoir 'frames'")
	assert_true(result.has("delays"), "doit avoir 'delays'")
	assert_eq((result["frames"] as Array).size(), 1, "PNG sans acTL → 1 frame")
	assert_eq((result["delays"] as Array).size(), 1)
	assert_almost_eq(result["delays"][0] as float, 1.0 / 12.0, 0.001, "délai par défaut")

func test_read_uint32_be():
	var data = PackedByteArray([0x00, 0x00, 0x00, 0x0D])
	assert_eq(ApngLoader._read_uint32_be(data, 0), 13)

func test_read_uint32_be_large():
	var data = PackedByteArray([0x01, 0x00, 0x00, 0x00])
	assert_eq(ApngLoader._read_uint32_be(data, 0), 16777216)

func test_read_uint16_be():
	var data = PackedByteArray([0x00, 0x0A])
	assert_eq(ApngLoader._read_uint16_be(data, 0), 10)

func test_make_idat_chunk_has_correct_length():
	var payload = PackedByteArray([1, 2, 3, 4])
	var chunk = ApngLoader._make_idat_chunk(payload)
	# 4 bytes length + 4 bytes "IDAT" + 4 bytes payload + 4 bytes CRC = 16
	assert_eq(chunk.size(), 16)
	# First 4 bytes = length = 4
	assert_eq(ApngLoader._read_uint32_be(chunk, 0), 4)
	# Bytes 4-7 = "IDAT"
	assert_eq(chunk[4], 0x49)  # I
	assert_eq(chunk[5], 0x44)  # D
	assert_eq(chunk[6], 0x41)  # A
	assert_eq(chunk[7], 0x54)  # T

func test_crc32_known_value():
	# CRC32 de "IEND" = 0xAE426082
	var data = PackedByteArray([0x49, 0x45, 0x4E, 0x44])
	assert_eq(ApngLoader._crc32(data), 0xAE426082)

func test_load_nonexistent_file_returns_empty():
	var result = ApngLoader.load("/tmp/nonexistent_apng_test_file_xyz.apng")
	assert_eq(result, {})
