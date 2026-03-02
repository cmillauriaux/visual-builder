extends GutTest

## Tests pour les méthodes de configuration des langues dans StoryI18nService.

const StoryI18nService = preload("res://src/services/story_i18n_service.gd")

var _test_dir: String = ""


func before_each() -> void:
	_test_dir = "user://test_i18n_cfg_%d" % randi()
	DirAccess.make_dir_recursive_absolute(_test_dir)


func after_each() -> void:
	_remove_dir_recursive(_test_dir)


func _remove_dir_recursive(path: String) -> void:
	var dir = DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name = dir.get_next()
	while name != "":
		if name != "." and name != "..":
			var full = path + "/" + name
			if dir.current_is_dir():
				_remove_dir_recursive(full)
			else:
				DirAccess.remove_absolute(full)
		name = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)


# ── load_languages_config ─────────────────────────────────────────────────────

func test_load_config_returns_fr_default_when_no_files() -> void:
	var config = StoryI18nService.load_languages_config(_test_dir)
	assert_eq(config.get("default", ""), "fr")

func test_load_config_returns_fr_in_languages_when_no_files() -> void:
	var config = StoryI18nService.load_languages_config(_test_dir)
	assert_true(config.get("languages", []).has("fr"))

func test_load_config_bootstraps_from_existing_yaml_files() -> void:
	StoryI18nService.save_i18n({"Bonjour": "Hello"}, _test_dir, "en")
	StoryI18nService.save_i18n({"Bonjour": "Bonjour"}, _test_dir, "fr")
	var config = StoryI18nService.load_languages_config(_test_dir)
	assert_true(config.get("languages", []).has("en"))
	assert_true(config.get("languages", []).has("fr"))

func test_load_config_sets_fr_as_default_when_bootstrapping() -> void:
	StoryI18nService.save_i18n({}, _test_dir, "en")
	StoryI18nService.save_i18n({}, _test_dir, "fr")
	var config = StoryI18nService.load_languages_config(_test_dir)
	assert_eq(config.get("default", ""), "fr")

func test_load_config_from_saved_file() -> void:
	var original = {"default": "en", "languages": ["en", "fr"]}
	StoryI18nService.save_languages_config(original, _test_dir)
	var loaded = StoryI18nService.load_languages_config(_test_dir)
	assert_eq(loaded.get("default", ""), "en")
	assert_true(loaded.get("languages", []).has("fr"))
	assert_true(loaded.get("languages", []).has("en"))

func test_load_config_excludes_languages_yaml_from_scan() -> void:
	# languages.yaml ne doit pas apparaître comme une langue
	StoryI18nService.save_languages_config({"default": "fr", "languages": ["fr"]}, _test_dir)
	var config = StoryI18nService.load_languages_config(_test_dir)
	assert_false(config.get("languages", []).has("languages"))


# ── save_languages_config ─────────────────────────────────────────────────────

func test_save_creates_i18n_dir() -> void:
	StoryI18nService.save_languages_config({"default": "fr", "languages": ["fr"]}, _test_dir)
	assert_true(DirAccess.dir_exists_absolute(_test_dir + "/i18n"))

func test_save_creates_languages_yaml() -> void:
	StoryI18nService.save_languages_config({"default": "fr", "languages": ["fr"]}, _test_dir)
	assert_true(FileAccess.file_exists(_test_dir + "/i18n/languages.yaml"))

func test_save_and_load_roundtrip() -> void:
	var config = {"default": "fr", "languages": ["de", "en", "fr"]}
	StoryI18nService.save_languages_config(config, _test_dir)
	var loaded = StoryI18nService.load_languages_config(_test_dir)
	assert_eq(loaded.get("default", ""), "fr")
	var langs = loaded.get("languages", [])
	assert_true(langs.has("fr"))
	assert_true(langs.has("en"))
	assert_true(langs.has("de"))


# ── check_translations avec config ───────────────────────────────────────────

func _make_simple_story():
	var StoryScript = load("res://src/models/story.gd")
	var story = StoryScript.new()
	story.title = "Titre"
	story.menu_title = "Menu"
	return story

func test_check_uses_config_languages() -> void:
	var story = _make_simple_story()
	# Config avec de mais pas en
	StoryI18nService.save_languages_config({"default": "fr", "languages": ["fr", "de"]}, _test_dir)
	StoryI18nService.save_i18n({}, _test_dir, "de")
	StoryI18nService.save_i18n({}, _test_dir, "en")  # en existe mais pas dans config
	var check = StoryI18nService.check_translations(story, _test_dir)
	assert_true(check.has("de"))
	assert_false(check.has("en"))  # en n'est pas dans la config

func test_check_skips_default_language() -> void:
	var story = _make_simple_story()
	StoryI18nService.save_languages_config({"default": "fr", "languages": ["fr", "en"]}, _test_dir)
	StoryI18nService.save_i18n({}, _test_dir, "en")
	var check = StoryI18nService.check_translations(story, _test_dir)
	assert_false(check.has("fr"))

func test_check_includes_language_with_no_file() -> void:
	# Si une langue est dans la config mais pas de fichier → tout manque
	var story = _make_simple_story()
	StoryI18nService.save_languages_config({"default": "fr", "languages": ["fr", "en"]}, _test_dir)
	# Pas de en.yaml
	var check = StoryI18nService.check_translations(story, _test_dir)
	assert_true(check.has("en"))
	assert_true(check["en"]["missing"].size() > 0)


# ── regenerate_missing_keys avec config ───────────────────────────────────────

func test_regenerate_creates_file_for_configured_lang() -> void:
	var story = _make_simple_story()
	StoryI18nService.save_languages_config({"default": "fr", "languages": ["fr", "en"]}, _test_dir)
	StoryI18nService.regenerate_missing_keys(story, _test_dir)
	assert_true(FileAccess.file_exists(_test_dir + "/i18n/en.yaml"))

func test_regenerate_uses_default_lang_for_key_equal_value() -> void:
	var story = _make_simple_story()
	StoryI18nService.save_languages_config({"default": "fr", "languages": ["fr", "en"]}, _test_dir)
	StoryI18nService.regenerate_missing_keys(story, _test_dir)
	var fr_dict = StoryI18nService.load_i18n(_test_dir, "fr")
	assert_eq(fr_dict.get("Titre", "MISSING"), "Titre")

func test_regenerate_non_default_gets_empty_value() -> void:
	var story = _make_simple_story()
	StoryI18nService.save_languages_config({"default": "fr", "languages": ["fr", "en"]}, _test_dir)
	StoryI18nService.regenerate_missing_keys(story, _test_dir)
	var en_dict = StoryI18nService.load_i18n(_test_dir, "en")
	assert_eq(en_dict.get("Titre", "MISSING"), "")

func test_regenerate_does_not_process_unconfigured_lang() -> void:
	var story = _make_simple_story()
	# Config sans "de", mais de.yaml existe
	StoryI18nService.save_languages_config({"default": "fr", "languages": ["fr"]}, _test_dir)
	StoryI18nService.save_i18n({}, _test_dir, "de")
	var result = StoryI18nService.regenerate_missing_keys(story, _test_dir)
	assert_false(result.has("de"))

func test_regenerate_with_non_fr_default() -> void:
	var story = _make_simple_story()
	# Langue source = en (histoire en anglais)
	StoryI18nService.save_languages_config({"default": "en", "languages": ["en", "fr"]}, _test_dir)
	StoryI18nService.regenerate_missing_keys(story, _test_dir)
	var en_dict = StoryI18nService.load_i18n(_test_dir, "en")
	var fr_dict = StoryI18nService.load_i18n(_test_dir, "fr")
	assert_eq(en_dict.get("Titre", "MISSING"), "Titre")  # source
	assert_eq(fr_dict.get("Titre", "MISSING"), "")       # cible


# ── get_available_languages ───────────────────────────────────────────────────

func test_get_languages_excludes_languages_yaml() -> void:
	StoryI18nService.save_languages_config({"default": "fr", "languages": ["fr"]}, _test_dir)
	StoryI18nService.save_i18n({}, _test_dir, "en")
	var langs = StoryI18nService.get_available_languages(_test_dir)
	assert_false(langs.has("languages"))
	assert_true(langs.has("en"))
