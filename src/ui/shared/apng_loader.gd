# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends RefCounted
class_name ApngLoader

## Parse un fichier APNG et extrait ses frames et leurs délais.
## Retourne {} en cas d'erreur.
## Retourne { "frames": Array[ImageTexture], "delays": Array[float] } en cas de succès.

const PNG_SIG = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
const DEFAULT_DELAY = 1.0 / 12.0

static var _cache: Dictionary = {}  # path → { "frames": Array[ImageTexture], "delays": Array[float] }


static func load(path: String) -> Dictionary:
	if _cache.has(path):
		return _cache[path]
	var fa = FileAccess.open(path, FileAccess.READ)
	if not fa:
		return {}
	var data = fa.get_buffer(fa.get_length())
	fa.close()
	var result = load_from_buffer(data)
	if not result.is_empty():
		_cache[path] = result
	return result


static func load_from_buffer(data: PackedByteArray) -> Dictionary:
	if data.size() < 8:
		return {}
	for i in range(8):
		if data[i] != PNG_SIG[i]:
			return {}

	var offset = 8
	var ihdr_chunk := PackedByteArray()
	var actl_found := false
	var current_delay := DEFAULT_DELAY
	var current_idat_parts: Array[PackedByteArray] = []
	var frame_delays: Array[float] = []
	var frame_parts_list: Array = []  # Array of Array[PackedByteArray]

	while offset + 8 <= data.size():
		var chunk_start = offset
		var chunk_len = _read_uint32_be(data, offset)
		offset += 4
		if offset + 4 > data.size():
			break
		var type_str = data.slice(offset, offset + 4).get_string_from_ascii()
		offset += 4
		var chunk_data := PackedByteArray()
		if chunk_len > 0 and offset + chunk_len <= data.size():
			chunk_data = data.slice(offset, offset + chunk_len)
		offset += chunk_len
		var full_chunk = data.slice(chunk_start, offset + 4)
		offset += 4  # skip CRC

		match type_str:
			"IHDR":
				ihdr_chunk = full_chunk
			"acTL":
				actl_found = true
			"fcTL":
				# Flush frames accumulés avant de démarrer la prochaine
				if not current_idat_parts.is_empty():
					frame_parts_list.append(current_idat_parts.duplicate())
					frame_delays.append(current_delay)
					current_idat_parts.clear()
				if chunk_data.size() >= 24:
					var delay_num = _read_uint16_be(chunk_data, 20)
					var delay_den = _read_uint16_be(chunk_data, 22)
					if delay_den == 0:
						delay_den = 100
					current_delay = DEFAULT_DELAY if delay_num == 0 else float(delay_num) / float(delay_den)
				else:
					current_delay = DEFAULT_DELAY
			"IDAT":
				current_idat_parts.append(full_chunk)  # Réutilise le chunk original (CRC valide)
			"fdAT":
				# Convertit fdAT (sequence_number + data) en chunk IDAT
				if chunk_data.size() > 4:
					current_idat_parts.append(_make_idat_chunk(chunk_data.slice(4)))
			"IEND":
				if not current_idat_parts.is_empty():
					frame_parts_list.append(current_idat_parts.duplicate())
					frame_delays.append(current_delay)
				break

	if not actl_found:
		# PNG standard (pas APNG) : charger comme frame unique
		var img = Image.new()
		if img.load_png_from_buffer(data) != OK:
			return {}
		var tex = ImageTexture.create_from_image(img)
		return { "frames": [tex], "delays": [DEFAULT_DELAY] }

	if frame_parts_list.is_empty():
		return {}

	var frames: Array[ImageTexture] = []
	var delays: Array[float] = []
	for i in range(frame_parts_list.size()):
		var tex = _reconstruct_frame(ihdr_chunk, frame_parts_list[i])
		if tex:
			frames.append(tex)
			delays.append(frame_delays[i])

	if frames.is_empty():
		return {}
	return { "frames": frames, "delays": delays }


static func _reconstruct_frame(ihdr: PackedByteArray, idat_parts: Array[PackedByteArray]) -> ImageTexture:
	var result := PackedByteArray()
	# Signature PNG
	result.append_array(PackedByteArray([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]))
	# IHDR original
	result.append_array(ihdr)
	# Chunks IDAT
	for part in idat_parts:
		result.append_array(part)
	# IEND fixe
	result.append_array(PackedByteArray([0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82]))
	var img = Image.new()
	if img.load_png_from_buffer(result) != OK:
		return null
	return ImageTexture.create_from_image(img)


static func _make_idat_chunk(payload: PackedByteArray) -> PackedByteArray:
	var chunk := PackedByteArray()
	var len = payload.size()
	chunk.append((len >> 24) & 0xFF)
	chunk.append((len >> 16) & 0xFF)
	chunk.append((len >> 8) & 0xFF)
	chunk.append(len & 0xFF)
	var type_bytes = PackedByteArray([0x49, 0x44, 0x41, 0x54])  # "IDAT"
	chunk.append_array(type_bytes)
	chunk.append_array(payload)
	var crc_input := PackedByteArray()
	crc_input.append_array(type_bytes)
	crc_input.append_array(payload)
	var crc = _crc32(crc_input)
	chunk.append((crc >> 24) & 0xFF)
	chunk.append((crc >> 16) & 0xFF)
	chunk.append((crc >> 8) & 0xFF)
	chunk.append(crc & 0xFF)
	return chunk


static var _crc_table: PackedInt32Array = []

static func _get_crc_table() -> PackedInt32Array:
	if not _crc_table.is_empty():
		return _crc_table
	_crc_table.resize(256)
	for i in range(256):
		var c = i
		for j in range(8):
			if c & 1:
				c = 0xEDB88320 ^ ((c >> 1) & 0x7FFFFFFF)
			else:
				c = (c >> 1) & 0x7FFFFFFF
		_crc_table[i] = c
	return _crc_table

static func _crc32(data: PackedByteArray) -> int:
	var crc: int = 0xFFFFFFFF
	var table = _get_crc_table()
	for b in data:
		crc = table[(crc ^ b) & 0xFF] ^ ((crc >> 8) & 0x00FFFFFF)
	return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF


static func _read_uint32_be(data: PackedByteArray, pos: int) -> int:
	return (data[pos] << 24) | (data[pos + 1] << 16) | (data[pos + 2] << 8) | data[pos + 3]


static func _read_uint16_be(data: PackedByteArray, pos: int) -> int:
	return (data[pos] << 8) | data[pos + 1]
