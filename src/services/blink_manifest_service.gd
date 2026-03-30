extends RefCounted

## Service de gestion du manifeste de clignements d'yeux.
## Lit et écrit `assets/foregrounds/blink_manifest.yaml` dans le dossier story.
##
## Format YAML :
##   blinks:
##     hero_smile.png: hero_smile_blink.png
##     hero_sad.png: hero_sad_blink.png
##
## Les clés et valeurs sont des noms de fichiers relatifs à `assets/foregrounds/`.

const MANIFEST_FILE := "assets/foregrounds/blink_manifest.yaml"


## Charge le manifeste depuis le dossier story.
## Retourne un Dictionary { source_filename: blink_filename }.
static func load_manifest(story_base_path: String) -> Dictionary:
	var file_path = story_base_path.path_join(MANIFEST_FILE)
	if not FileAccess.file_exists(file_path):
		return {}
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {}
	var content = file.get_as_text()
	file.close()
	return _parse_manifest(content)


## Sauvegarde le manifeste dans le dossier story.
## manifest est un Dictionary { source_filename: blink_filename }.
static func save_manifest(story_base_path: String, manifest: Dictionary) -> void:
	var file_path = story_base_path.path_join(MANIFEST_FILE)
	var dir_path = file_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir_path)
	var content = _serialize_manifest(manifest)
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(content)
		file.close()


## Retourne le nom du fichier blink associé à image_filename, ou "" si absent.
static func get_blink_for(story_base_path: String, image_filename: String) -> String:
	var manifest = load_manifest(story_base_path)
	if manifest.has(image_filename):
		return manifest[image_filename]
	return ""


## Associe source_filename à blink_filename dans le manifeste, puis sauvegarde.
static func set_blink(story_base_path: String, source_filename: String, blink_filename: String) -> void:
	var manifest = load_manifest(story_base_path)
	manifest[source_filename] = blink_filename
	save_manifest(story_base_path, manifest)


# --- Parsing interne ---

static func _parse_manifest(content: String) -> Dictionary:
	var result := {}
	var lines = content.split("\n")
	var in_blinks := false
	for line in lines:
		var stripped = line.strip_edges()
		if stripped == "" or stripped.begins_with("#"):
			continue
		if stripped == "blinks:":
			in_blinks = true
			continue
		if in_blinks:
			# Chaque ligne est "  key: value" avec une indentation de 2 espaces
			var indent = _get_indent(line)
			if indent == 0:
				# On sort du bloc blinks
				in_blinks = false
				continue
			# Trouver le premier ":" qui sépare clé et valeur
			var colon_pos = stripped.find(": ")
			if colon_pos < 0:
				# Essayer aussi un ":" en fin de ligne (valeur vide)
				if stripped.ends_with(":"):
					result[stripped.substr(0, stripped.length() - 1)] = ""
				continue
			var key = stripped.substr(0, colon_pos).strip_edges()
			var value = stripped.substr(colon_pos + 2).strip_edges()
			result[key] = value
	return result


static func _serialize_manifest(manifest: Dictionary) -> String:
	var lines := PackedStringArray()
	lines.append("blinks:")
	var keys = manifest.keys()
	keys.sort()
	for key in keys:
		var value = manifest[key]
		lines.append("  %s: %s" % [key, value])
	return "\n".join(lines) + "\n"


static func _get_indent(line: String) -> int:
	var count = 0
	for c in line:
		if c == " ":
			count += 1
		elif c == "\t":
			count += 2
		else:
			break
	return count
