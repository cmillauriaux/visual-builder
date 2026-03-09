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
