extends GutTest

## Tests pour StoryI18nService (système de traduction style .po).

const StoryI18nService = preload("res://src/services/story_i18n_service.gd")
const Story = preload("res://src/models/story.gd")
const Chapter = preload("res://src/models/chapter.gd")
const SceneData = preload("res://src/models/scene_data.gd")
const Sequence = preload("res://src/models/sequence.gd")
const Dialogue = preload("res://src/models/dialogue.gd")
const Ending = preload("res://src/models/ending.gd")
const Choice = preload("res://src/models/choice.gd")
const StoryNotification = preload("res://src/models/story_notification.gd")

var _test_dir: String = ""


func before_each() -> void:
	_test_dir = "user://test_i18n_%d" % randi()
	DirAccess.make_dir_recursive_absolute(_test_dir)


func after_each() -> void:
	_remove_dir_recursive(_test_dir)


func _remove_dir_recursive(path: String) -> void:
	var dir = DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name != "." and file_name != "..":
			var full_path = path + "/" + file_name
			if dir.current_is_dir():
				_remove_dir_recursive(full_path)
			else:
				DirAccess.remove_absolute(full_path)
		file_name = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)


# ── Helpers ──────────────────────────────────────────────────────────────────

func _make_story() -> Story:
	var story = Story.new()
	story.title = "L'Épreuve du Héros"
	story.author = "Auteur Test"
	story.description = "Une histoire de test."
	story.menu_title = "Épreuve"
	story.menu_subtitle = "Un voyage"

	var notif = StoryNotification.new()
	notif.pattern = "*"
	notif.message = "Variable modifiée!"
	story.notifications.append(notif)

	var chapter = Chapter.new()
	chapter.chapter_name = "Chapitre Un"
	chapter.subtitle = ""

	var scene = SceneData.new()
	scene.scene_name = "La Salle"
	scene.subtitle = ""

	var seq = Sequence.new()
	seq.seq_name = "Introduction"
	seq.subtitle = ""

	var dlg = Dialogue.new()
	dlg.character = "Héraut"
	dlg.text = "Bienvenue!"
	seq.dialogues.append(dlg)

	var choice = Choice.new()
	choice.text = "Continuer"
	var ending = Ending.new()
	ending.type = "choices"
	ending.choices.append(choice)
	seq.ending = ending

	scene.sequences.append(seq)
	chapter.scenes.append(scene)
	story.chapters.append(chapter)
	return story


# ── extract_strings ───────────────────────────────────────────────────────────

func test_extract_includes_story_title() -> void:
	var story = _make_story()
	var strings = StoryI18nService.extract_strings(story)
	assert_true(strings.has("L'Épreuve du Héros"))

func test_extract_includes_story_author() -> void:
	var story = _make_story()
	var strings = StoryI18nService.extract_strings(story)
	assert_true(strings.has("Auteur Test"))

func test_extract_includes_story_description() -> void:
	var story = _make_story()
	var strings = StoryI18nService.extract_strings(story)
	assert_true(strings.has("Une histoire de test."))

func test_extract_includes_menu_title() -> void:
	var story = _make_story()
	var strings = StoryI18nService.extract_strings(story)
	assert_true(strings.has("Épreuve"))

func test_extract_includes_menu_subtitle() -> void:
	var story = _make_story()
	var strings = StoryI18nService.extract_strings(story)
	assert_true(strings.has("Un voyage"))

func test_extract_includes_notification_message() -> void:
	var story = _make_story()
	var strings = StoryI18nService.extract_strings(story)
	assert_true(strings.has("Variable modifiée!"))

func test_extract_includes_chapter_name() -> void:
	var story = _make_story()
	var strings = StoryI18nService.extract_strings(story)
	assert_true(strings.has("Chapitre Un"))

func test_extract_includes_scene_name() -> void:
	var story = _make_story()
	var strings = StoryI18nService.extract_strings(story)
	assert_true(strings.has("La Salle"))

func test_extract_includes_sequence_name() -> void:
	var story = _make_story()
	var strings = StoryI18nService.extract_strings(story)
	assert_true(strings.has("Introduction"))

func test_extract_includes_dialogue_character() -> void:
	var story = _make_story()
	var strings = StoryI18nService.extract_strings(story)
	assert_true(strings.has("Héraut"))

func test_extract_includes_dialogue_text() -> void:
	var story = _make_story()
	var strings = StoryI18nService.extract_strings(story)
	assert_true(strings.has("Bienvenue!"))

func test_extract_includes_choice_text() -> void:
	var story = _make_story()
	var strings = StoryI18nService.extract_strings(story)
	assert_true(strings.has("Continuer"))

func test_extract_excludes_empty_strings() -> void:
	var story = _make_story()
	var strings = StoryI18nService.extract_strings(story)
	assert_false(strings.has(""))

func test_extract_deduplicates_identical_strings() -> void:
	var story = _make_story()
	# Ajouter un deuxième dialogue avec le même personnage
	var dlg2 = Dialogue.new()
	dlg2.character = "Héraut"
	dlg2.text = "Au revoir!"
	story.chapters[0].scenes[0].sequences[0].dialogues.append(dlg2)
	var strings = StoryI18nService.extract_strings(story)
	# "Héraut" ne doit apparaître qu'une fois (clé de dictionnaire)
	assert_eq(strings.keys().count("Héraut"), 1)

func test_extract_key_equals_value_for_source() -> void:
	var story = _make_story()
	var strings = StoryI18nService.extract_strings(story)
	assert_eq(strings["Bienvenue!"], "Bienvenue!")

func test_extract_empty_story_returns_ui_strings_only() -> void:
	var story = Story.new()
	var strings = StoryI18nService.extract_strings(story)
	# Un Story vide ne contient que les chaînes UI fixes
	assert_eq(strings.size(), StoryI18nService.UI_STRINGS.size())

func test_extract_includes_all_ui_strings() -> void:
	var story = Story.new()
	var strings = StoryI18nService.extract_strings(story)
	for s in StoryI18nService.UI_STRINGS:
		assert_true(strings.has(s), "UI string manquante : " + s)

func test_extract_ui_string_key_equals_value() -> void:
	var story = Story.new()
	var strings = StoryI18nService.extract_strings(story)
	assert_eq(strings.get("Nouvelle partie", ""), "Nouvelle partie")

func test_tr_returns_translation() -> void:
	var i18n = {"Nouvelle partie": "New Game", "Quitter": "Quit"}
	assert_eq(StoryI18nService.get_ui_string("Nouvelle partie", i18n), "New Game")

func test_tr_falls_back_to_source_when_key_absent() -> void:
	assert_eq(StoryI18nService.get_ui_string("Nouvelle partie", {}), "Nouvelle partie")

func test_tr_falls_back_to_source_when_translation_empty() -> void:
	var i18n = {"Nouvelle partie": ""}
	assert_eq(StoryI18nService.get_ui_string("Nouvelle partie", i18n), "Nouvelle partie")


# ── apply_to_story ────────────────────────────────────────────────────────────

func test_apply_translates_story_title() -> void:
	var story = _make_story()
	var i18n = {"L'Épreuve du Héros": "The Hero's Trial"}
	StoryI18nService.apply_to_story(story, i18n)
	assert_eq(story.title, "The Hero's Trial")

func test_apply_translates_dialogue_text() -> void:
	var story = _make_story()
	var i18n = {"Bienvenue!": "Welcome!"}
	StoryI18nService.apply_to_story(story, i18n)
	assert_eq(story.chapters[0].scenes[0].sequences[0].dialogues[0].text, "Welcome!")

func test_apply_translates_dialogue_character() -> void:
	var story = _make_story()
	var i18n = {"Héraut": "Herald"}
	StoryI18nService.apply_to_story(story, i18n)
	assert_eq(story.chapters[0].scenes[0].sequences[0].dialogues[0].character, "Herald")

func test_apply_translates_choice_text() -> void:
	var story = _make_story()
	var i18n = {"Continuer": "Continue"}
	StoryI18nService.apply_to_story(story, i18n)
	assert_eq(story.chapters[0].scenes[0].sequences[0].ending.choices[0].text, "Continue")

func test_apply_translates_chapter_name() -> void:
	var story = _make_story()
	var i18n = {"Chapitre Un": "Chapter One"}
	StoryI18nService.apply_to_story(story, i18n)
	assert_eq(story.chapters[0].chapter_name, "Chapter One")

func test_apply_translates_notification_message() -> void:
	var story = _make_story()
	var i18n = {"Variable modifiée!": "Variable changed!"}
	StoryI18nService.apply_to_story(story, i18n)
	assert_eq(story.notifications[0].message, "Variable changed!")

func test_apply_fallback_missing_key() -> void:
	var story = _make_story()
	var i18n = {"Autre clé": "Other key"}
	StoryI18nService.apply_to_story(story, i18n)
	assert_eq(story.title, "L'Épreuve du Héros")  # inchangé

func test_apply_fallback_empty_translation() -> void:
	var story = _make_story()
	var i18n = {"L'Épreuve du Héros": ""}
	StoryI18nService.apply_to_story(story, i18n)
	assert_eq(story.title, "L'Épreuve du Héros")  # valeur source conservée

func test_apply_empty_dict_changes_nothing() -> void:
	var story = _make_story()
	StoryI18nService.apply_to_story(story, {})
	assert_eq(story.title, "L'Épreuve du Héros")


# ── load_i18n ─────────────────────────────────────────────────────────────────

func test_load_returns_empty_dict_if_file_missing() -> void:
	var result = StoryI18nService.load_i18n(_test_dir, "en")
	assert_true(result.is_empty())

func test_load_returns_dict_if_file_exists() -> void:
	var i18n_dir = _test_dir + "/i18n"
	DirAccess.make_dir_recursive_absolute(i18n_dir)
	var file = FileAccess.open(i18n_dir + "/en.yaml", FileAccess.WRITE)
	# Le parser YAML attend des clés non quotées : Bonjour: "Hello"
	file.store_string("Bonjour: \"Hello\"\n")
	file.close()
	var result = StoryI18nService.load_i18n(_test_dir, "en")
	assert_true(result.has("Bonjour"))
	assert_eq(result["Bonjour"], "Hello")


# ── save_i18n ─────────────────────────────────────────────────────────────────

func test_save_creates_i18n_directory() -> void:
	StoryI18nService.save_i18n({"Bonjour": "Hello"}, _test_dir, "en")
	assert_true(DirAccess.dir_exists_absolute(_test_dir + "/i18n"))

func test_save_creates_lang_file() -> void:
	StoryI18nService.save_i18n({"Bonjour": "Hello"}, _test_dir, "en")
	assert_true(FileAccess.file_exists(_test_dir + "/i18n/en.yaml"))

func test_save_and_load_roundtrip() -> void:
	var original = {"Bonjour": "Hello", "Au revoir": "Goodbye"}
	StoryI18nService.save_i18n(original, _test_dir, "en")
	var loaded = StoryI18nService.load_i18n(_test_dir, "en")
	assert_eq(loaded.get("Bonjour", ""), "Hello")
	assert_eq(loaded.get("Au revoir", ""), "Goodbye")

func test_save_fr_source_has_key_equal_value() -> void:
	var story = _make_story()
	var strings = StoryI18nService.extract_strings(story)
	StoryI18nService.save_i18n(strings, _test_dir, "fr")
	var loaded = StoryI18nService.load_i18n(_test_dir, "fr")
	assert_eq(loaded.get("Bienvenue!", ""), "Bienvenue!")


# ── get_available_languages ───────────────────────────────────────────────────

func test_get_languages_empty_if_no_i18n_dir() -> void:
	var langs = StoryI18nService.get_available_languages(_test_dir)
	assert_true(langs.is_empty())

func test_get_languages_returns_existing_langs() -> void:
	StoryI18nService.save_i18n({"Bonjour": "Hello"}, _test_dir, "en")
	StoryI18nService.save_i18n({"Bonjour": "Hallo"}, _test_dir, "de")
	var langs = StoryI18nService.get_available_languages(_test_dir)
	assert_true(langs.has("en"))
	assert_true(langs.has("de"))

func test_get_languages_excludes_non_yaml() -> void:
	DirAccess.make_dir_recursive_absolute(_test_dir + "/i18n")
	var f = FileAccess.open(_test_dir + "/i18n/notes.txt", FileAccess.WRITE)
	f.store_string("note")
	f.close()
	var langs = StoryI18nService.get_available_languages(_test_dir)
	assert_false(langs.has("notes"))

func test_get_languages_sorted() -> void:
	StoryI18nService.save_i18n({}, _test_dir, "zh")
	StoryI18nService.save_i18n({}, _test_dir, "de")
	StoryI18nService.save_i18n({}, _test_dir, "en")
	var langs = StoryI18nService.get_available_languages(_test_dir)
	assert_eq(langs[0], "de")
	assert_eq(langs[1], "en")
	assert_eq(langs[2], "zh")


# ── check_translations ────────────────────────────────────────────────────────

func test_check_empty_if_no_non_fr_lang() -> void:
	var story = _make_story()
	StoryI18nService.save_i18n(StoryI18nService.extract_strings(story), _test_dir, "fr")
	var check = StoryI18nService.check_translations(story, _test_dir)
	assert_true(check.is_empty())

func test_check_detects_missing_translations() -> void:
	var story = _make_story()
	StoryI18nService.save_languages_config({"default": "fr", "languages": ["fr", "en"]}, _test_dir)
	StoryI18nService.save_i18n({}, _test_dir, "en")
	var check = StoryI18nService.check_translations(story, _test_dir)
	assert_true(check.has("en"))
	assert_true(check["en"]["missing"].size() > 0)

func test_check_detects_orphan_keys() -> void:
	var story = _make_story()
	StoryI18nService.save_languages_config({"default": "fr", "languages": ["fr", "en"]}, _test_dir)
	StoryI18nService.save_i18n({"Clé fantôme": "Ghost key"}, _test_dir, "en")
	var check = StoryI18nService.check_translations(story, _test_dir)
	assert_true(check["en"]["orphans"].has("Clé fantôme"))

func test_check_no_issues_when_fully_translated() -> void:
	var story = _make_story()
	var strings = StoryI18nService.extract_strings(story)
	StoryI18nService.save_languages_config({"default": "fr", "languages": ["fr", "en"]}, _test_dir)
	var en_dict: Dictionary = {}
	for s in strings:
		en_dict[s] = "translated:" + s
	StoryI18nService.save_i18n(en_dict, _test_dir, "en")
	var check = StoryI18nService.check_translations(story, _test_dir)
	assert_true(check["en"]["missing"].is_empty())
	assert_true(check["en"]["orphans"].is_empty())

func test_check_counts_translated_correctly() -> void:
	var story = _make_story()
	StoryI18nService.save_languages_config({"default": "fr", "languages": ["fr", "en"]}, _test_dir)
	StoryI18nService.save_i18n({"L'Épreuve du Héros": "The Hero's Trial"}, _test_dir, "en")
	var check = StoryI18nService.check_translations(story, _test_dir)
	assert_eq(check["en"]["translated"], 1)

func test_check_total_matches_source_strings() -> void:
	var story = _make_story()
	StoryI18nService.save_languages_config({"default": "fr", "languages": ["fr", "en"]}, _test_dir)
	StoryI18nService.save_i18n({}, _test_dir, "en")
	var source_count = StoryI18nService.extract_strings(story).size()
	var check = StoryI18nService.check_translations(story, _test_dir)
	assert_eq(check["en"]["total"], source_count)

func test_check_ignores_fr() -> void:
	var story = _make_story()
	StoryI18nService.save_i18n({"test": ""}, _test_dir, "fr")
	var check = StoryI18nService.check_translations(story, _test_dir)
	assert_false(check.has("fr"))


# ── regenerate_missing_keys ───────────────────────────────────────────────────

func test_regenerate_adds_missing_keys_to_existing_lang() -> void:
	var story = _make_story()
	StoryI18nService.save_languages_config({"default": "fr", "languages": ["fr", "en"]}, _test_dir)
	StoryI18nService.save_i18n({"L'Épreuve du Héros": "The Hero's Trial"}, _test_dir, "en")
	var result = StoryI18nService.regenerate_missing_keys(story, _test_dir)
	assert_true(result.has("en"))
	assert_true(result["en"] > 0)

func test_regenerate_new_keys_empty_value_for_non_fr() -> void:
	var story = _make_story()
	StoryI18nService.save_languages_config({"default": "fr", "languages": ["fr", "en"]}, _test_dir)
	StoryI18nService.save_i18n({}, _test_dir, "en")
	StoryI18nService.regenerate_missing_keys(story, _test_dir)
	var loaded = StoryI18nService.load_i18n(_test_dir, "en")
	assert_true(loaded.has("Bienvenue!"))
	assert_eq(loaded["Bienvenue!"], "")

func test_regenerate_fr_keys_equal_value() -> void:
	var story = _make_story()
	StoryI18nService.save_i18n({}, _test_dir, "fr")
	StoryI18nService.regenerate_missing_keys(story, _test_dir)
	var loaded = StoryI18nService.load_i18n(_test_dir, "fr")
	assert_eq(loaded.get("Bienvenue!", "MISSING"), "Bienvenue!")

func test_regenerate_preserves_existing_translations() -> void:
	var story = _make_story()
	StoryI18nService.save_i18n({"L'Épreuve du Héros": "The Hero's Trial"}, _test_dir, "en")
	StoryI18nService.regenerate_missing_keys(story, _test_dir)
	var loaded = StoryI18nService.load_i18n(_test_dir, "en")
	# La traduction existante doit être conservée
	assert_eq(loaded.get("L'Épreuve du Héros", ""), "The Hero's Trial")

func test_regenerate_zero_added_when_complete() -> void:
	var story = _make_story()
	var strings = StoryI18nService.extract_strings(story)
	var en_dict: Dictionary = {}
	for s in strings:
		en_dict[s] = "translated"
	StoryI18nService.save_i18n(en_dict, _test_dir, "en")
	var result = StoryI18nService.regenerate_missing_keys(story, _test_dir)
	assert_eq(result.get("en", -1), 0)

func test_regenerate_creates_fr_if_missing() -> void:
	var story = _make_story()
	# Aucun fichier i18n
	var result = StoryI18nService.regenerate_missing_keys(story, _test_dir)
	assert_true(result.has("fr"))
	assert_true(FileAccess.file_exists(_test_dir + "/i18n/fr.yaml"))
