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
	# La fonction collecte toutes les lignes d'erreur après "due to configuration errors:"
	assert_eq(result, "Missing template\nAnother error")

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


# --- Tests cache busting ---

func test_compute_file_hash_returns_8_chars():
	var path = "user://test_hash_file.bin"
	var f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string("hello world")
	f.close()

	var hash = _service._compute_file_hash(path)
	assert_eq(hash.length(), 8, "Le hash doit faire 8 caractères")
	# Vérifier que c'est bien de l'hexadécimal
	for c in hash:
		assert_true("0123456789abcdef".contains(c), "Le hash doit être hexadécimal : %s" % hash)

	DirAccess.remove_absolute(path)


func test_compute_file_hash_nonexistent_file():
	var hash = _service._compute_file_hash("user://nonexistent_xyz_test.bin")
	assert_eq(hash, "00000000", "Un fichier inexistant doit retourner 00000000")


func test_compute_file_hash_different_content_gives_different_hash():
	var path1 = "user://test_hash_1.bin"
	var path2 = "user://test_hash_2.bin"
	var f1 = FileAccess.open(path1, FileAccess.WRITE)
	f1.store_string("content version 1")
	f1.close()
	var f2 = FileAccess.open(path2, FileAccess.WRITE)
	f2.store_string("content version 2")
	f2.close()

	var hash1 = _service._compute_file_hash(path1)
	var hash2 = _service._compute_file_hash(path2)
	assert_ne(hash1, hash2, "Des contenus différents doivent donner des hashs différents")

	DirAccess.remove_absolute(path1)
	DirAccess.remove_absolute(path2)


func test_compute_file_hash_same_content_gives_same_hash():
	var path1 = "user://test_hash_same_1.bin"
	var path2 = "user://test_hash_same_2.bin"
	var f1 = FileAccess.open(path1, FileAccess.WRITE)
	f1.store_string("identical content")
	f1.close()
	var f2 = FileAccess.open(path2, FileAccess.WRITE)
	f2.store_string("identical content")
	f2.close()

	var hash1 = _service._compute_file_hash(path1)
	var hash2 = _service._compute_file_hash(path2)
	assert_eq(hash1, hash2, "Des contenus identiques doivent donner le même hash")

	DirAccess.remove_absolute(path1)
	DirAccess.remove_absolute(path2)
