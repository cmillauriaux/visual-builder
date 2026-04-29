extends GutTest

var ExportServiceScript

func before_each():
	ExportServiceScript = load("res://src/services/export_service.gd")

func test_remove_unused_assets_leak_via_blink_manifest():
	var service = ExportServiceScript.new()
	var temp_dir = ProjectSettings.globalize_path("user://test_leak_" + str(Time.get_ticks_msec()))
	
	DirAccess.make_dir_recursive_absolute(temp_dir + "/assets/foregrounds")
	DirAccess.make_dir_recursive_absolute(temp_dir + "/chapters/ch1/scenes")
	
	# Story and scenes ONLY use "hero.png"
	var f = FileAccess.open(temp_dir + "/story.yaml", FileAccess.WRITE)
	f.store_string("title: 'Test'\nchapters:\n  - uuid: 'ch1'\n")
	f.close()
	
	f = FileAccess.open(temp_dir + "/chapters/ch1/scenes/s1.yaml", FileAccess.WRITE)
	f.store_string("sequences:\n  - foregrounds:\n      - image: 'assets/foregrounds/hero.png'\n")
	f.close()
	
	# Blink manifest references "unused.png" and "unused_blink.png"
	f = FileAccess.open(temp_dir + "/assets/foregrounds/blink_manifest.yaml", FileAccess.WRITE)
	f.store_string("blinks:\n  hero.png: hero_blink.png\n  unused.png: unused_blink.png\n")
	f.close()
	
	# Create all these files
	for img in ["hero.png", "hero_blink.png", "unused.png", "unused_blink.png", "orphan.png"]:
		var af = FileAccess.open(temp_dir + "/assets/foregrounds/" + img, FileAccess.WRITE)
		af.store_string("data")
		af.close()
	
	var log_path = temp_dir + "/test.log"
	f = FileAccess.open(log_path, FileAccess.WRITE)
	f.close()
	
	service._remove_unused_assets(temp_dir, log_path)
	
	# EXPECTED (Surgical):
	# hero.png (used) -> KEEP
	# hero_blink.png (referenced by used) -> KEEP
	# unused.png (not used in sequences) -> REMOVE
	# unused_blink.png (referenced by unused) -> REMOVE
	# orphan.png (not referenced anywhere) -> REMOVE
	
	assert_true(FileAccess.file_exists(temp_dir + "/assets/foregrounds/hero.png"), "hero.png should be kept")
	assert_true(FileAccess.file_exists(temp_dir + "/assets/foregrounds/hero_blink.png"), "hero_blink.png should be kept")
	
	assert_false(FileAccess.file_exists(temp_dir + "/assets/foregrounds/unused.png"), "unused.png should be removed even if in blink_manifest.yaml")
	assert_false(FileAccess.file_exists(temp_dir + "/assets/foregrounds/unused_blink.png"), "unused_blink.png should be removed")
	
	assert_false(FileAccess.file_exists(temp_dir + "/assets/foregrounds/orphan.png"), "orphan.png should be removed")
	
	service._remove_dir_recursive(temp_dir)


func test_remove_unused_assets_removes_unused_apng():
	var service = ExportServiceScript.new()
	var temp_dir = ProjectSettings.globalize_path("user://test_apng_cleanup_" + str(Time.get_ticks_msec()))
	
	DirAccess.make_dir_recursive_absolute(temp_dir + "/assets/foregrounds")
	DirAccess.make_dir_recursive_absolute(temp_dir + "/chapters/ch1/scenes")
	
	# Story uses "used.apng"
	var f = FileAccess.open(temp_dir + "/story.yaml", FileAccess.WRITE)
	f.store_string("title: 'Test'\n")
	f.close()
	
	f = FileAccess.open(temp_dir + "/chapters/ch1/scenes/s1.yaml", FileAccess.WRITE)
	f.store_string("sequences:\n  - foregrounds:\n      - image: 'assets/foregrounds/used.apng'\n")
	f.close()
	
	# Create apng files
	for img in ["used.apng", "unused.apng"]:
		var af = FileAccess.open(temp_dir + "/assets/foregrounds/" + img, FileAccess.WRITE)
		af.store_string("data")
		af.close()
	
	var log_path = temp_dir + "/test.log"
	f = FileAccess.open(log_path, FileAccess.WRITE)
	f.close()
	
	service._remove_unused_assets(temp_dir, log_path)
	
	assert_true(FileAccess.file_exists(temp_dir + "/assets/foregrounds/used.apng"), "used.apng should be kept")
	assert_false(FileAccess.file_exists(temp_dir + "/assets/foregrounds/unused.apng"), "unused.apng should be removed")
	
	service._remove_dir_recursive(temp_dir)
