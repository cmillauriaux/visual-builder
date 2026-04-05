# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends RefCounted

## Utilitaire partagé de chargement de textures (ressources Godot ou fichiers externes).

class_name TextureLoader

static var base_dir: String = ""

static func load_texture(path: String) -> Texture2D:
	if path == "":
		return null

	var full_path = path
	if not path.is_absolute_path() and not path.begins_with("res://") and base_dir != "":
		full_path = base_dir.path_join(path)

	# Try as Godot resource first (skips raw images packed without .import)
	if ResourceLoader.exists(full_path):
		return load(full_path)
	# Try as raw image in PCK (res:// path but no .import — loaded via FileAccess buffer)
	if full_path.begins_with("res://") and FileAccess.file_exists(full_path):
		return _load_from_buffer(full_path)
	# Try as external file
	if not FileAccess.file_exists(full_path):
		# Fallback pour les chemins absolus invalides (migration de machine)
		if path.is_absolute_path() and base_dir != "":
			var assets_pos = path.find("assets/")
			if assets_pos != -1:
				var sub_path = path.substr(assets_pos)
				full_path = base_dir.path_join(sub_path)
				if not FileAccess.file_exists(full_path):
					return null
			else:
				return null
		else:
			return null
	var img = Image.new()
	var err = img.load(full_path)
	if err != OK:
		return null
	return ImageTexture.create_from_image(img)


## Charge une image depuis un fichier accessible via FileAccess (PCK ou filesystem).
## Utilise load_*_from_buffer() car Image.load() ne fonctionne pas avec les chemins res://.
static func _load_from_buffer(file_path: String) -> Texture2D:
	var fa = FileAccess.open(file_path, FileAccess.READ)
	if not fa:
		return null
	var buf = fa.get_buffer(fa.get_length())
	fa.close()

	var img = Image.new()
	var ext = file_path.get_extension().to_lower()
	var err: int
	if ext == "webp":
		err = img.load_webp_from_buffer(buf)
	elif ext == "png":
		err = img.load_png_from_buffer(buf)
	elif ext == "jpg" or ext == "jpeg":
		err = img.load_jpg_from_buffer(buf)
	else:
		return null

	if err != OK:
		return null
	return ImageTexture.create_from_image(img)