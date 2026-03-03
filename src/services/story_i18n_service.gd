## Service d'internationalisation des histoires (style .po).
##
## Les fichiers YAML d'histoire restent inchangés (texte source en français).
## Un fichier i18n/{lang}.yaml mappe chaque chaîne source vers sa traduction.
## Format : { "chaîne source": "traduction" }

class_name StoryI18nService

const YamlParser = preload("res://src/persistence/yaml_parser.gd")

## Chaînes fixes de l'interface utilisateur du jeu (incluses dans tous les fichiers i18n).
const UI_STRINGS: Array[String] = [
	# Bouton menu in-game
	"☰ Menu",
	# Sélecteur d'histoires
	"Sélectionnez une histoire",
	"Aucune histoire trouvée",
	"Fonctionnalité à venir",
	# Overlay de choix
	"Faites votre choix",
	# Messages de fin de partie
	"Fin — Game Over",
	"Fin — À suivre...",
	"Fin (aucune terminaison configurée)",
	"Erreur (cible introuvable ou contenu vide)",
	"Lecture arrêtée",
	"Fin de la lecture",
	# Menu principal
	"Nouvelle partie",
	"Charger partie",
	"Options",
	"Quitter",
	# Menu pause
	"Pause",
	"Reprendre",
	"Sauvegarder",
	"Charger",
	# Menu options
	"Affichage",
	"Résolution",
	"Plein écran",
	"Audio",
	"Musique",
	"Volume musique",
	"Effets sonores",
	"Volume effets",
	"Langue",
	"Appliquer",
]


## Retourne la traduction d'une chaîne depuis un dictionnaire i18n.
## Fallback : retourne la chaîne source si la clé est absente ou la traduction vide.
static func get_ui_string(source: String, i18n_dict: Dictionary) -> String:
	return _tr(source, i18n_dict)


## Extrait toutes les chaînes source non vides d'une histoire.
## Retourne un dictionnaire { source: source } (clé = valeur) pour générer fr.yaml.
static func extract_strings(story: RefCounted) -> Dictionary:
	var strings: Dictionary = {}

	# Chaînes d'interface fixes
	for s in UI_STRINGS:
		_add(strings, s)

	# Story
	_add(strings, story.title)
	_add(strings, story.author)
	_add(strings, story.description)
	_add(strings, story.menu_title)
	_add(strings, story.menu_subtitle)

	# Notifications
	for notif in story.notifications:
		_add(strings, notif.message)

	# Chapters → Scenes → Sequences → Dialogues / Choices
	for chapter in story.chapters:
		_add(strings, chapter.chapter_name)
		_add(strings, chapter.subtitle)
		for scene in chapter.scenes:
			_add(strings, scene.scene_name)
			_add(strings, scene.subtitle)
			for seq in scene.sequences:
				_add(strings, seq.seq_name)
				_add(strings, seq.subtitle)
				for dlg in seq.dialogues:
					_add(strings, dlg.character)
					_add(strings, dlg.text)
				if seq.ending and seq.ending.type == "choices":
					for choice in seq.ending.choices:
						_add(strings, choice.text)

	return strings


## Charge le fichier i18n/{lang}.yaml depuis story_path.
## Retourne {} si le fichier est absent ou illisible.
static func load_i18n(story_path: String, lang: String) -> Dictionary:
	var path = story_path + "/i18n/" + lang + ".yaml"
	if not FileAccess.file_exists(path):
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var content = file.get_as_text()
	file.close()
	var result = YamlParser.yaml_to_dict(content)
	if result == null:
		return {}
	return result


## Écrit le fichier i18n/{lang}.yaml dans story_path.
static func save_i18n(strings_dict: Dictionary, story_path: String, lang: String) -> void:
	var dir = story_path + "/i18n"
	DirAccess.make_dir_recursive_absolute(dir)
	var yaml = YamlParser.dict_to_yaml(strings_dict)
	var path = dir + "/" + lang + ".yaml"
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(yaml)
		file.close()


## Applique les traductions de i18n_dict aux champs texte de l'histoire en mémoire.
## Si une clé est absente ou si la traduction est vide, la valeur source est conservée.
static func apply_to_story(story: RefCounted, i18n_dict: Dictionary) -> void:
	if i18n_dict.is_empty():
		return

	story.title = _tr(story.title, i18n_dict)
	story.author = _tr(story.author, i18n_dict)
	story.description = _tr(story.description, i18n_dict)
	story.menu_title = _tr(story.menu_title, i18n_dict)
	story.menu_subtitle = _tr(story.menu_subtitle, i18n_dict)

	for notif in story.notifications:
		notif.message = _tr(notif.message, i18n_dict)

	for chapter in story.chapters:
		chapter.chapter_name = _tr(chapter.chapter_name, i18n_dict)
		chapter.subtitle = _tr(chapter.subtitle, i18n_dict)
		for scene in chapter.scenes:
			scene.scene_name = _tr(scene.scene_name, i18n_dict)
			scene.subtitle = _tr(scene.subtitle, i18n_dict)
			for seq in scene.sequences:
				seq.seq_name = _tr(seq.seq_name, i18n_dict)
				seq.subtitle = _tr(seq.subtitle, i18n_dict)
				for dlg in seq.dialogues:
					dlg.character = _tr(dlg.character, i18n_dict)
					dlg.text = _tr(dlg.text, i18n_dict)
				if seq.ending and seq.ending.type == "choices":
					for choice in seq.ending.choices:
						choice.text = _tr(choice.text, i18n_dict)


## Charge la configuration des langues depuis i18n/languages.yaml.
## Si le fichier est absent, bootstrap depuis les fichiers i18n/*.yaml existants.
## Format retourné : { "default": "fr", "languages": ["fr", "en"] }
static func load_languages_config(story_path: String) -> Dictionary:
	var config_path = story_path + "/i18n/languages.yaml"
	if FileAccess.file_exists(config_path):
		var file = FileAccess.open(config_path, FileAccess.READ)
		if file:
			var content = file.get_as_text()
			file.close()
			var parsed = YamlParser.yaml_to_dict(content)
			if parsed and parsed.has("languages"):
				var langs = parsed["languages"]
				if langs is Array and not langs.is_empty():
					return {
						"default": parsed.get("default", langs[0]),
						"languages": langs,
					}
	# Bootstrap depuis les fichiers existants
	var existing = _scan_language_files(story_path)
	if existing.is_empty():
		existing = ["fr"]
	var default_lang = "fr" if existing.has("fr") else existing[0]
	return {"default": default_lang, "languages": existing}


## Sauvegarde la configuration des langues dans i18n/languages.yaml.
static func save_languages_config(config: Dictionary, story_path: String) -> void:
	DirAccess.make_dir_recursive_absolute(story_path + "/i18n")
	var yaml = YamlParser.dict_to_yaml(config)
	var file = FileAccess.open(story_path + "/i18n/languages.yaml", FileAccess.WRITE)
	if file:
		file.store_string(yaml)
		file.close()


## Retourne la liste des codes de langue déduits des fichiers *.yaml dans i18n/
## (hors languages.yaml). Triés alphabétiquement.
static func get_available_languages(story_path: String) -> Array:
	return _scan_language_files(story_path)


## Vérifie les fichiers de traduction par rapport aux chaînes source de l'histoire.
## Retourne un dictionnaire par langue non-défaut :
##   { lang: { "missing": [...], "orphans": [...], "total": int, "translated": int } }
## La langue par défaut (source) est ignorée.
static func check_translations(story: RefCounted, story_path: String) -> Dictionary:
	var source_strings = extract_strings(story)
	var config = load_languages_config(story_path)
	var default_lang: String = config.get("default", "fr")
	var langs: Array = config.get("languages", [])
	var result: Dictionary = {}

	for lang in langs:
		if lang == default_lang:
			continue
		var i18n = load_i18n(story_path, lang)
		var missing: Array = []
		var orphans: Array = []
		var translated := 0

		for src in source_strings:
			if not i18n.has(src) or i18n[src] == "":
				missing.append(src)
			else:
				translated += 1

		for key in i18n:
			if not source_strings.has(key):
				orphans.append(key)

		result[lang] = {
			"missing": missing,
			"orphans": orphans,
			"total": source_strings.size(),
			"translated": translated,
		}

	return result


## Ajoute les clés manquantes dans tous les fichiers de traduction configurés.
## Pour la langue par défaut : clé = valeur (chaîne source).
## Pour les autres langues : clé = "" (à traduire).
## Crée les fichiers manquants. Retourne { lang: added_count }.
static func regenerate_missing_keys(story: RefCounted, story_path: String) -> Dictionary:
	var source_strings = extract_strings(story)
	var config = load_languages_config(story_path)
	var default_lang: String = config.get("default", "fr")
	var langs: Array = config.get("languages", [])
	var result: Dictionary = {}

	# Garantir que la langue par défaut est dans la liste
	if not langs.has(default_lang):
		langs = [default_lang] + langs

	for lang in langs:
		var i18n = load_i18n(story_path, lang)
		var added := 0
		for src in source_strings:
			if not i18n.has(src):
				i18n[src] = src if lang == default_lang else ""
				added += 1
		save_i18n(i18n, story_path, lang)
		result[lang] = added

	return result


# --- Helpers ---

static func _scan_language_files(story_path: String) -> Array:
	var langs: Array = []
	var dir = DirAccess.open(story_path + "/i18n")
	if dir == null:
		return langs
	dir.list_dir_begin()
	var name = dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.ends_with(".yaml") and name != "languages.yaml":
			langs.append(name.get_basename())
		name = dir.get_next()
	dir.list_dir_end()
	langs.sort()
	return langs


static func _add(d: Dictionary, s: String) -> void:
	if s != "":
		d[s] = s


static func _tr(source: String, i18n_dict: Dictionary) -> String:
	if source == "":
		return source
	if not i18n_dict.has(source):
		return source
	var translation: String = i18n_dict[source]
	if translation == "":
		return source
	return translation
