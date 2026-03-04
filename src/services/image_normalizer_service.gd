extends RefCounted

## Service de normalisation d'images.
## Analyse et normalise les images pour uniformiser la balance des blancs,
## la luminosité et le contraste par rapport à une image de référence.
## Utilise PackedByteArray pour la performance.


static func analyze_image(path: String) -> Dictionary:
	var img = Image.new()
	if img.load(path) != OK:
		return {}

	img.convert(Image.FORMAT_RGBA8)

	# Redimensionner pour l'analyse (max 512x512)
	var w = img.get_width()
	var h = img.get_height()
	if w > 512 or h > 512:
		var scale = min(512.0 / w, 512.0 / h)
		img.resize(int(w * scale), int(h * scale), Image.INTERPOLATE_BILINEAR)

	var data = img.get_data()
	var pixel_count = data.size() / 4
	if pixel_count == 0:
		return {}

	var sum_r := 0.0
	var sum_g := 0.0
	var sum_b := 0.0
	var sum_lum := 0.0
	var sum_lum_sq := 0.0

	for i in range(pixel_count):
		var idx = i * 4
		var r = data[idx] / 255.0
		var g = data[idx + 1] / 255.0
		var b = data[idx + 2] / 255.0
		var lum = 0.299 * r + 0.587 * g + 0.114 * b

		sum_r += r
		sum_g += g
		sum_b += b
		sum_lum += lum
		sum_lum_sq += lum * lum

	var mean_r = sum_r / pixel_count
	var mean_g = sum_g / pixel_count
	var mean_b = sum_b / pixel_count
	var mean_lum = sum_lum / pixel_count
	var variance = (sum_lum_sq / pixel_count) - (mean_lum * mean_lum)
	var std_lum = sqrt(max(variance, 0.0))

	return {
		"path": path,
		"mean_r": mean_r,
		"mean_g": mean_g,
		"mean_b": mean_b,
		"mean_luminance": mean_lum,
		"std_luminance": std_lum,
		"pixel_count": pixel_count
	}


static func normalize_image(path: String, image_stats: Dictionary, reference_stats: Dictionary, output_path: String) -> bool:
	var img = Image.new()
	if img.load(path) != OK:
		return false

	img.convert(Image.FORMAT_RGBA8)
	var data = img.get_data()
	var pixel_count = data.size() / 4
	if pixel_count == 0:
		return false

	var safe_mean_r = max(image_stats["mean_r"], 0.001)
	var safe_mean_g = max(image_stats["mean_g"], 0.001)
	var safe_mean_b = max(image_stats["mean_b"], 0.001)
	var safe_std = max(image_stats["std_luminance"], 0.001)

	var ref_mean_r = reference_stats["mean_r"]
	var ref_mean_g = reference_stats["mean_g"]
	var ref_mean_b = reference_stats["mean_b"]
	var ref_std = reference_stats["std_luminance"]
	var contrast_factor = ref_std / safe_std

	var wb_r = ref_mean_r / safe_mean_r
	var wb_g = ref_mean_g / safe_mean_g
	var wb_b = ref_mean_b / safe_mean_b

	var new_data = PackedByteArray()
	new_data.resize(data.size())

	for i in range(pixel_count):
		var idx = i * 4
		var r = data[idx] / 255.0
		var g = data[idx + 1] / 255.0
		var b = data[idx + 2] / 255.0

		# Balance des blancs + luminosité + contraste
		var new_r = ref_mean_r + (r * wb_r - ref_mean_r) * contrast_factor
		var new_g = ref_mean_g + (g * wb_g - ref_mean_g) * contrast_factor
		var new_b = ref_mean_b + (b * wb_b - ref_mean_b) * contrast_factor

		new_data[idx] = int(clampf(new_r, 0.0, 1.0) * 255.0)
		new_data[idx + 1] = int(clampf(new_g, 0.0, 1.0) * 255.0)
		new_data[idx + 2] = int(clampf(new_b, 0.0, 1.0) * 255.0)
		new_data[idx + 3] = data[idx + 3]  # Alpha préservé

	var result = Image.create_from_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, new_data)
	return _save_image(result, output_path, path.get_extension().to_lower())


static func cleanup_temp_dir(temp_dir_path: String) -> void:
	var dir = DirAccess.open(temp_dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			dir.remove(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(temp_dir_path)


static func apply_normalized_images(mappings: Array) -> int:
	var count := 0
	for mapping in mappings:
		var original_path: String = mapping["original"]
		var temp_path: String = mapping["temp"]
		if not FileAccess.file_exists(temp_path):
			continue
		# Charger l'image temporaire et la sauvegarder à l'emplacement original
		var img = Image.new()
		if img.load(temp_path) != OK:
			continue
		var ext = original_path.get_extension().to_lower()
		if _save_image(img, original_path, ext):
			count += 1
	return count


static func get_temp_path(original_path: String, temp_dir: String, prefix: String) -> String:
	return temp_dir + "/" + prefix + original_path.get_file()


static func _save_image(img: Image, path: String, ext: String) -> bool:
	match ext:
		"jpg", "jpeg":
			return img.save_jpg(path, 0.9) == OK
		"webp":
			return img.save_webp(path) == OK
		_:
			return img.save_png(path) == OK
