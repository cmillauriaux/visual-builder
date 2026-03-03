extends RefCounted

## Utilitaire partagé de chargement de textures (ressources Godot ou fichiers externes).

class_name TextureLoader

static func load_texture(path: String) -> Texture2D:
	if path == "":
		return null
	# Try as Godot resource first
	if ResourceLoader.exists(path):
		return load(path)
	# Try as external file
	if not FileAccess.file_exists(path):
		return null
	var img = Image.new()
	var err = img.load(path)
	if err != OK:
		return null
	return ImageTexture.create_from_image(img)
