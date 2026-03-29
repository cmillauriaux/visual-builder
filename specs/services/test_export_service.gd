extends GutTest

var ExportServiceScript

func before_each():
	ExportServiceScript = load("res://src/services/export_service.gd")

func test_get_export_extension():
	var service = ExportServiceScript.new()
	assert_eq(service._get_export_extension("web"), "html")
	assert_eq(service._get_export_extension("macos"), "zip")
	assert_eq(service._get_export_extension("windows"), "exe")
	assert_eq(service._get_export_extension("linux"), "x86_64")
	assert_eq(service._get_export_extension("android"), "apk")

func test_get_preset_name():
	var service = ExportServiceScript.new()
	assert_eq(service._get_preset_name("web"), "Web")
	assert_eq(service._get_preset_name("macos"), "macOS")
	assert_eq(service._get_preset_name("windows"), "Windows")

func test_strip_ansi_codes():
	var service = ExportServiceScript.new()
	var input = "\u001b[31mError\u001b[0m: Something went wrong"
	assert_eq(service._strip_ansi_codes(input), "Error: Something went wrong")

func test_extract_export_error_no_file():
	var service = ExportServiceScript.new()
	var error = service.extract_export_error("nonexistent.log")
	assert_string_contains(error, "log introuvable")

func test_find_godot():
	var service = ExportServiceScript.new()
	var godot = service._find_godot()
	assert_not_null(godot)

func test_export_story_null_story():
	var service = ExportServiceScript.new()
	var result = service.export_story(null, "web", "res://build/", "")
	assert_false(result.success)
	assert_eq(result.error_message, "Aucune histoire chargée.")


func test_generate_plugin_registry():
	var service = ExportServiceScript.new()
	# Créer un projet temp avec un plugin factice
	var temp_dir = ProjectSettings.globalize_path("user://test_registry_" + str(Time.get_ticks_msec()))
	DirAccess.make_dir_recursive_absolute(temp_dir + "/plugins/my_plugin")
	var f = FileAccess.open(temp_dir + "/plugins/my_plugin/game_plugin.gd", FileAccess.WRITE)
	f.store_string("extends RefCounted\nfunc get_plugin_name(): return 'my_plugin'")
	f.close()
	# Générer le registre
	var log_path = temp_dir + "/test.log"
	f = FileAccess.open(log_path, FileAccess.WRITE)
	f.close()
	service._generate_plugin_registry(temp_dir, log_path)
	# Vérifier le registre
	var registry_path = temp_dir + "/plugins/_registry.json"
	assert_true(FileAccess.file_exists(registry_path), "Registry file should be created")
	var content = FileAccess.get_file_as_string(registry_path)
	var parsed = JSON.parse_string(content)
	assert_true(parsed is Array)
	assert_eq(parsed.size(), 1)
	assert_eq(parsed[0], "res://plugins/my_plugin/game_plugin.gd")
	# Cleanup
	service._remove_dir_recursive(temp_dir)


func test_generate_plugin_registry_excludes_removed_plugins():
	var service = ExportServiceScript.new()
	# Créer un projet temp avec 2 plugins
	var temp_dir = ProjectSettings.globalize_path("user://test_registry_excl_" + str(Time.get_ticks_msec()))
	DirAccess.make_dir_recursive_absolute(temp_dir + "/plugins/kept")
	DirAccess.make_dir_recursive_absolute(temp_dir + "/plugins/removed")
	for name in ["kept", "removed"]:
		var f = FileAccess.open(temp_dir + "/plugins/" + name + "/game_plugin.gd", FileAccess.WRITE)
		f.store_string("extends RefCounted")
		f.close()
	# Supprimer le plugin "removed" (comme le ferait l'export service)
	service._remove_dir_recursive(temp_dir + "/plugins/removed")
	# Générer le registre
	var log_path = temp_dir + "/test.log"
	var f2 = FileAccess.open(log_path, FileAccess.WRITE)
	f2.close()
	service._generate_plugin_registry(temp_dir, log_path)
	# Vérifier que seul "kept" est dans le registre
	var content = FileAccess.get_file_as_string(temp_dir + "/plugins/_registry.json")
	var parsed = JSON.parse_string(content)
	assert_eq(parsed.size(), 1)
	assert_eq(parsed[0], "res://plugins/kept/game_plugin.gd")
	# Cleanup
	service._remove_dir_recursive(temp_dir)


# --- Tests _remove_unused_assets ---

func _create_test_story_dir() -> String:
	var service = ExportServiceScript.new()
	var temp_dir = ProjectSettings.globalize_path("user://test_unused_assets_" + str(Time.get_ticks_msec()))

	# Créer la structure : story avec un chapitre, une scène, des assets
	DirAccess.make_dir_recursive_absolute(temp_dir + "/assets/backgrounds")
	DirAccess.make_dir_recursive_absolute(temp_dir + "/assets/foregrounds")
	DirAccess.make_dir_recursive_absolute(temp_dir + "/assets/music")
	DirAccess.make_dir_recursive_absolute(temp_dir + "/assets/voices")
	DirAccess.make_dir_recursive_absolute(temp_dir + "/chapters/ch1/scenes")

	# story.yaml référence menu_background et menu_music
	var f = FileAccess.open(temp_dir + "/story.yaml", FileAccess.WRITE)
	f.store_string('title: "Test"\nmenu_background: "assets/backgrounds/menu_bg.png"\nmenu_music: "assets/music/menu_track.mp3"\nchapters:\n  - uuid: "ch1"\n    chapter_name: "Chapter 1"\n')
	f.close()

	# Scène YAML référence certains assets
	f = FileAccess.open(temp_dir + "/chapters/ch1/scenes/scene1.yaml", FileAccess.WRITE)
	f.store_string('sequences:\n  - uuid: "seq1"\n    background: "assets/backgrounds/forest.png"\n    foregrounds:\n      - image: "assets/foregrounds/hero.png"\n    music: "assets/music/battle.mp3"\n    audio_fx: ""\n    dialogues:\n      - uuid: "dlg1"\n        voice_files: { default: "assets/voices/dlg1.mp3" }\n')
	f.close()

	# Créer les fichiers assets référencés
	for path in ["assets/backgrounds/menu_bg.png", "assets/backgrounds/forest.png",
				"assets/foregrounds/hero.png", "assets/music/menu_track.mp3",
				"assets/music/battle.mp3", "assets/voices/dlg1.mp3"]:
		var af = FileAccess.open(temp_dir + "/" + path, FileAccess.WRITE)
		af.store_string("fake data")
		af.close()

	# Créer des fichiers assets NON référencés (orphelins)
	for path in ["assets/backgrounds/unused_bg.png", "assets/foregrounds/old_char.jpg",
				"assets/music/deleted_track.ogg", "assets/voices/orphan_voice.mp3"]:
		var af = FileAccess.open(temp_dir + "/" + path, FileAccess.WRITE)
		af.store_string("orphan data")
		af.close()

	return temp_dir


func test_remove_unused_assets_keeps_referenced():
	var service = ExportServiceScript.new()
	var temp_dir = _create_test_story_dir()
	var log_path = temp_dir + "/test.log"
	var f = FileAccess.open(log_path, FileAccess.WRITE)
	f.close()

	service._remove_unused_assets(temp_dir, log_path)

	# Les assets référencés doivent être conservés
	assert_true(FileAccess.file_exists(temp_dir + "/assets/backgrounds/menu_bg.png"), "menu_bg.png should be kept")
	assert_true(FileAccess.file_exists(temp_dir + "/assets/backgrounds/forest.png"), "forest.png should be kept")
	assert_true(FileAccess.file_exists(temp_dir + "/assets/foregrounds/hero.png"), "hero.png should be kept")
	assert_true(FileAccess.file_exists(temp_dir + "/assets/music/menu_track.mp3"), "menu_track.mp3 should be kept")
	assert_true(FileAccess.file_exists(temp_dir + "/assets/music/battle.mp3"), "battle.mp3 should be kept")
	assert_true(FileAccess.file_exists(temp_dir + "/assets/voices/dlg1.mp3"), "dlg1.mp3 should be kept")

	# Cleanup
	service._remove_dir_recursive(temp_dir)


func test_remove_unused_assets_deletes_orphans():
	var service = ExportServiceScript.new()
	var temp_dir = _create_test_story_dir()
	var log_path = temp_dir + "/test.log"
	var f = FileAccess.open(log_path, FileAccess.WRITE)
	f.close()

	service._remove_unused_assets(temp_dir, log_path)

	# Les assets orphelins doivent être supprimés
	assert_false(FileAccess.file_exists(temp_dir + "/assets/backgrounds/unused_bg.png"), "unused_bg.png should be removed")
	assert_false(FileAccess.file_exists(temp_dir + "/assets/foregrounds/old_char.jpg"), "old_char.jpg should be removed")
	assert_false(FileAccess.file_exists(temp_dir + "/assets/music/deleted_track.ogg"), "deleted_track.ogg should be removed")
	assert_false(FileAccess.file_exists(temp_dir + "/assets/voices/orphan_voice.mp3"), "orphan_voice.mp3 should be removed")

	# Cleanup
	service._remove_dir_recursive(temp_dir)


func test_remove_unused_assets_partial_export_scenario():
	var service = ExportServiceScript.new()
	var temp_dir = ProjectSettings.globalize_path("user://test_partial_assets_" + str(Time.get_ticks_msec()))

	# Créer 2 chapitres
	DirAccess.make_dir_recursive_absolute(temp_dir + "/assets/backgrounds")
	DirAccess.make_dir_recursive_absolute(temp_dir + "/assets/voices")
	DirAccess.make_dir_recursive_absolute(temp_dir + "/chapters/ch1/scenes")

	# story.yaml (chapitre 2 déjà exclu, comme après _filter_partial_chapters)
	var f = FileAccess.open(temp_dir + "/story.yaml", FileAccess.WRITE)
	f.store_string('title: "Test"\nmenu_background: ""\nchapters:\n  - uuid: "ch1"\n')
	f.close()

	# Scène du chapitre 1 : référence bg_ch1.png
	f = FileAccess.open(temp_dir + "/chapters/ch1/scenes/s1.yaml", FileAccess.WRITE)
	f.store_string('sequences:\n  - background: "assets/backgrounds/bg_ch1.png"\n    dialogues:\n      - voice_files: { default: "assets/voices/voice_ch1.mp3" }\n')
	f.close()

	# Assets du chapitre 1 (référencés)
	for path in ["assets/backgrounds/bg_ch1.png", "assets/voices/voice_ch1.mp3"]:
		var af = FileAccess.open(temp_dir + "/" + path, FileAccess.WRITE)
		af.store_string("data")
		af.close()

	# Assets du chapitre 2 (non référencés car le dossier chapitre a été supprimé)
	for path in ["assets/backgrounds/bg_ch2.png", "assets/voices/voice_ch2.mp3"]:
		var af = FileAccess.open(temp_dir + "/" + path, FileAccess.WRITE)
		af.store_string("data")
		af.close()

	var log_path = temp_dir + "/test.log"
	f = FileAccess.open(log_path, FileAccess.WRITE)
	f.close()

	service._remove_unused_assets(temp_dir, log_path)

	# Assets du chapitre 1 conservés
	assert_true(FileAccess.file_exists(temp_dir + "/assets/backgrounds/bg_ch1.png"), "bg_ch1 should be kept")
	assert_true(FileAccess.file_exists(temp_dir + "/assets/voices/voice_ch1.mp3"), "voice_ch1 should be kept")

	# Assets du chapitre 2 supprimés
	assert_false(FileAccess.file_exists(temp_dir + "/assets/backgrounds/bg_ch2.png"), "bg_ch2 should be removed")
	assert_false(FileAccess.file_exists(temp_dir + "/assets/voices/voice_ch2.mp3"), "voice_ch2 should be removed")

	# Cleanup
	service._remove_dir_recursive(temp_dir)


func test_remove_unused_assets_ignores_non_media_files():
	var service = ExportServiceScript.new()
	var temp_dir = ProjectSettings.globalize_path("user://test_nonmedia_" + str(Time.get_ticks_msec()))

	DirAccess.make_dir_recursive_absolute(temp_dir + "/assets/backgrounds")

	# story.yaml minimal
	var f = FileAccess.open(temp_dir + "/story.yaml", FileAccess.WRITE)
	f.store_string('title: "Test"\n')
	f.close()

	# Fichier non-media dans assets (ne doit PAS être supprimé par la logique media)
	f = FileAccess.open(temp_dir + "/assets/backgrounds/readme.txt", FileAccess.WRITE)
	f.store_string("notes")
	f.close()

	# Fichier media orphelin (doit être supprimé)
	f = FileAccess.open(temp_dir + "/assets/backgrounds/orphan.png", FileAccess.WRITE)
	f.store_string("data")
	f.close()

	var log_path = temp_dir + "/test.log"
	f = FileAccess.open(log_path, FileAccess.WRITE)
	f.close()

	service._remove_unused_assets(temp_dir, log_path)

	# Le fichier .txt ne doit pas être touché
	assert_true(FileAccess.file_exists(temp_dir + "/assets/backgrounds/readme.txt"), "txt file should be kept")
	# Le fichier .png orphelin doit être supprimé
	assert_false(FileAccess.file_exists(temp_dir + "/assets/backgrounds/orphan.png"), "orphan.png should be removed")

	# Cleanup
	service._remove_dir_recursive(temp_dir)


func test_remove_unused_assets_no_assets_dir():
	var service = ExportServiceScript.new()
	var temp_dir = ProjectSettings.globalize_path("user://test_noassets_" + str(Time.get_ticks_msec()))
	DirAccess.make_dir_recursive_absolute(temp_dir)

	var f = FileAccess.open(temp_dir + "/story.yaml", FileAccess.WRITE)
	f.store_string('title: "Test"\n')
	f.close()

	var log_path = temp_dir + "/test.log"
	f = FileAccess.open(log_path, FileAccess.WRITE)
	f.close()

	# Ne doit pas crasher si le dossier assets n'existe pas
	service._remove_unused_assets(temp_dir, log_path)
	assert_true(true, "Should not crash when assets dir is missing")

	# Cleanup
	service._remove_dir_recursive(temp_dir)


# --- Tests _patch_orphan_redirects ---

func _create_partial_export_dir() -> String:
	var temp_dir = ProjectSettings.globalize_path("user://test_patch_redirects_" + str(Time.get_ticks_msec()))
	DirAccess.make_dir_recursive_absolute(temp_dir + "/chapters/ch-aaa/scenes")
	DirAccess.make_dir_recursive_absolute(temp_dir + "/chapters/ch-bbb/scenes")
	return temp_dir


func test_patch_orphan_redirects_auto_redirect_to_excluded_chapter():
	var service = ExportServiceScript.new()
	var temp_dir = _create_partial_export_dir()
	var log_path = temp_dir + "/test.log"
	var f = FileAccess.open(log_path, FileAccess.WRITE)
	f.close()

	# Scène avec auto_redirect vers un chapitre exclu (ch-zzz)
	f = FileAccess.open(temp_dir + "/chapters/ch-bbb/scenes/s1.yaml", FileAccess.WRITE)
	f.store_string("uuid: \"s1\"\nname: \"Scene 1\"\nsequences:\n  - uuid: \"seq1\"\n    name: \"Seq 1\"\n    ending:\n      type: \"auto_redirect\"\n      consequence:\n        type: \"redirect_chapter\"\n        target: \"ch-zzz\"\n        effects: []\nconditions: []\nconnections: []\nentry_point: \"seq1\"\n")
	f.close()

	var selected_uuids: Array = ["ch-aaa", "ch-bbb"]
	service._patch_orphan_redirects(temp_dir + "/chapters", selected_uuids, log_path)

	# Vérifier que la conséquence a été convertie
	var YamlParser = load("res://src/persistence/yaml_parser.gd")
	var content = FileAccess.get_file_as_string(temp_dir + "/chapters/ch-bbb/scenes/s1.yaml")
	var scene_dict = YamlParser.yaml_to_dict(content)
	var consequence = scene_dict["sequences"][0]["ending"]["consequence"]
	assert_eq(consequence["type"], "to_be_continued", "Should convert to to_be_continued")
	assert_false(consequence.has("target"), "Should remove target field")

	service._remove_dir_recursive(temp_dir)


func test_patch_orphan_redirects_keeps_valid_redirect():
	var service = ExportServiceScript.new()
	var temp_dir = _create_partial_export_dir()
	var log_path = temp_dir + "/test.log"
	var f = FileAccess.open(log_path, FileAccess.WRITE)
	f.close()

	# Scène avec redirect vers un chapitre inclus (ch-bbb)
	f = FileAccess.open(temp_dir + "/chapters/ch-aaa/scenes/s1.yaml", FileAccess.WRITE)
	f.store_string("uuid: \"s1\"\nname: \"Scene 1\"\nsequences:\n  - uuid: \"seq1\"\n    name: \"Seq 1\"\n    ending:\n      type: \"auto_redirect\"\n      consequence:\n        type: \"redirect_chapter\"\n        target: \"ch-bbb\"\n        effects: []\nconditions: []\nconnections: []\nentry_point: \"seq1\"\n")
	f.close()

	var selected_uuids: Array = ["ch-aaa", "ch-bbb"]
	service._patch_orphan_redirects(temp_dir + "/chapters", selected_uuids, log_path)

	var YamlParser = load("res://src/persistence/yaml_parser.gd")
	var content = FileAccess.get_file_as_string(temp_dir + "/chapters/ch-aaa/scenes/s1.yaml")
	var scene_dict = YamlParser.yaml_to_dict(content)
	var consequence = scene_dict["sequences"][0]["ending"]["consequence"]
	assert_eq(consequence["type"], "redirect_chapter", "Should keep redirect_chapter")
	assert_eq(consequence["target"], "ch-bbb", "Should keep target")

	service._remove_dir_recursive(temp_dir)


func test_patch_orphan_redirects_choices_to_excluded_chapter():
	var service = ExportServiceScript.new()
	var temp_dir = _create_partial_export_dir()
	var log_path = temp_dir + "/test.log"
	var f = FileAccess.open(log_path, FileAccess.WRITE)
	f.close()

	# Scène avec choices dont un pointe vers un chapitre exclu
	f = FileAccess.open(temp_dir + "/chapters/ch-bbb/scenes/s1.yaml", FileAccess.WRITE)
	f.store_string("uuid: \"s1\"\nname: \"Scene 1\"\nsequences:\n  - uuid: \"seq1\"\n    name: \"Seq 1\"\n    ending:\n      type: \"choices\"\n      choices:\n        - text: \"Go next\"\n          consequence:\n            type: \"redirect_chapter\"\n            target: \"ch-zzz\"\n            effects: []\n          conditions: {}\n          effects: []\n        - text: \"Stay here\"\n          consequence:\n            type: \"redirect_sequence\"\n            target: \"seq1\"\n            effects: []\n          conditions: {}\n          effects: []\nconditions: []\nconnections: []\nentry_point: \"seq1\"\n")
	f.close()

	var selected_uuids: Array = ["ch-aaa", "ch-bbb"]
	service._patch_orphan_redirects(temp_dir + "/chapters", selected_uuids, log_path)

	var YamlParser = load("res://src/persistence/yaml_parser.gd")
	var content = FileAccess.get_file_as_string(temp_dir + "/chapters/ch-bbb/scenes/s1.yaml")
	var scene_dict = YamlParser.yaml_to_dict(content)
	var choices = scene_dict["sequences"][0]["ending"]["choices"]
	# Le premier choix doit être converti
	assert_eq(choices[0]["consequence"]["type"], "to_be_continued", "Orphan choice should be to_be_continued")
	assert_false(choices[0]["consequence"].has("target"), "Should remove target from orphan choice")
	# Le second choix (redirect_sequence) ne doit pas être modifié
	assert_eq(choices[1]["consequence"]["type"], "redirect_sequence", "Non-redirect_chapter should be untouched")
	assert_eq(choices[1]["consequence"]["target"], "seq1", "Target should be preserved")

	service._remove_dir_recursive(temp_dir)


func test_patch_orphan_redirects_preserves_effects():
	var service = ExportServiceScript.new()
	var temp_dir = _create_partial_export_dir()
	var log_path = temp_dir + "/test.log"
	var f = FileAccess.open(log_path, FileAccess.WRITE)
	f.close()

	# Scène avec redirect vers chapitre exclu + effects
	f = FileAccess.open(temp_dir + "/chapters/ch-bbb/scenes/s1.yaml", FileAccess.WRITE)
	f.store_string("uuid: \"s1\"\nname: \"Scene 1\"\nsequences:\n  - uuid: \"seq1\"\n    name: \"Seq 1\"\n    ending:\n      type: \"auto_redirect\"\n      consequence:\n        type: \"redirect_chapter\"\n        target: \"ch-zzz\"\n        effects:\n          - variable: \"score\"\n            operator: \"add\"\n            value: \"10\"\nconditions: []\nconnections: []\nentry_point: \"seq1\"\n")
	f.close()

	var selected_uuids: Array = ["ch-aaa", "ch-bbb"]
	service._patch_orphan_redirects(temp_dir + "/chapters", selected_uuids, log_path)

	var YamlParser = load("res://src/persistence/yaml_parser.gd")
	var content = FileAccess.get_file_as_string(temp_dir + "/chapters/ch-bbb/scenes/s1.yaml")
	var scene_dict = YamlParser.yaml_to_dict(content)
	var consequence = scene_dict["sequences"][0]["ending"]["consequence"]
	assert_eq(consequence["type"], "to_be_continued", "Should convert to to_be_continued")
	assert_true(consequence.has("effects"), "Should preserve effects")
	assert_eq(consequence["effects"].size(), 1, "Should have 1 effect")
	assert_eq(consequence["effects"][0]["variable"], "score", "Should preserve effect variable")

	service._remove_dir_recursive(temp_dir)


func test_patch_orphan_redirects_no_scenes_dir():
	var service = ExportServiceScript.new()
	var temp_dir = ProjectSettings.globalize_path("user://test_patch_noscenes_" + str(Time.get_ticks_msec()))
	DirAccess.make_dir_recursive_absolute(temp_dir + "/chapters/ch-aaa")
	var log_path = temp_dir + "/test.log"
	var f = FileAccess.open(log_path, FileAccess.WRITE)
	f.close()

	# Ne doit pas crasher si le dossier scenes n'existe pas
	var selected_uuids: Array = ["ch-aaa"]
	service._patch_orphan_redirects(temp_dir + "/chapters", selected_uuids, log_path)
	assert_true(true, "Should not crash when scenes dir is missing")

	service._remove_dir_recursive(temp_dir)


# --- Tests _extract_voice_keeps_from_content ---

func test_extract_voice_keeps_inline_format():
	var service = ExportServiceScript.new()
	var keep: Dictionary = {}
	var content = 'dialogues:\n  - uuid: "dlg1"\n    voice_files: { default: "assets/voices/uuid1.mp3", en: "assets/voices/uuid1_en.mp3" }\n'
	service._extract_voice_keeps_from_content(content, "en", "fr", keep)
	assert_true(keep.has("uuid1_en.mp3"), "Should keep en file from inline format")
	assert_false(keep.has("uuid1.mp3"), "Should not keep default when en exists (not source lang)")


func test_extract_voice_keeps_inline_default_fallback():
	var service = ExportServiceScript.new()
	var keep: Dictionary = {}
	# Pas de clé "en", donc le default doit être gardé comme fallback
	var content = 'dialogues:\n  - voice_files: { default: "assets/voices/uuid1.mp3" }\n'
	service._extract_voice_keeps_from_content(content, "en", "fr", keep)
	assert_true(keep.has("uuid1.mp3"), "Should keep default when language key is missing")


func test_extract_voice_keeps_block_format():
	var service = ExportServiceScript.new()
	var keep: Dictionary = {}
	var content = "dialogues:\n  - uuid: \"dlg1\"\n    voice_files:\n      default: \"assets/voices/uuid1.mp3\"\n      en: \"assets/voices/uuid1_en.mp3\"\n      fr: \"assets/voices/uuid1_fr.mp3\"\n    voice_request_ids:\n      en: \"req123\"\n"
	service._extract_voice_keeps_from_content(content, "en", "fr", keep)
	assert_true(keep.has("uuid1_en.mp3"), "Should keep en file from block format")
	assert_false(keep.has("uuid1.mp3"), "Should not keep default when en exists")
	assert_false(keep.has("uuid1_fr.mp3"), "Should not keep fr when exporting en")


func test_extract_voice_keeps_block_format_source_lang():
	var service = ExportServiceScript.new()
	var keep: Dictionary = {}
	# Export en français (langue source), doit garder "default" et "fr"
	var content = "dialogues:\n  - voice_files:\n      default: \"assets/voices/uuid1.mp3\"\n      en: \"assets/voices/uuid1_en.mp3\"\n      fr: \"assets/voices/uuid1_fr.mp3\"\n"
	service._extract_voice_keeps_from_content(content, "fr", "fr", keep)
	assert_true(keep.has("uuid1_fr.mp3"), "Should keep fr file")
	assert_true(keep.has("uuid1.mp3"), "Should keep default when exporting source lang")
	assert_false(keep.has("uuid1_en.mp3"), "Should not keep en when exporting fr")


func test_extract_voice_keeps_block_default_fallback():
	var service = ExportServiceScript.new()
	var keep: Dictionary = {}
	# Block format sans clé "en" : le default sert de fallback
	var content = "dialogues:\n  - voice_files:\n      default: \"assets/voices/uuid1.mp3\"\n      fr: \"assets/voices/uuid1_fr.mp3\"\n"
	service._extract_voice_keeps_from_content(content, "en", "fr", keep)
	assert_true(keep.has("uuid1.mp3"), "Should keep default when en key is missing in block format")
	assert_false(keep.has("uuid1_fr.mp3"), "Should not keep fr when exporting en")


func test_extract_voice_keeps_mixed_formats():
	var service = ExportServiceScript.new()
	var keep: Dictionary = {}
	# Mélange inline (narrateur) et block (Jessy)
	var content = "sequences:\n  - dialogues:\n      - character: \"Narrateur\"\n        voice_files: { en: \"assets/voices/narrator_en.mp3\" }\n      - character: \"Jessy\"\n        voice_files:\n          default: \"assets/voices/jessy.mp3\"\n          en: \"assets/voices/jessy_en.mp3\"\n          fr: \"assets/voices/jessy_fr.mp3\"\n"
	service._extract_voice_keeps_from_content(content, "en", "fr", keep)
	assert_true(keep.has("narrator_en.mp3"), "Should keep narrator en from inline")
	assert_true(keep.has("jessy_en.mp3"), "Should keep jessy en from block")
	assert_false(keep.has("jessy.mp3"), "Should not keep jessy default when en exists")
	assert_false(keep.has("jessy_fr.mp3"), "Should not keep jessy fr")


func test_extract_voice_keeps_empty_block():
	var service = ExportServiceScript.new()
	var keep: Dictionary = {}
	var content = "dialogues:\n  - voice_files: {}\n  - voice_files:\n      en: \"assets/voices/valid_en.mp3\"\n"
	service._extract_voice_keeps_from_content(content, "en", "fr", keep)
	assert_true(keep.has("valid_en.mp3"), "Should handle empty inline then parse next block")
