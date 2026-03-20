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
