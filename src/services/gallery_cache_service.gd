extends RefCounted

## Service de mise en cache pour la galerie (images et listes de fichiers).
## Améliore les performances d'ouverture des popups de la galerie.

class_name GalleryCacheService

# Cache des textures : path -> ImageTexture
static var _texture_cache: Dictionary = {}

# Cache des listes de fichiers : dir_path -> Array[String]
static var _file_list_cache: Dictionary = {}

## Récupère une texture du cache ou la charge si absente.
static func get_texture(path: String) -> ImageTexture:
	if _texture_cache.has(path):
		var tex = _texture_cache[path]
		if is_instance_valid(tex):
			return tex
	
	if not FileAccess.file_exists(path):
		return null
		
	var img = Image.new()
	if img.load(path) == OK:
		var tex = ImageTexture.create_from_image(img)
		_texture_cache[path] = tex
		return tex
	return null

## Récupère la liste des fichiers d'un dossier (mise en cache).
static func get_file_list(dir_path: String, extensions: Array) -> Array:
	if _file_list_cache.has(dir_path):
		return _file_list_cache[dir_path]
	
	var result = []
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return result
		
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if not dir.current_is_dir():
			var ext = fname.get_extension().to_lower()
			if ext in extensions:
				result.append(dir_path + "/" + fname)
		fname = dir.get_next()
	dir.list_dir_end()
	result.sort()
	
	_file_list_cache[dir_path] = result
	return result

## Force le vidage du cache.
static func clear_all() -> void:
	_texture_cache.clear()
	_file_list_cache.clear()

## Vide le cache pour un chemin spécifique (utile après renommage/suppression).
static func clear_path(path: String) -> void:
	if _texture_cache.has(path):
		_texture_cache.erase(path)
	
	var dir_path = path.get_base_dir()
	if _file_list_cache.has(dir_path):
		_file_list_cache.erase(dir_path)

## Vide le cache d'un dossier spécifique.
static func clear_dir(dir_path: String) -> void:
	if _file_list_cache.has(dir_path):
		_file_list_cache.erase(dir_path)
	
	# On pourrait aussi filtrer _texture_cache mais c'est plus coûteux.
	# Les entrées invalides seront de toute façon ignorées par get_texture.
