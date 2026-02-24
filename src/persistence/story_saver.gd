extends RefCounted

## Sauvegarde et chargement d'histoires au format YAML structuré.

const YamlParser = preload("res://src/persistence/yaml_parser.gd")
const StoryScript = preload("res://src/models/story.gd")
const ChapterScript = preload("res://src/models/chapter.gd")
const SceneDataScript = preload("res://src/models/scene_data.gd")
const SequenceScript = preload("res://src/models/sequence.gd")

# --- Sauvegarde ---

static func save_story(story, base_path: String) -> void:
	# Créer la structure de dossiers
	DirAccess.make_dir_recursive_absolute(base_path)
	DirAccess.make_dir_recursive_absolute(base_path + "/assets/backgrounds")
	DirAccess.make_dir_recursive_absolute(base_path + "/assets/foregrounds")
	DirAccess.make_dir_recursive_absolute(base_path + "/chapters")

	# Écrire story.yaml
	var story_dict = story.to_dict()
	var story_yaml = YamlParser.dict_to_yaml(story_dict)
	_write_file(base_path + "/story.yaml", story_yaml)

	# Écrire chaque chapitre
	for chapter in story.chapters:
		var ch_path = base_path + "/chapters/" + chapter.uuid
		DirAccess.make_dir_recursive_absolute(ch_path)
		DirAccess.make_dir_recursive_absolute(ch_path + "/scenes")

		# chapter.yaml
		var ch_dict = chapter.to_dict()
		var ch_yaml = YamlParser.dict_to_yaml(ch_dict)
		_write_file(ch_path + "/chapter.yaml", ch_yaml)

		# Fichiers scène
		for scene in chapter.scenes:
			var scene_dict = scene.to_dict()
			var scene_yaml = YamlParser.dict_to_yaml(scene_dict)
			_write_file(ch_path + "/scenes/" + scene.uuid + ".yaml", scene_yaml)

# --- Chargement ---

static func load_story(base_path: String):
	var story_yaml_path = base_path + "/story.yaml"
	if not FileAccess.file_exists(story_yaml_path):
		return null

	# Lire story.yaml
	var story_content = _read_file(story_yaml_path)
	var story_dict = YamlParser.yaml_to_dict(story_content)
	var story = StoryScript.from_dict(story_dict)

	# Charger chaque chapitre complet
	var full_chapters = []
	for ch_header in story.chapters:
		var ch_path = base_path + "/chapters/" + ch_header.uuid
		var ch_yaml_path = ch_path + "/chapter.yaml"

		if FileAccess.file_exists(ch_yaml_path):
			var ch_content = _read_file(ch_yaml_path)
			var ch_dict = YamlParser.yaml_to_dict(ch_content)
			var chapter = ChapterScript.from_dict(ch_dict)
			chapter.position = ch_header.position

			# Charger les scènes complètes
			var full_scenes = []
			for scene_header in chapter.scenes:
				var scene_path = ch_path + "/scenes/" + scene_header.uuid + ".yaml"
				if FileAccess.file_exists(scene_path):
					var scene_content = _read_file(scene_path)
					var scene_dict = YamlParser.yaml_to_dict(scene_content)
					var scene = SceneDataScript.from_dict(scene_dict)
					scene.position = scene_header.position
					full_scenes.append(scene)
				else:
					full_scenes.append(scene_header)
			chapter.scenes = full_scenes
			full_chapters.append(chapter)
		else:
			full_chapters.append(ch_header)

	story.chapters = full_chapters
	return story

# --- Utilitaires fichier ---

static func _write_file(path: String, content: String) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(content)
		file.close()

static func _read_file(path: String) -> String:
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		file.close()
		return content
	return ""
