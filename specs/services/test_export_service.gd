extends GutTest

const ExportServiceScript = preload("res://src/services/export_service.gd")
var _service: RefCounted

func before_each():
	_service = ExportServiceScript.new()

func test_extract_export_error_no_file():
	var result = _service.extract_export_error("res://nonexistent_log_xyz.txt")
	assert_eq(result, "L'export a échoué (log introuvable).")

func test_strip_ansi_codes():
	var input = "\u001b[31mError message\u001b[0m"
	var output = _service._strip_ansi_codes(input)
	assert_eq(output, "Error message")

func test_extract_export_error_from_content():
	var log_path = "user://test_export_error.log"
	var f = FileAccess.open(log_path, FileAccess.WRITE)
	f.store_string("Some noise
due to configuration errors:
Missing template
Another error")
	f.close()
	
	var result = _service.extract_export_error(log_path)
	assert_eq(result, "Missing template")
	
	DirAccess.remove_absolute(log_path)

func test_extract_export_error_from_godot_error():
	var log_path = "user://test_export_error_2.log"
	var f = FileAccess.open(log_path, FileAccess.WRITE)
	f.store_string("Godot Engine v4.4
ERREUR: Failed to open project
at: main.cpp:123")
	f.close()
	
	var result = _service.extract_export_error(log_path)
	assert_eq(result, "Failed to open project")
	
	DirAccess.remove_absolute(log_path)
