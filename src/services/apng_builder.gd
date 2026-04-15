# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

class_name ApngBuilder

## Assemble frames RGBA en APNG. Retourne PackedByteArray (fichier APNG).
## frames: Array[Image], fps: float (>0), loops: int (0 = infini)
static func build(frames: Array, fps: float, loops: int = 0) -> PackedByteArray:
	if frames.is_empty() or fps <= 0.0:
		return PackedByteArray()

	var png_list: Array = []
	for frame in frames:
		var img: Image = frame as Image
		if img == null:
			return PackedByteArray()
		png_list.append(img.save_png_to_buffer())

	var parsed: Array = []
	for png_bytes in png_list:
		parsed.append(_parse_png_chunks(png_bytes))

	var num_frames: int = frames.size()
	var ihdr0: PackedByteArray = parsed[0]["ihdr_data"]
	var width: int = (ihdr0[0] << 24) | (ihdr0[1] << 16) | (ihdr0[2] << 8) | ihdr0[3]
	var height: int = (ihdr0[4] << 24) | (ihdr0[5] << 16) | (ihdr0[6] << 8) | ihdr0[7]

	var out := PackedByteArray()
	out.append_array(PackedByteArray([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]))
	out.append_array(_make_chunk("IHDR", ihdr0))

	var actl := PackedByteArray()
	actl.append_array(_u32_be(num_frames))
	actl.append_array(_u32_be(loops))
	out.append_array(_make_chunk("acTL", actl))

	var seq_num: int = 0
	for i in range(num_frames):
		var fctl := PackedByteArray()
		fctl.append_array(_u32_be(seq_num)); seq_num += 1
		fctl.append_array(_u32_be(width))
		fctl.append_array(_u32_be(height))
		fctl.append_array(_u32_be(0))    # x_offset
		fctl.append_array(_u32_be(0))    # y_offset
		var delay_ms := clampi(roundi(1000.0 / fps), 1, 65535)
		fctl.append_array(_u16_be(delay_ms))  # delay_num  (ms per frame)
		fctl.append_array(_u16_be(1000))      # delay_den
		fctl.append(0)  # dispose_op = APNG_DISPOSE_OP_NONE
		fctl.append(0)  # blend_op = APNG_BLEND_OP_SOURCE
		out.append_array(_make_chunk("fcTL", fctl))

		var idat_chunks: Array = parsed[i]["idat_chunks"]
		for idat in idat_chunks:
			if i == 0:
				out.append_array(_make_chunk("IDAT", idat))
			else:
				var fdat := PackedByteArray()
				fdat.append_array(_u32_be(seq_num)); seq_num += 1
				fdat.append_array(idat)
				out.append_array(_make_chunk("fdAT", fdat))

	out.append_array(_make_chunk("IEND", PackedByteArray()))
	return out


static func _parse_png_chunks(png_bytes: PackedByteArray) -> Dictionary:
	var result := {"ihdr_data": PackedByteArray(), "idat_chunks": []}
	var pos: int = 8  # skip 8-byte signature
	while pos + 8 <= png_bytes.size():
		var length: int = (png_bytes[pos] << 24) | (png_bytes[pos + 1] << 16) | \
			(png_bytes[pos + 2] << 8) | png_bytes[pos + 3]
		var type_str: String = png_bytes.slice(pos + 4, pos + 8).get_string_from_ascii()
		var data: PackedByteArray = png_bytes.slice(pos + 8, pos + 8 + length) \
			if length > 0 else PackedByteArray()
		if type_str == "IHDR":
			result["ihdr_data"] = data
		elif type_str == "IDAT":
			result["idat_chunks"].append(data)
		pos += 12 + length  # 4B len + 4B type + N data + 4B CRC
	return result


static func _make_chunk(type_str: String, data: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray()
	out.append_array(_u32_be(data.size()))
	var type_bytes: PackedByteArray = type_str.to_ascii_buffer()
	out.append_array(type_bytes)
	out.append_array(data)
	out.append_array(_crc32_of(type_bytes, data))
	return out


static func _crc32_of(type_bytes: PackedByteArray, data: PackedByteArray) -> PackedByteArray:
	# CRC32 standard (polynôme PNG 0xEDB88320, reversed representation)
	var crc: int = 0xFFFFFFFF
	for byte in type_bytes:
		crc ^= byte
		for _bit in range(8):
			if crc & 1:
				crc = (crc >> 1) ^ 0xEDB88320
			else:
				crc >>= 1
	for byte in data:
		crc ^= byte
		for _bit in range(8):
			if crc & 1:
				crc = (crc >> 1) ^ 0xEDB88320
			else:
				crc >>= 1
	return _u32_be(crc ^ 0xFFFFFFFF)


static func _u32_be(value: int) -> PackedByteArray:
	var b := PackedByteArray([0, 0, 0, 0])
	b[0] = (value >> 24) & 0xFF
	b[1] = (value >> 16) & 0xFF
	b[2] = (value >> 8) & 0xFF
	b[3] = value & 0xFF
	return b


static func _u16_be(value: int) -> PackedByteArray:
	var b := PackedByteArray([0, 0])
	b[0] = (value >> 8) & 0xFF
	b[1] = value & 0xFF
	return b
