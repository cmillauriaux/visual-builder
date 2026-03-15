extends GutTest

## Tests pour export_service — fix _copy_dir_recursive + exclusion assets/ui.

const ExportServiceScript = preload("res://src/services/export_service.gd")

var _service
var _tmp_src: String
var _tmp_dst: String


func before_each() -> void:
	_service = RefCounted.new()
	_service.set_script(ExportServiceScript)
	_tmp_src = "/tmp/test_copy_src_" + str(randi())
	_tmp_dst = "/tmp/test_copy_dst_" + str(randi())
	DirAccess.make_dir_recursive_absolute(_tmp_src)
	DirAccess.make_dir_recursive_absolute(_tmp_dst)


func after_each() -> void:
	_cleanup_dir(_tmp_src)
	_cleanup_dir(_tmp_dst)


func _cleanup_dir(path: String) -> void:
	var d = DirAccess.open(path)
	if not d:
		return
	d.list_dir_begin()
	var f = d.get_next()
	while f != "":
		var fp = path + "/" + f
		if d.current_is_dir():
			_cleanup_dir(fp)
			DirAccess.remove_absolute(fp)
		else:
			DirAccess.remove_absolute(fp)
		f = d.get_next()
	DirAccess.remove_absolute(path)


func test_copy_dir_recursive_propagates_exclude_to_subdirs() -> void:
	# Structure à 2 niveaux : _tmp_src/level1/ui/ et _tmp_src/level1/foregrounds/
	# Le bug original passe [] lors de la récursion dans level1/ → "ui" n'est plus exclu
	# Le fix propaghe ["ui"] à tous les niveaux récursifs
	DirAccess.make_dir_recursive_absolute(_tmp_src + "/level1/ui")
	DirAccess.make_dir_recursive_absolute(_tmp_src + "/level1/foregrounds")
	var f = FileAccess.open(_tmp_src + "/level1/ui/button_brown.png", FileAccess.WRITE)
	f.store_string("fake png")
	f.close()
	f = FileAccess.open(_tmp_src + "/level1/foregrounds/hero.png", FileAccess.WRITE)
	f.store_string("fake png")
	f.close()

	_service._copy_dir_recursive(_tmp_src, _tmp_dst, ["ui"])

	# "ui" doit être exclu à tous les niveaux
	assert_false(DirAccess.dir_exists_absolute(_tmp_dst + "/level1/ui"),
		"level1/ui should be excluded by propagated exclude list")
	assert_true(DirAccess.dir_exists_absolute(_tmp_dst + "/level1/foregrounds"),
		"level1/foregrounds should be copied")


func test_copy_dir_recursive_without_exclude_copies_everything() -> void:
	DirAccess.make_dir_recursive_absolute(_tmp_src + "/assets/ui")
	var f = FileAccess.open(_tmp_src + "/assets/ui/button_brown.png", FileAccess.WRITE)
	f.store_string("fake png")
	f.close()

	_service._copy_dir_recursive(_tmp_src, _tmp_dst, [])

	assert_true(DirAccess.dir_exists_absolute(_tmp_dst + "/assets/ui"),
		"assets/ui should be copied when no exclusion")
	assert_true(FileAccess.file_exists(_tmp_dst + "/assets/ui/button_brown.png"))
