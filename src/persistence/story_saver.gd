extends RefCounted

## Sauvegarde et chargement d'histoires au format YAML structuré.

const YamlParser = preload("res://src/persistence/yaml_parser.gd")
const StoryScript = preload("res://src/models/story.gd")
const ChapterScript = preload("res://src/models/chapter.gd")
const SceneDataScript = preload("res://src/models/scene_data.gd")
const SequenceScript = preload("res://src/models/sequence.gd")
const StoryI18nService = preload("res://src/services/story_i18n_service.gd")

# --- Sauvegarde ---

static func save_story(story, base_path: String, lang: String = "fr") -> void:
	# Créer la structure de dossiers
	DirAccess.make_dir_recursive_absolute(base_path)
	DirAccess.make_dir_recursive_absolute(base_path + "/assets/backgrounds")
	DirAccess.make_dir_recursive_absolute(base_path + "/assets/foregrounds")
	DirAccess.make_dir_recursive_absolute(base_path + "/assets/icons")
	DirAccess.make_dir_recursive_absolute(base_path + "/chapters")

	# S'assurer que le loader utilise ce chemin pour les chargements ultérieurs
	TextureLoader.base_dir = base_path

	# Copier les assets et réécrire les chemins en relatif
	_relocate_assets(story, base_path)

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

	# Générer/mettre à jour i18n/fr.yaml (fichier source pour traducteurs)
	var source_strings = StoryI18nService.extract_strings(story)
	StoryI18nService.save_i18n(source_strings, base_path, "fr")

# --- Chargement ---

static func load_story(base_path: String, lang: String = "fr"):
	var story_yaml_path = base_path + "/story.yaml"
	if not FileAccess.file_exists(story_yaml_path):
		return null

	# Définir le répertoire de base pour le chargement des images relatives
	TextureLoader.base_dir = base_path

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

	# Appliquer les traductions si langue différente du français
	if lang != "fr":
		var i18n_dict = StoryI18nService.load_i18n(base_path, lang)
		StoryI18nService.apply_to_story(story, i18n_dict)

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

# --- Relocalisation des assets ---

static func _relocate_assets(story, base_path: String) -> void:
	# App icon
	story.app_icon = _relocate_image(story.app_icon, base_path, "icons")
	# Menu background
	story.menu_background = _relocate_image(story.menu_background, base_path, "backgrounds")
	# Game over background
	story.game_over_background = _relocate_image(story.game_over_background, base_path, "backgrounds")
	# To be continued background
	story.to_be_continued_background = _relocate_image(story.to_be_continued_background, base_path, "backgrounds")

	# Images des variables
	for var_def in story.variables:
		var_def.image = _relocate_image(var_def.image, base_path, "foregrounds")

	for chapter in story.chapters:
		for scene in chapter.scenes:
			for seq in scene.sequences:
				# Background de séquence
				seq.background = _relocate_image(seq.background, base_path, "backgrounds")
				# Foregrounds de séquence
				for fg in seq.foregrounds:
					fg.image = _relocate_image(fg.image, base_path, "foregrounds")
				# Foregrounds de chaque dialogue
				for dlg in seq.dialogues:
					for fg in dlg.foregrounds:
						fg.image = _relocate_image(fg.image, base_path, "foregrounds")


static func _relocate_image(image_path: String, base_path: String, subfolder: String) -> String:
	if image_path == "":
		return ""
	
	var filename = image_path.get_file()
	var dest_dir = base_path + "/assets/" + subfolder
	var expected_abs = dest_dir + "/" + filename
	var relative_path = "assets/" + subfolder + "/" + filename
	
	# Si c'est déjà le bon chemin relatif, on ne touche à rien
	if image_path == relative_path:
		return relative_path
		
	# Si c'est le chemin absolu correspondant au dossier de destination, on convertit en relatif
	if image_path == expected_abs:
		return relative_path

	# Si le fichier source n'existe pas, on tente de résoudre via 'assets/' pour migration
	if not FileAccess.file_exists(image_path):
		var assets_pos = image_path.find("assets/")
		if assets_pos != -1:
			var sub_path = image_path.substr(assets_pos)
			var migration_path = base_path.path_join(sub_path)
			if FileAccess.file_exists(migration_path):
				image_path = migration_path
			else:
				return image_path
		else:
			return image_path
		
	# Si après résolution du fallback, on est déjà au bon endroit, on ne copie rien
	if image_path == expected_abs:
		return relative_path

	# Copier le fichier s'il n'existe pas encore à destination
	if not FileAccess.file_exists(expected_abs):
		DirAccess.copy_absolute(image_path, expected_abs)
		
	return relative_path
